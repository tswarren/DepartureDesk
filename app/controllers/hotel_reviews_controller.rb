# frozen_string_literal: true

class HotelReviewsController < ApplicationController
  include HotelArrangementAccess

  before_action :require_departure_view!
  before_action :require_composition_access!, only: %i[confirm revise activate]
  before_action :set_departure
  before_action :ensure_composable_departure!
  before_action :set_supplier_arrangement
  before_action :set_hotel_agreement_version
  before_action :set_lodging_hotel_item
  before_action :assign_hotel_composition_context

  def show
    load_review
    @idempotency_key = SecureRandom.uuid
  end

  def confirm
    RecordHotelSupplierConfirmation.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      version: @supplier_arrangement_version,
      arrangement_item: @arrangement_item,
      idempotency_key: params[:idempotency_key],
      evidence_attributes: confirmation_params,
      identifier_attributes: identifier_params.presence,
      duplicate_acknowledgement_token: params[:duplicate_acknowledgement_token]
    ).call
    redirect_to review_path, notice: "Supplier confirmed."
  rescue AgencyCommand::DuplicateReviewRequired => error
    load_review
    @idempotency_key = params[:idempotency_key]
    @acknowledgement_token = error.token
    flash.now[:alert] = error.message
    render :show, status: :unprocessable_entity
  rescue AgencyCommand::Error => error
    rescue_review(error)
  end

  def revise
    ReviseConfirmedHotelAgreement.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      reason: params[:reason],
      idempotency_key: params[:idempotency_key],
      arrangement_lock_version: params[:arrangement_lock_version],
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to review_path, notice: "A new Hotel draft is ready to confirm."
  rescue AgencyCommand::Error => error
    rescue_review(error)
  end

  def activate
    result = ActivateSupplierArrangementVersion.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      version: @supplier_arrangement_version,
      arrangement_lock_version: params[:arrangement_lock_version],
      version_lock_version: params[:version_lock_version],
      idempotency_key: params[:idempotency_key],
      existing_confirmation_id: params[:existing_confirmation_id],
      cost_source_coverage_acknowledged: params[:cost_source_coverage_acknowledged],
      provisional_costs_acknowledged: params[:provisional_costs_acknowledged],
      commitment_trigger_coverage_acknowledged: params[:commitment_trigger_coverage_acknowledged],
      elapsed_deadlines_acknowledged: params[:elapsed_deadlines_acknowledged]
    ).call
    redirect_to hotel_agreement_path_for, notice: result.status == :replayed ? "Arrangement was already activated." : "Arrangement activated."
  rescue AgencyCommand::Error => error
    rescue_review(error)
  end

  private

  helper_method :hotel_review_blocker_path

  def hotel_review_blocker_path(blocker)
    case blocker.target
    when :stay
      edit_item_stay_departure_arrangement_hotel_path(@departure, @supplier_arrangement, @arrangement_item, version_id: @supplier_arrangement_version.id)
    when :inventory
      item_inventory_departure_arrangement_hotel_path(@departure, @supplier_arrangement, @arrangement_item, version_id: @supplier_arrangement_version.id)
    when :rates
      item_rates_departure_arrangement_hotel_path(@departure, @supplier_arrangement, @arrangement_item, version_id: @supplier_arrangement_version.id)
    when :activation
      departure_arrangement_activation_path(@departure, @supplier_arrangement)
    else
      hotel_agreement_path_for
    end
  end

  def load_review
    @review = CompileHotelActivationReview.new(
      agency: Current.agency,
      departure: @departure,
      arrangement: @supplier_arrangement,
      version: @supplier_arrangement_version,
      item: @arrangement_item
    ).call
    @can_manage = Current.agency_user.permitted?(:manage_departures)
  end

  def review_path
    item_hotel_review_departure_arrangement_hotel_path(
      @departure, @supplier_arrangement, @arrangement_item, version_id: @supplier_arrangement_version.id
    )
  end

  def rescue_review(error)
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    load_review
    @idempotency_key = params[:idempotency_key]
    flash.now[:alert] = error.message
    render :show, status: :unprocessable_entity
  end

  def confirmation_params
    params.fetch(:confirmation, ActionController::Parameters.new).permit(
      :evidence_kind, :other_evidence_label, :evidence_on, :channel, :reference_note,
      :confirmed_without_identifier_reason
    )
  end

  def identifier_params
    params.fetch(:identifier, ActionController::Parameters.new).permit(
      :identifier_type, :other_type_label, :display_value, :issuer_context
    )
  end
end
