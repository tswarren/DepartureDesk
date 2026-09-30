# frozen_string_literal: true

class CruiseSupplierDepositsController < ApplicationController
  include SupplierArrangementAccess
  include CruiseAgreementReview

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :require_compatible_cruise_shape!
  before_action :require_editable_draft!
  before_action :set_definition, only: %i[update destroy]

  def create
    candidate = normalize_candidate!
    result = CreateSupplierDepositRequirementDefinition.new(
      agency: Current.agency,
      actor: Current.agency_user,
      version: @cruise_shape.version,
      attributes: candidate.attributes,
      version_lock_version: params.require(:version_lock_version),
      idempotency_key: params.require(:idempotency_key)
    ).call
    redirect_to saved_deposit_path(result.record), notice: "Deposit requirement saved."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    render_workspace_with_error(error, deposit_editor: "new")
  end

  def update
    candidate = normalize_candidate!
    result = UpdateSupplierDepositRequirementDefinition.new(
      agency: Current.agency,
      actor: Current.agency_user,
      definition: @definition,
      attributes: candidate.attributes,
      lock_version: params.require(:lock_version)
    ).call
    redirect_to saved_deposit_path(result.record), notice: "Deposit requirement updated."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    render_workspace_with_error(error, deposit_editor: "edit", editing_deposit_id: @definition.id)
  end

  def destroy
    RemoveSupplierDepositRequirementDefinition.new(
      agency: Current.agency,
      actor: Current.agency_user,
      definition: @definition,
      version_lock_version: params.require(:version_lock_version)
    ).call
    redirect_to departure_arrangement_cruise_deposits_and_deadlines_path(
      @departure, @supplier_arrangement
    ), notice: "Deposit requirement removed."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to departure_arrangement_cruise_deposits_and_deadlines_path(
      @departure, @supplier_arrangement
    ), alert: error.message
  end

  def preview
    candidate = normalize_candidate!
    result = PreviewCruiseDepositRequirement.call(
      agency: Current.agency,
      arrangement: @supplier_arrangement,
      version: @cruise_shape.version,
      candidate: candidate,
      version_lock_version: params[:version_lock_version]
    )

    render json: {
      status: result.status,
      amount_minor_units: result.amount_minor_units,
      amount_display: format_preview_amount(result.amount_minor_units),
      pending_reasons: result.pending_reasons,
      quantity_label: result.quantity_label,
      stale: result.stale?,
      version_lock_version: result.version_lock_version,
      request_token: params[:request_token]
    }
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    render json: {
      status: "invalid",
      amount_minor_units: nil,
      amount_display: nil,
      pending_reasons: [ error.message ],
      quantity_label: nil,
      stale: false,
      version_lock_version: @cruise_shape.version.lock_version,
      request_token: params[:request_token]
    }, status: :unprocessable_entity
  end

  private

  def require_compatible_cruise_shape!
    @cruise_shape = DetectCruiseArrangementShape.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement
    ).call
    return if @cruise_shape.compatible?

    redirect_to departure_arrangement_cruise_path(@departure, @supplier_arrangement),
      alert: "Open advanced Supplier planning for this Arrangement."
  end

  def require_editable_draft!
    return if @cruise_shape.version&.draft?

    if action_name == "preview"
      render json: {
        status: "invalid",
        pending_reasons: [ "Create a successor draft before editing deposits." ]
      }, status: :unprocessable_entity
      return
    end

    redirect_to departure_arrangement_cruise_deposits_and_deadlines_path(
      @departure, @supplier_arrangement
    ), alert: "Create a successor draft before editing deposits."
  end

  def set_definition
    version = @cruise_shape.version
    raise ActiveRecord::RecordNotFound unless version&.draft?

    @definition = version.supplier_deposit_requirement_definitions.find(params[:id])
  end

  def deposit_form_params
    params.fetch(:cruise_deposit, {}).permit(
      :template, :description, :amount_shape, :quantity_basis,
      :fixed_amount, :fixed_amount_minor_units, :rate_amount, :rate_minor_units,
      :explicit_quantity, :coverage_scope,
      :rule_shape, :fixed_date, :fixed_datetime, :offset_days, :offset_hours,
      :arm1_rule_shape, :arm1_fixed_date, :arm1_fixed_datetime, :arm1_offset_days, :arm1_offset_hours,
      :arm1_milestone_kind,
      :arm2_rule_shape, :arm2_fixed_date, :arm2_fixed_datetime, :arm2_offset_days, :arm2_offset_hours,
      :arm2_milestone_kind,
      capacity_pool_ids: [],
      supplier_resource_ids: [],
      contributor_definition_ids: []
    )
  end

  def normalize_candidate!
    form = preserved_deposit_form
    CruiseDepositCandidateNormalizer.call(
      template_key: form[:template].presence || "other_deposit",
      form: form,
      arrangement: @supplier_arrangement,
      version: @cruise_shape.version,
      cruise_item: @cruise_shape.item,
      currency: @departure.operating_currency,
      cumulative_definition: @definition
    )
  end

  def preserved_deposit_form
    form = deposit_form_params.to_h.with_indifferent_access
    return form unless agreement_return? && @definition

    projected = CruiseDepositTemplateSupport.project_editor_fields(@definition)
    form[:description] = projected[:description] unless deposit_form_params.key?(:description)
    form[:capacity_pool_ids] = projected[:capacity_pool_ids] if Array(form[:capacity_pool_ids]).blank?
    form[:amount_shape] = projected[:amount_shape] if form[:amount_shape].blank?
    form[:quantity_basis] = projected[:quantity_basis] if form[:quantity_basis].blank?
    if Array(form[:contributor_definition_ids]).blank?
      form[:contributor_definition_ids] = projected[:contributor_definition_ids]
    end
    if form[:explicit_quantity].blank? && projected[:explicit_quantity].present?
      form[:explicit_quantity] = projected[:explicit_quantity]
    end
    form
  end

  def saved_deposit_path(record)
    return deposits_page_path(focus_deposit_id: record.id) unless agreement_return?

    template = CruiseDepositTemplateSupport.recognize_template(record)
    highlight = template == "initial_deposit" ? "deposit-#{record.id}" : "requirement-deposit-#{record.id}"
    agreement_page_path(highlight: highlight)
  end

  def deposits_page_path(**query)
    departure_arrangement_cruise_deposits_and_deadlines_path(@departure, @supplier_arrangement, **query)
  end

  def format_preview_amount(minor_units)
    return nil if minor_units.nil?

    Money.new(minor_units, @departure.operating_currency).format
  end

  def render_workspace_with_error(error, deposit_editor:, editing_deposit_id: nil)
    if agreement_return?
      focus = if @definition
        "deposit-#{@definition.id}"
      elsif deposit_form_params[:template] == "initial_deposit"
        "deposit-new-initial"
      else
        "deposits"
      end
      render_agreement_review_error(error, focus: focus)
      return
    end

    @form_error = error.message
    flash.now[:alert] = error.message
    @workspace = CompileCruiseDepositsAndDeadlinesWorkspace.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement,
      version: @cruise_shape.version
    ).call
    @supplier_arrangement_version = @workspace.version
    @editable = @workspace.editable?
    @deposit_editor = deposit_editor
    @editing_deposit_id = editing_deposit_id
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    @deposit_form = deposit_form_params.to_h.with_indifferent_access
    assign_coverage_options
    assign_contributor_options
    render "cruise_deposits_and_deadlines/show", status: :unprocessable_entity
  end

  def assign_coverage_options
    version = @cruise_shape.version
    @resource_options = version.supplier_resource_definitions.order(:position, :id).map { |definition|
      [
        definition.supplier_code.presence || definition.name,
        definition.supplier_resource_id
      ]
    }
    @pool_options = version.capacity_pool_definitions.order(:id).map { |definition|
      resource_definition = version.supplier_resource_definitions
        .find { |row| row.supplier_resource_id == definition.supplier_resource_id }
      label = [
        resource_definition&.supplier_code.presence || resource_definition&.name,
        "pool"
      ].compact.join(" · ")
      [ label, definition.capacity_pool_id ]
    }
  end

  def assign_contributor_options
    version = @cruise_shape.version
    edit_position = @definition&.position
    @contributor_options = version.supplier_deposit_requirement_definitions
      .order(:position, :id)
      .filter_map { |definition|
        next if @definition && definition.id == @definition.id
        next if edit_position && definition.position >= edit_position
        next unless definition.amount_shape == "quantity_times_rate" &&
          definition.quantity_basis == "capacity_pool_units"

        [ definition.description.presence || "Deposit #{definition.position}", definition.id ]
      }
  end
end
