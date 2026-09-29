# frozen_string_literal: true

class CruiseAgreementsController < ApplicationController
  include SupplierArrangementAccess
  include CruiseAgreementReview

  before_action :require_departure_view!
  before_action :require_departure_management!, except: :show
  before_action :set_departure
  before_action :set_supplier_arrangement

  def show
    assign_cruise_agreement_review!
  end

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
    allocated, card, steps = term_arguments
    RecordCruiseAgreementTerms.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      version_lock_version: params.require(:version_lock_version),
      idempotency_key: params.require(:idempotency_key),
      allocated_cabin_deposit: allocated,
      card_restrictions: card,
      cancellation_steps: steps
    ).call
    redirect_to agreement_page_path(highlight: term_highlight),
      notice: "Supplier terms recorded. Charges are not calculated."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    render_agreement_review_error(error, focus: term_error_focus)
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
    redirect_to agreement_page_path(highlight: "agreement"), notice: "Cruise agreement recorded."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    render_agreement_review_error(error, focus: "agreement")
  end

  def term_arguments
    case params[:term_scope].to_s
    when "allocated"
      [
        {
          amount_minor_units: money_minor(params[:allocated_amount]),
          credit_minor_units: money_minor(params[:allocated_credit]),
          currency: @departure.operating_currency,
          body: params[:allocated_body]
        },
        nil,
        nil
      ]
    when "card"
      [ nil, params[:card_restrictions], nil ]
    when "cancellation"
      [ nil, nil, cancellation_steps_argument ]
    else
      raise AgencyCommand::Error.new("Enter a Cruise term to record.", code: :invalid)
    end
  end

  def cancellation_steps_argument
    rows = params[:cancellation_steps]
    return [] if rows.blank?

    list = rows.is_a?(ActionController::Parameters) ? rows.values : Array(rows)
    list.map do |step|
      values = step.respond_to?(:permit) ? step.permit(:days_before_departure, :body) : step
      values.to_h.slice("days_before_departure", "body", :days_before_departure, :body)
    end
  end

  def term_highlight
    case params[:term_scope].to_s
    when "allocated" then "term-allocated"
    when "card" then "term-card"
    else "term-cancellation"
    end
  end

  def term_error_focus
    case params[:term_scope].to_s
    when "allocated" then "term-allocated"
    when "card" then "term-card"
    when "cancellation" then params[:cancellation_editor].presence || "cancellation-new"
    else "terms"
    end
  end

  def money_minor(display)
    text = display.to_s.strip
    return nil if text.blank?

    Money.from_amount(BigDecimal(text), @departure.operating_currency).fractional
  rescue ArgumentError
    nil
  end
end
