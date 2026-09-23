# frozen_string_literal: true

class CruiseDepositsAndDeadlinesController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :require_compatible_cruise_shape!

  def show
    @workspace = CompileCruiseDepositsAndDeadlinesWorkspace.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement,
      version: @cruise_shape.version
    ).call
    @supplier_arrangement_version = @workspace.version
    @editable = @workspace.editable?
    @editor = params[:editor].to_s
    @editing_id = params[:deadline_id].presence
    @idempotency_key = SecureRandom.uuid
    assign_form_defaults
    assign_coverage_options
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

  def assign_form_defaults
    @form = (@form || {}).with_indifferent_access
    return if @form[:template].present?

    if @editing_id.present?
      row = @workspace.deadline_rows.find { |entry| entry.definition.id == @editing_id }
      if row&.compatible? && row.projected_fields
        fields = row.projected_fields.with_indifferent_access
        @form = {
          template: fields[:template],
          kind: fields[:kind],
          other_label: fields[:other_label],
          description: fields[:description],
          warning_lead_days: fields[:warning_lead_days],
          coverage_scope: fields.dig(:coverage, :scope),
          supplier_resource_id: fields.dig(:coverage, :supplier_resource_id),
          capacity_pool_id: fields.dig(:coverage, :capacity_pool_id)
        }.merge(fields[:timing] || {}).with_indifferent_access
        return
      end
    end

    @form = {
      template: "option_or_release",
      kind: "actionable",
      rule_shape: "fixed_date",
      coverage_scope: "arrangement",
      time_zone: @departure.time_zone
    }.with_indifferent_access
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
