# frozen_string_literal: true

class HotelAgreementDeadlinesController < ApplicationController
  include HotelArrangementAccess

  before_action :require_departure_management!
  before_action :set_departure
  before_action :ensure_composable_departure!
  before_action :set_supplier_arrangement
  before_action :set_hotel_agreement_version
  before_action :set_lodging_hotel_item
  before_action :assign_hotel_composition_context
  before_action :require_editable_agreement!
  before_action :set_definition, only: %i[edit update destroy]

  def new
    @deadline_type = "rooming_list_due"
    @other_label = nil
    @due_on = nil
    @due_time = nil
    @idempotency_key = SecureRandom.uuid
  end

  def create
    assign_form_fields
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    CreateSupplierDeadlineDefinition.new(
      agency: Current.agency,
      actor: Current.agency_user,
      version: @supplier_arrangement_version,
      attributes: deadline_attributes("actionable"),
      version_lock_version: @supplier_arrangement_version.lock_version,
      idempotency_key: @idempotency_key
    ).call
    redirect_to hotel_agreement_path_for, notice: "Deadline saved."
  rescue AgencyCommand::Error => error
    hotel_command_error(error, :new)
  end

  def edit
    @deadline_type = @definition.deadline_type
    @other_label = @definition.other_label
    parameters = @definition.rule_parameters || {}
    if @definition.fixed_local_datetime?
      date_text, time_text = parameters["datetime"].to_s.split("T", 2)
      @due_on = date_text
      @due_time = time_text.to_s[0, 5]
    else
      @due_on = parameters["date"]
      @due_time = nil
    end
  end

  def update
    assign_form_fields
    UpdateSupplierDeadlineDefinition.new(
      agency: Current.agency,
      actor: Current.agency_user,
      definition: @definition,
      attributes: deadline_attributes(@definition.kind).merge(lock_version: params[:lock_version]),
      lock_version: params[:lock_version]
    ).call
    redirect_to hotel_agreement_path_for, notice: "Deadline saved."
  rescue AgencyCommand::Error => error
    hotel_command_error(error, :edit)
  end

  def destroy
    RemoveSupplierDeadlineDefinition.new(
      agency: Current.agency,
      actor: Current.agency_user,
      definition: @definition,
      version_lock_version: @supplier_arrangement_version.lock_version
    ).call
    redirect_to hotel_agreement_path_for, notice: "Deadline removed."
  rescue AgencyCommand::Error => error
    redirect_to hotel_agreement_path_for, alert: error.message
  end

  private

  def require_editable_agreement!
    raise ActiveRecord::RecordNotFound unless hotel_agreement_editable?
  end

  def set_definition
    @definition = @supplier_arrangement_version.supplier_deadline_definitions.find(params[:id])
    workspace = HotelAgreementWorkspace.new(
      agency: Current.agency,
      departure: @departure,
      arrangement: @supplier_arrangement,
      version: @supplier_arrangement_version,
      item: @arrangement_item
    ).call
    row = workspace.deadlines.find { |candidate| candidate.definition.id == @definition.id && candidate.thin }
    raise ActiveRecord::RecordNotFound if row.nil?
  end

  def assign_form_fields
    @deadline_type = params[:deadline_type]
    @other_label = params[:other_label]
    @due_on = params[:due_on]
    @due_time = params[:due_time]
  end

  def deadline_attributes(kind)
    due_on = params[:due_on].to_s
    due_time = params[:due_time].to_s.strip
    if due_time.present?
      rule_shape = "fixed_local_datetime"
      precision = "local_date_time"
      rule_parameters = { "datetime" => "#{due_on}T#{normalize_time(due_time)}" }
    else
      rule_shape = "fixed_date"
      precision = "date_only"
      rule_parameters = { "date" => due_on }
    end
    {
      deadline_type: params[:deadline_type].to_s,
      other_label: params[:other_label],
      kind: kind,
      rule_shape: rule_shape,
      precision: precision,
      cardinality: "one_shared",
      time_zone: @departure.time_zone,
      warning_lead_days: @definition&.warning_lead_days,
      description: @definition&.description,
      rule_parameters: rule_parameters,
      coverage_links: [ { arrangement_item_id: @arrangement_item.id } ],
      commitment_lines: []
    }
  end

  def normalize_time(value)
    parts = value.split(":")
    return value if parts.size >= 3

    format("%02d:%02d:00", parts[0].to_i, parts[1].to_i)
  end
end
