# frozen_string_literal: true

class HotelAgreementDepositsController < ApplicationController
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
    @due_on = nil
    @amount = nil
    @idempotency_key = SecureRandom.uuid
  end

  def create
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    @due_on = params[:due_on]
    @amount = params[:amount]
    minor = money_minor(@amount)
    if minor.nil?
      @form_error = "Enter the deposit amount."
      render :new, status: :unprocessable_entity
      return
    end

    CreateSupplierDepositRequirementDefinition.new(
      agency: Current.agency,
      actor: Current.agency_user,
      version: @supplier_arrangement_version,
      attributes: deposit_attributes(minor),
      version_lock_version: @supplier_arrangement_version.lock_version,
      idempotency_key: @idempotency_key
    ).call
    redirect_to hotel_agreement_path_for, notice: "Deposit saved."
  rescue AgencyCommand::Error => error
    hotel_command_error(error, :new)
  end

  def edit
    @due_on = @definition.rule_parameters["date"]
    @amount = Money.new(@definition.fixed_amount_minor_units, @definition.currency)
      .format(symbol: false, thousands_separator: false)
  end

  def update
    @due_on = params[:due_on]
    @amount = params[:amount]
    minor = money_minor(@amount)
    if minor.nil?
      @form_error = "Enter the deposit amount."
      render :edit, status: :unprocessable_entity
      return
    end

    UpdateSupplierDepositRequirementDefinition.new(
      agency: Current.agency,
      actor: Current.agency_user,
      definition: @definition,
      attributes: deposit_attributes(minor).merge(lock_version: params[:lock_version]),
      lock_version: params[:lock_version]
    ).call
    redirect_to hotel_agreement_path_for, notice: "Deposit saved."
  rescue AgencyCommand::Error => error
    hotel_command_error(error, :edit)
  end

  def destroy
    RemoveSupplierDepositRequirementDefinition.new(
      agency: Current.agency,
      actor: Current.agency_user,
      definition: @definition,
      version_lock_version: @supplier_arrangement_version.lock_version
    ).call
    redirect_to hotel_agreement_path_for, notice: "Deposit removed."
  rescue AgencyCommand::Error => error
    redirect_to hotel_agreement_path_for, alert: error.message
  end

  private

  def require_editable_agreement!
    raise ActiveRecord::RecordNotFound unless hotel_agreement_editable?
  end

  def set_definition
    @definition = @supplier_arrangement_version.supplier_deposit_requirement_definitions.find(params[:id])
    workspace = HotelAgreementWorkspace.new(
      agency: Current.agency,
      departure: @departure,
      arrangement: @supplier_arrangement,
      version: @supplier_arrangement_version,
      item: @arrangement_item
    ).call
    row = workspace.deposits.find { |candidate| candidate.definition.id == @definition.id && candidate.thin }
    raise ActiveRecord::RecordNotFound if row.nil?
  end

  def deposit_attributes(minor)
    {
      amount_shape: "fixed_amount",
      fixed_amount_minor_units: minor,
      currency: @departure.operating_currency,
      rule_shape: "fixed_date",
      precision: "date_only",
      time_zone: @departure.time_zone,
      rule_parameters: { "date" => params[:due_on].to_s },
      coverage_links: [ { arrangement_item_id: @arrangement_item.id } ],
      cost_links: [],
      contributor_definition_ids: []
    }
  end

  def money_minor(display)
    text = display.to_s.strip
    return nil if text.blank?

    Money.from_amount(BigDecimal(text), @departure.operating_currency).fractional
  rescue ArgumentError
    nil
  end
end
