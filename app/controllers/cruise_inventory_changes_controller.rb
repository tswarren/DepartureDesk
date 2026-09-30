# frozen_string_literal: true

class CruiseInventoryChangesController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :require_active_cruise!

  def show
    @governing_version = governing_version!
    @successor = draft_successor
  end

  def same_terms
    prepare_same_terms
  end

  def create_same_terms
    prepare_same_terms
    if params[:commit] == "Review this increase"
      assign_preview
      render :same_terms, status: :unprocessable_entity
      return
    end

    result = RecordCruiseSameTermsCapacityIncrease.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      pool_id: params.require(:capacity_pool_id),
      quantity: params[:quantity],
      rate_minor_units: money_minor(params[:rate_amount]),
      evidence: {
        evidence_kind: "supplier_confirmation",
        evidence_on: params[:evidence_on],
        evidence_reference_note: params[:evidence_reference_note]
      },
      idempotency_key: params.require(:idempotency_key),
      effective_on: params[:effective_on].presence
    ).call
    redirect_to departure_arrangement_cruise_cabin_categories_path(@departure, @supplier_arrangement),
      notice: same_terms_notice(result.record)
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @command_error = error.message
    render :same_terms, status: :unprocessable_entity
  end

  def changed_terms
    if draft_successor
      redirect_to departure_arrangement_cruise_inventory_change_path(@departure, @supplier_arrangement),
        alert: "A successor draft already exists."
      return
    end

    prepare_changed_terms
  end

  def create_changed_terms
    if draft_successor
      redirect_to departure_arrangement_cruise_inventory_change_path(@departure, @supplier_arrangement),
        alert: "A successor draft already exists."
      return
    end

    prepare_changed_terms
    created = CreateCruiseSupplementalBlock.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      arrangement_lock_version: params.require(:arrangement_lock_version),
      version_lock_version: params.require(:version_lock_version),
      idempotency_key: params.require(:idempotency_key),
      maximum_occupancy: params[:maximum_occupancy],
      opening_quantity: params[:opening_quantity],
      supplier_resource_id: params[:supplier_resource_id]
    ).call
    definition = created.record.version.supplier_resource_definitions.find_by!(
      supplier_resource_id: created.record.resource.id
    )
    redirect_to departure_arrangement_cruise_cabin_categories_path(@departure, @supplier_arrangement),
      notice: [ "#{definition.name} added on a new successor.", client_offering_sentence ].compact.join(" ")
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @command_error = error.message
    render :changed_terms, status: :unprocessable_entity
  end

  private

  def require_active_cruise!
    return if @supplier_arrangement.active? && @supplier_arrangement.governing_version&.activated?

    redirect_to departure_arrangement_cruise_path(@departure, @supplier_arrangement),
      alert: "Change inventory is available after this Cruise is active."
  end

  def governing_version!
    version = @supplier_arrangement.governing_version
    raise ActiveRecord::RecordNotFound unless version&.activated?

    version
  end

  def draft_successor
    @supplier_arrangement.versions.find_by(status: "draft")
  end

  def prepare_same_terms
    @governing_version = governing_version!
    @successor = draft_successor
    @pool_options = eligible_pool_options(@governing_version)
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    requested_pool_id = params[:capacity_pool_id].presence
    @selected_pool_id = if @pool_options.any? { |_label, id| id == requested_pool_id }
      requested_pool_id
    else
      @pool_options.first&.last
    end
    @selected_pool_context = selected_pool_context(@governing_version, @selected_pool_id)
  end

  def prepare_changed_terms
    @governing_version = governing_version!
    @category_options = category_options(@governing_version)
    @selected_category_id = params[:supplier_resource_id].presence || @category_options.first&.last
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
  end

  def category_options(version)
    version.supplier_resource_definitions.order(:position, :id).filter_map do |definition|
      code = definition.supplier_code.to_s.strip
      next if code.blank?

      [ [ code, definition.name ].compact_blank.join(" · "), definition.supplier_resource_id ]
    end
  end

  def selected_pool_context(version, pool_id)
    return if pool_id.blank?

    resources = version.supplier_resource_definitions.index_by(&:supplier_resource_id)
    definition = version.capacity_pool_definitions.includes(capacity_pool: :capacity_projection)
      .find { |row| row.capacity_pool_id == pool_id }
    return unless definition

    pool = definition.capacity_pool
    return unless pool.numeric_inventory?

    resource = resources[definition.supplier_resource_id]
    label = [ resource&.supplier_code, resource&.name ].compact_blank.join(" · ")
    {
      id: pool.id,
      label: label.presence || "Cabin category",
      current_capacity: CompileCruiseCompositionSummary.current_supplier_capacity(pool)
    }
  end

  def eligible_pool_options(version)
    resources = version.supplier_resource_definitions.index_by(&:supplier_resource_id)
    version.capacity_pool_definitions.includes(:capacity_pool).order(:position, :id).filter_map do |definition|
      pool = definition.capacity_pool
      next unless pool.numeric_inventory?

      resource = resources[definition.supplier_resource_id]
      label = [ resource&.supplier_code, resource&.name ].compact_blank.join(" · ")
      [ label.presence || "Cabin block", pool.id ]
    end
  end

  def assign_preview
    quantity = Integer(params[:quantity], exception: false)
    rate = money_minor(params[:rate_amount])
    if params[:rate_amount].to_s.strip.blank? || rate.nil? || quantity.nil? || quantity <= 0
      @preview_error = "Enter a positive cabin quantity and a per-cabin deposit rate. Use 0 when the Supplier charged no deposit for these cabins."
      return
    end

    @preview = {
      quantity: quantity,
      rate_label: helpers.format_offer_money(rate, @departure.operating_currency),
      total_label: helpers.format_offer_money(quantity * rate, @departure.operating_currency)
    }
  end

  def same_terms_notice(requirement)
    pool = @governing_version.capacity_pool_definitions.find_by!(capacity_pool_id: requirement.capacity_pool_id).capacity_pool
    projection = pool.capacity_projection&.current_supplier_capacity
    opening = @governing_version.capacity_pool_definitions.find_by!(capacity_pool_id: pool.id).proposed_opening_quantity
    deposit = helpers.format_offer_money(requirement.amount_minor_units, requirement.currency)
    [
      "Current active capacity is #{projection} cabins.",
      "Increase deposit #{deposit}.",
      "Original opening quantity remains #{opening}.",
      client_offering_sentence
    ].compact.join(" ")
  end

  def client_offering_sentence
    shape = DetectCruiseArrangementShape.new(agency: Current.agency, arrangement: @supplier_arrangement).call
    return unless shape.compatible?

    workspace = CompileCruiseServiceConnectionWorkspace.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement,
      shape: shape
    ).call
    return unless workspace.status == :connected

    "Supplier inventory has changed. Client offering has not been changed automatically."
  end

  def money_minor(display)
    text = display.to_s.strip
    return nil if text.blank?

    Money.from_amount(BigDecimal(text), @departure.operating_currency).fractional
  rescue ArgumentError
    nil
  end
end
