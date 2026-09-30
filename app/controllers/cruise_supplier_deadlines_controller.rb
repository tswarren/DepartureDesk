# frozen_string_literal: true

class CruiseSupplierDeadlinesController < ApplicationController
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
    attributes = compiled_attributes!
    result = CreateSupplierDeadlineDefinition.new(
      agency: Current.agency,
      actor: Current.agency_user,
      version: @cruise_shape.version,
      attributes: attributes,
      version_lock_version: params.require(:version_lock_version),
      idempotency_key: params.require(:idempotency_key)
    ).call
    redirect_to saved_deadline_path(result.record), notice: "Deadline saved."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    render_workspace_with_error(error, editor: "new")
  end

  def update
    attributes = compiled_attributes!
    result = UpdateSupplierDeadlineDefinition.new(
      agency: Current.agency,
      actor: Current.agency_user,
      definition: @definition,
      attributes: attributes,
      lock_version: params.require(:lock_version)
    ).call
    redirect_to saved_deadline_path(result.record), notice: "Deadline updated."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    render_workspace_with_error(error, editor: "edit", editing_id: @definition.id)
  end

  def destroy
    RemoveSupplierDeadlineDefinition.new(
      agency: Current.agency,
      actor: Current.agency_user,
      definition: @definition,
      version_lock_version: params.require(:version_lock_version)
    ).call
    redirect_to departure_arrangement_cruise_deposits_and_deadlines_path(
      @departure, @supplier_arrangement
    ), notice: "Deadline removed."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to departure_arrangement_cruise_deposits_and_deadlines_path(
      @departure, @supplier_arrangement
    ), alert: error.message
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

    redirect_to departure_arrangement_cruise_deposits_and_deadlines_path(
      @departure, @supplier_arrangement
    ), alert: "Create a successor draft before editing deadlines."
  end

  def set_definition
    version = @cruise_shape.version
    raise ActiveRecord::RecordNotFound unless version&.draft?

    @definition = version.supplier_deadline_definitions.find(params[:id])
  end

  def deadline_form_params
    params.fetch(:cruise_deadline, {}).permit(
      :template, :kind, :other_label, :description, :warning_lead_days,
      :rule_shape, :fixed_date, :fixed_datetime, :offset_days, :offset_hours,
      :arm1_rule_shape, :arm1_fixed_date, :arm1_fixed_datetime, :arm1_offset_days, :arm1_offset_hours,
      :arm2_rule_shape, :arm2_fixed_date, :arm2_fixed_datetime, :arm2_offset_days, :arm2_offset_hours,
      :coverage_scope, :supplier_resource_id, :capacity_pool_id
    )
  end

  def compiled_attributes!
    form = preserved_deadline_form
    CruiseDeadlineTemplateSupport.compile_attributes(
      template_key: form[:template],
      kind: form[:kind],
      other_label: form[:other_label],
      description: form[:description],
      warning_lead_days: form[:warning_lead_days],
      timing: form,
      coverage: {
        scope: form[:coverage_scope],
        supplier_resource_id: form[:supplier_resource_id],
        capacity_pool_id: form[:capacity_pool_id]
      },
      arrangement: @supplier_arrangement,
      version: @cruise_shape.version,
      cruise_item: @cruise_shape.item
    )
  end

  def preserved_deadline_form
    form = deadline_form_params.to_h.with_indifferent_access
    return form unless agreement_return? && @definition

    projected = CruiseDeadlineTemplateSupport.project_editor_fields(@definition)
    form[:description] = projected[:description] unless deadline_form_params.key?(:description)
    unless deadline_form_params.key?(:warning_lead_days)
      form[:warning_lead_days] = projected[:warning_lead_days]
    end
    form[:kind] = projected[:kind] if form[:kind].blank?
    coverage = projected[:coverage] || {}
    form[:coverage_scope] = coverage[:scope] if form[:coverage_scope].blank?
    form[:supplier_resource_id] = coverage[:supplier_resource_id] if form[:supplier_resource_id].blank?
    form[:capacity_pool_id] = coverage[:capacity_pool_id] if form[:capacity_pool_id].blank?
    form
  end

  def saved_deadline_path(record)
    unless agreement_return?
      return departure_arrangement_cruise_deposits_and_deadlines_path(
        @departure, @supplier_arrangement, focus_deadline_id: record.id
      )
    end

    agreement_page_path(highlight: "deadline-#{record.id}")
  end

  def render_workspace_with_error(error, editor:, editing_id: nil)
    if agreement_return?
      focus = if @definition
        "deadline-#{@definition.id}"
      elsif deadline_form_params[:template].in?(%w[hard_stop option_or_release])
        "deadline-new-hard-stop"
      elsif deadline_form_params[:template] == "final_payment"
        "deadline-new-final-payment"
      else
        "deadlines"
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
    @editor = editor
    @editing_id = editing_id
    @deposit_editor = nil
    @editing_deposit_id = nil
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    @form = deadline_form_params.to_h.with_indifferent_access
    @deposit_form = {
      template: "initial_deposit",
      amount_shape: "quantity_times_rate",
      quantity_basis: "capacity_pool_units",
      rule_shape: "fixed_date",
      capacity_pool_ids: [],
      contributor_definition_ids: []
    }.with_indifferent_access
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
    @contributor_options = version.supplier_deposit_requirement_definitions
      .order(:position, :id)
      .filter_map { |definition|
        next unless definition.amount_shape == "quantity_times_rate" &&
          definition.quantity_basis == "capacity_pool_units"

        [ definition.description.presence || "Deposit #{definition.position}", definition.id ]
      }
  end
end
