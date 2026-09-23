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
    @deposit_editor = params[:deposit_editor].to_s
    @editing_deposit_id = params[:deposit_id].presence
    @idempotency_key = SecureRandom.uuid
    assign_form_defaults
    assign_deposit_form_defaults
    assign_coverage_options
    assign_contributor_options
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

  def assign_deposit_form_defaults
    @deposit_form = (@deposit_form || {}).with_indifferent_access
    return if @deposit_form[:template].present?

    if @editing_deposit_id.present?
      row = @workspace.deposit_rows.find { |entry| entry.definition.id == @editing_deposit_id }
      if row&.compatible? && row.projected_fields
        fields = row.projected_fields.with_indifferent_access
        @deposit_form = {
          template: fields[:template],
          description: fields[:description],
          amount_shape: fields[:amount_shape],
          quantity_basis: fields[:quantity_basis],
          fixed_amount_minor_units: fields[:fixed_amount_minor_units],
          rate_minor_units: fields[:rate_minor_units],
          explicit_quantity: fields[:explicit_quantity],
          capacity_pool_ids: fields[:capacity_pool_ids],
          supplier_resource_ids: fields[:supplier_resource_ids],
          contributor_definition_ids: fields[:contributor_definition_ids]
        }.merge(fields[:timing] || {}).with_indifferent_access
        return
      end
    end

    @deposit_form = {
      template: "initial_deposit",
      description: "Initial deposit",
      amount_shape: "quantity_times_rate",
      quantity_basis: "capacity_pool_units",
      rule_shape: "fixed_date",
      capacity_pool_ids: [],
      contributor_definition_ids: []
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

  def assign_contributor_options
    version = @cruise_shape.version
    exclude_id = @editing_deposit_id
    @contributor_options = version.supplier_deposit_requirement_definitions
      .order(:position, :id)
      .filter_map { |definition|
        next if exclude_id.present? && definition.id.to_s == exclude_id.to_s
        next unless definition.amount_shape == "quantity_times_rate" &&
          definition.quantity_basis == "capacity_pool_units"

        [ definition.description.presence || "Deposit #{definition.position}", definition.id ]
      }
  end
end
