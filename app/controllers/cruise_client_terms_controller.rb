# frozen_string_literal: true

class CruiseClientTermsController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_client_terms_access!
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :assign_offer

  def show
    @idempotency_key = SecureRandom.uuid
    @editor_open = params[:editor].present?
    @selected_option_id = params[:option_id].presence || @workspace[:categories].first&.dig(:option)&.id
    @proposal = proposal_for(selected_category) if params[:copy] == "review"
  end

  def create
    mutate(:created) { save_new }
  end

  def update
    mutate(:updated) { save_existing }
  end

  def destroy
    mutate(:removed) { remove_terms }
  end

  def preview
    assign_submitted
    append_custom_row if params[:add_row].present?
    @preview = preview_totals unless params[:add_row].present?
    @editor_open = true
    render :show, status: :ok
  end

  private

  def require_client_terms_access!
    raise ActiveRecord::RecordNotFound unless Current.agency_user&.permitted?(:manage_departures)
  end

  def assign_offer
    version, = selected_sailing_version
    shape = DetectCruiseArrangementShape.new(agency: Current.agency, arrangement: @supplier_arrangement, version: version).call
    raise ActiveRecord::RecordNotFound unless shape.compatible?

    offer = CruiseServiceConnectionSupport.offers_pinning_item(shape.item).first
    raise ActiveRecord::RecordNotFound if offer.nil?

    draft = offer.editable_draft_version || offer.versions.order(:created_at).last
    @offer = offer
    @workspace = CompileCruiseClientTermsWorkspace.new(agency: Current.agency, offer: offer, version: draft).call
    @reviews = @workspace[:categories].index_by { |category| category[:option].id }.transform_values do |category|
      CompileCruiseScenarioReview.new(
        agency: Current.agency, actor: Current.agency_user, offer: offer, version: draft, option: category[:option]
      ).call
    end
    @selected_option_id = params[:option_id].presence
  end

  def mutate(status)
    yield
    redirect_to departure_arrangement_cruise_client_terms_path(@departure, @supplier_arrangement), status: :see_other, notice: "Client terms #{status}."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    assign_submitted
    @form_error = error.message
    @editor_open = true
    render :show, status: :unprocessable_entity
  end

  def save_new
    CreateCruiseClientTermSchedule.new(
      agency: Current.agency, actor: Current.agency_user, offer: @offer,
      idempotency_key: params[:idempotency_key], attributes: term_attributes
    ).call
  end

  def save_existing
    UpdateCruiseClientTermSchedule.new(
      agency: Current.agency, actor: Current.agency_user, offer: @offer, attributes: term_attributes
    ).call
  end

  def remove_terms
    RemoveCruiseClientTermSchedule.new(
      agency: Current.agency, actor: Current.agency_user, offer: @offer, attributes: term_attributes
    ).call
  end

  def term_attributes
    {
      choice_option_id: params[:option_id],
      version_lock_version: params[:version_lock_version],
      arrangement_lock_version: params[:arrangement_lock_version],
      cells: submitted_cells
    }
  end

  def submitted_cells
    rows = permitted_rows
    rows.flat_map do |row_key, bands|
      label = bands["label"]
      CruiseClientTermRows::BANDS.filter_map do |band|
        amount = bands[band]
        next if amount.nil?

        provenance = bands["provenance_#{band}"]
        {
          row_key: row_key, band: band, amount: amount, label: label,
          supplier_cost_component_id: bands["source_#{band}"],
          recopy: provenance == "recopy" || bands["recopy_#{band}"],
          clear_provenance: provenance == "clear" || bands["clear_#{band}"]
        }
      end
    end
  end

  def assign_submitted
    @submitted = permitted_rows
    @selected_option_id = params[:option_id]
    @idempotency_key = params[:idempotency_key]
  end

  def permitted_rows
    raw = params[:rows]
    return {} unless raw.respond_to?(:keys)

    raw.keys.index_with { |row_key| raw[row_key].permit(*self.class::ROW_PERMIT).to_h }
  end

  ROW_PERMIT = (
    %i[label single first second additional] +
    CruiseClientTermRows::BANDS.flat_map { |band| [ :"source_#{band}", :"provenance_#{band}", :"recopy_#{band}", :"clear_#{band}" ] }
  ).freeze

  def append_custom_row
    kind = params[:add_row].to_s
    return unless %w[surcharge discount].include?(kind)

    key = kind == "discount" ? "custom_discount_#{SecureRandom.hex(8)}" : CruiseClientTermRows.mint_custom_key
    @submitted[key] = { "label" => (kind == "discount" ? "Discount" : "Surcharge") }
  end

  def preview_totals
    category = selected_category
    return [] if category.nil?

    currency = @departure.operating_currency
    option = category[:option]
    CompileCruiseScenarioReview::SCENARIOS.filter_map do |name, spec|
      next unless spec[:positions].all? { |band| category[:bands].enabled.include?(band) }

      cells = submitted_cells.select { |cell| spec[:positions].include?(cell[:band]) && cell[:amount].present? }
      pending = spec[:positions].select { |band| cells.none? { |cell| cell[:row_key] == "cruise_fare" && cell[:band] == band } }
      components = cells.each_with_index.map do |cell, index|
        {
          label: cell[:label].presence || CruiseClientTermRows.label_for(cell[:row_key]),
          client_role: CruiseClientTermRows.role_for(cell[:row_key]),
          calculation_kind: "unit_rate",
          amount_minor_units: Money.from_amount(BigDecimal(cell[:amount]), currency).fractional,
          quantity_basis: "occupancy_positions",
          client_rate_category_key: option.client_rate_category_key,
          occupancy_position_key: cell[:band],
          position: index + 1
        }
      end
      price = if components.any?
        EvaluateClientPrice.new(
          definition: { currency: currency, mode: "calculated", components: components },
          scenario: EvaluateClientPrice::Scenario.build(
            occupancy_positions: spec[:positions].map { |key| { key: key, rate_category: option.client_rate_category_key } },
            persons: spec[:persons],
            resource_units: 1
          )
        ).call
      end
      { name: name, total_minor: price&.complete ? price.amount_minor_units : nil, pending: pending, currency: currency, price: price }
    end
  rescue ArgumentError
    []
  end

  def proposal_for(category)
    return if category.nil? || category[:bands].advanced?

    ProposeCruiseSupplierTermCopy.new(
      agency: Current.agency,
      arrangement_version: category[:binding].supplier_arrangement_version,
      resource: category[:resource],
      enabled_bands: category[:bands].enabled
    ).call
  end

  helper_method :client_term_amount

  def client_term_amount(value)
    return "" if value.blank?
    return value if value.is_a?(String)
    return format("%.2f", value.amount) if value.respond_to?(:amount)

    value.to_s
  end

  def selected_category
    @workspace[:categories].find { |category| category[:option].id == @selected_option_id }
  end

  def selected_sailing_version
    version = @supplier_arrangement.versions.find_by(status: "draft") || @supplier_arrangement.governing_version
    [ version, version&.draft? ]
  end
end
