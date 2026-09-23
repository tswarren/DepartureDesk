# frozen_string_literal: true

class CruiseSupplierDeadlinesController < ApplicationController
  include SupplierArrangementAccess

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
    redirect_to departure_arrangement_cruise_deposits_and_deadlines_path(
      @departure, @supplier_arrangement,
      anchor: "cruise-deadline-#{result.record.id}"
    ), notice: "Deadline saved."
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
    redirect_to departure_arrangement_cruise_deposits_and_deadlines_path(
      @departure, @supplier_arrangement,
      anchor: "cruise-deadline-#{result.record.id}"
    ), notice: "Deadline updated."
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
    form = deadline_form_params.to_h.with_indifferent_access
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

  def render_workspace_with_error(error, editor:, editing_id: nil)
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
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    @form = deadline_form_params.to_h.with_indifferent_access
    assign_coverage_options
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
end
