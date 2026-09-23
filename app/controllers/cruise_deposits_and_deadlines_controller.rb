# frozen_string_literal: true

class CruiseDepositsAndDeadlinesController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!, only: :activation_preview
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :require_compatible_cruise_shape!

  def show
    load_workspace!
    @editor = params[:editor].to_s
    @editing_id = params[:deadline_id].presence
    @deposit_editor = params[:deposit_editor].to_s
    @editing_deposit_id = params[:deposit_id].presence
    normalize_single_editor!
    @idempotency_key = SecureRandom.uuid
    @planning_milestone_idempotency_key = SecureRandom.uuid
    assign_form_defaults
    assign_deposit_form_defaults
    assign_coverage_options
    assign_contributor_options
    assign_activation_preview if @editable
  end

  def activation_preview
    version = @cruise_shape.version
    raise ActiveRecord::RecordNotFound unless version.draft?

    result = PreviewCruiseDepositsAndDeadlinesActivation.call(
      agency: Current.agency,
      arrangement: @supplier_arrangement,
      version: version,
      version_lock_version: params[:version_lock_version]
    )

    render json: {
      status: result.status,
      stale: result.stale?,
      version_lock_version: result.version_lock_version,
      elapsed_acknowledgment_required: result.elapsed_acknowledgment_required?,
      blockers: result.blockers,
      unique_blockers: result.unique_blockers.map { |blocker| serialize_unique_blocker(blocker) },
      activation_path: result.activation_path,
      rows: result.rows.map { |row| serialize_activation_row(row) }
    }
  end

  private

  def load_workspace!
    version = @cruise_shape.version
    preview = if version.draft?
      PreviewCruiseDepositsAndDeadlinesActivation.call(
        agency: Current.agency,
        arrangement: @supplier_arrangement,
        version: version,
        version_lock_version: version.lock_version
      )
    end

    @workspace = CompileCruiseDepositsAndDeadlinesWorkspace.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement,
      version: version,
      activation_preview: preview
    ).call
    @supplier_arrangement_version = @workspace.version
    @editable = @workspace.editable?
    @activation_preview = preview if @editable
  end

  def assign_activation_preview
    return if @activation_preview

    @activation_preview = PreviewCruiseDepositsAndDeadlinesActivation.call(
      agency: Current.agency,
      arrangement: @supplier_arrangement,
      version: @supplier_arrangement_version,
      version_lock_version: @supplier_arrangement_version.lock_version
    )
  end

  # At most one deposit or deadline editor may be open (2B-UX §7.1).
  def normalize_single_editor!
    deposit_open = @deposit_editor.in?(%w[new edit])
    deadline_open = @editor.in?(%w[new edit])
    return unless deposit_open && deadline_open

    # Prefer the deposit editor when both query params are present.
    @editor = ""
    @editing_id = nil
  end

  def serialize_activation_row(row)
    {
      kind: row.kind,
      definition_id: row.definition_id,
      display_name: row.display_name,
      amount_sentence: row.amount_sentence,
      pending_reasons: row.pending_reasons,
      due_sentence: row.due_sentence,
      time_zone: row.time_zone,
      coverage_summary: row.coverage_summary,
      will_open_commitment: row.will_open_commitment?,
      elapsed_acknowledgment_required: row.elapsed_acknowledgment_required?,
      blocker: row.blocker,
      editor_anchor: row.editor_anchor,
      corrective_path: row.corrective_path,
      corrective_label: row.corrective_label
    }
  end

  def serialize_unique_blocker(blocker)
    {
      message: blocker.message,
      corrective_path: blocker.corrective_path,
      corrective_label: blocker.corrective_label,
      editor_anchor: blocker.editor_anchor,
      kind: blocker.kind,
      definition_id: blocker.definition_id
    }
  end

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
          coverage_scope: fields[:coverage_scope],
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
      coverage_scope: "arrangement",
      rule_shape: "fixed_date",
      capacity_pool_ids: [],
      supplier_resource_ids: [],
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
    editing = @editing_deposit_id.present? ?
      version.supplier_deposit_requirement_definitions.find_by(id: @editing_deposit_id) : nil
    edit_position = editing&.position
    @contributor_options = version.supplier_deposit_requirement_definitions
      .order(:position, :id)
      .filter_map { |definition|
        next if editing && definition.id == editing.id
        next if edit_position && definition.position >= edit_position
        next unless definition.amount_shape == "quantity_times_rate" &&
          definition.quantity_basis == "capacity_pool_units"

        [ definition.description.presence || "Deposit #{definition.position}", definition.id ]
      }
  end
end
