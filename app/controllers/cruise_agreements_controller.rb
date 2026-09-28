# frozen_string_literal: true

class CruiseAgreementsController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_supplier_arrangement

  def provisional
    record_agreement("save_provisional")
  end

  def confirm
    record_agreement("confirm")
  end

  def correct
    record_agreement("correct")
  end

  def terms
    amount = money_minor(params[:allocated_amount])
    credit = money_minor(params[:allocated_credit])
    allocated = if amount || params[:allocated_body].present?
      {
        amount_minor_units: amount,
        credit_minor_units: credit || 0,
        currency: @departure.operating_currency,
        body: params[:allocated_body]
      }
    end
    steps = if params[:cancellation_body].present? || params[:cancellation_days].present?
      [ { days_before_departure: params[:cancellation_days], body: params[:cancellation_body] } ]
    end
    RecordCruiseAgreementTerms.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      version_lock_version: params.require(:version_lock_version),
      idempotency_key: params.require(:idempotency_key),
      allocated_cabin_deposit: allocated,
      card_restrictions: params[:card_restrictions],
      cancellation_steps: steps
    ).call
    redirect_to cruise_path, notice: "Readable terms recorded. Charges are not calculated."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to cruise_path, alert: error.message
  end

  def same_terms_increase
    RecordCruiseSameTermsCapacityIncrease.new(
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
      idempotency_key: params.require(:idempotency_key)
    ).call
    redirect_to cruise_path, notice: "Same-terms capacity increase recorded."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to cruise_path, alert: error.message
  end

  def supplemental_block
    CreateCruiseSupplementalBlock.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      arrangement_lock_version: params.require(:arrangement_lock_version),
      version_lock_version: params.require(:version_lock_version),
      idempotency_key: params.require(:idempotency_key),
      maximum_occupancy: params[:maximum_occupancy],
      opening_quantity: params[:opening_quantity]
    ).call
    redirect_to cruise_path, notice: "Supplemental O1 block added on a new successor."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to cruise_path, alert: error.message
  end

  private

  def record_agreement(intent)
    RecordCruiseSupplierAgreement.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      intent: intent,
      version_lock_version: params.require(:version_lock_version),
      idempotency_key: params.require(:idempotency_key),
      group_creation_date: params[:group_creation_date],
      group_reference: params[:group_reference],
      contract_date: params[:contract_date],
      note: params[:note],
      deposit_treatment: params[:deposit_treatment]
    ).call
    redirect_to cruise_path, notice: "Cruise agreement recorded."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to cruise_path, alert: error.message
  end

  def cruise_path
    departure_arrangement_cruise_path(@departure, @supplier_arrangement)
  end

  def money_minor(display)
    text = display.to_s.strip
    return nil if text.blank?

    Money.from_amount(BigDecimal(text), @departure.operating_currency).fractional
  rescue ArgumentError
    nil
  end
end
