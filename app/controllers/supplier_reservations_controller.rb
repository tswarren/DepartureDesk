class SupplierReservationsController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!, except: %i[index show]
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :set_reservation_version
  before_action :set_supplier_reservation, only: %i[
    show edit update edit_abandon abandon request_booking withdraw respond cancel_scopes revise
  ]

  def index
    @reservations = @supplier_arrangement.supplier_reservations
      .includes(:booking_supplier, projection: :current_revision)
      .order(created_at: :desc, id: :desc)
  end

  def show
    prepare_reservation_show!
  end

  def new
    load_scope_options
    @idempotency_key = SecureRandom.uuid
  end

  def new_existing
    load_scope_options
    @idempotency_key = SecureRandom.uuid
  end

  def create
    result = CreateSupplierReservation.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      attributes: reservation_params,
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_arrangement_reservation_path(@departure, @supplier_arrangement, result.record),
      notice: result.status == :replayed ? "Reservation already exists." : "Reservation planned."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    load_scope_options
    @idempotency_key = params[:idempotency_key]
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  end

  def record_existing
    result = RecordExistingConfirmedSupplierReservation.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      attributes: existing_reservation_params,
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_arrangement_reservation_path(@departure, @supplier_arrangement, result.record),
      notice: result.status == :replayed ? "Existing confirmed reservation was already recorded." : "Existing confirmed reservation recorded."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    load_scope_options
    @idempotency_key = params[:idempotency_key]
    flash.now[:alert] = error.message
    render :new_existing, status: :unprocessable_entity
  end

  def edit
    @planned_revision = @supplier_reservation.revisions.where(status: "planned").sole
    load_scope_options(@planned_revision.supplier_arrangement_version)
  rescue ActiveRecord::SoleRecordExceeded, ActiveRecord::RecordNotFound
    redirect_to departure_arrangement_reservation_path(@departure, @supplier_arrangement, @supplier_reservation),
      alert: "Only planned reservations can be edited."
  end

  def update
    UpdatePlannedSupplierReservation.new(
      agency: Current.agency,
      actor: Current.agency_user,
      reservation: @supplier_reservation,
      attributes: reservation_params,
      revision_lock_version: params[:revision_lock_version]
    ).call
    redirect_to departure_arrangement_reservation_path(@departure, @supplier_arrangement, @supplier_reservation),
      notice: "Reservation plan updated."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @planned_revision = @supplier_reservation.revisions.where(status: "planned").first
    load_scope_options(@planned_revision&.supplier_arrangement_version || @supplier_arrangement_version)
    flash.now[:alert] = error.message
    render :edit, status: :unprocessable_entity
  end

  def edit_abandon
    @planned_revision = @supplier_reservation.revisions.where(status: "planned").sole
  rescue ActiveRecord::SoleRecordExceeded, ActiveRecord::RecordNotFound
    redirect_to departure_arrangement_reservation_path(@departure, @supplier_arrangement, @supplier_reservation),
      alert: "Only planned reservations can be abandoned."
  end

  def abandon
    AbandonPlannedSupplierReservation.new(
      agency: Current.agency,
      actor: Current.agency_user,
      reservation: @supplier_reservation,
      reason: params[:reason],
      revision_lock_version: params[:revision_lock_version]
    ).call
    redirect_to departure_arrangement_reservations_path(@departure, @supplier_arrangement),
      notice: "Reservation plan abandoned."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @planned_revision = @supplier_reservation.revisions.where(status: "planned").first
    flash.now[:alert] = error.message
    render :edit_abandon, status: :unprocessable_entity
  end

  def request_booking
    result = RecordSupplierReservationRequest.new(
      agency: Current.agency,
      actor: Current.agency_user,
      reservation: @supplier_reservation,
      attributes: request_params,
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_arrangement_reservation_path(@departure, @supplier_arrangement, @supplier_reservation),
      notice: result.status == :replayed ? "Reservation request was already recorded." : "Reservation request recorded."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    prepare_reservation_show!
    flash.now[:alert] = error.message
    render :show, status: :unprocessable_entity
  end

  def withdraw
    result = WithdrawSupplierReservation.new(
      agency: Current.agency,
      actor: Current.agency_user,
      reservation: @supplier_reservation,
      scope_ids: params[:scope_ids],
      reason: params[:reason],
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_arrangement_reservation_path(@departure, @supplier_arrangement, @supplier_reservation),
      notice: result.status == :replayed ? "Reservation withdrawal was already recorded." : "Reservation withdrawal recorded."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    prepare_reservation_show!
    flash.now[:alert] = error.message
    render :show, status: :unprocessable_entity
  end

  def respond
    result = RecordSupplierReservationResponse.new(
      agency: Current.agency,
      actor: Current.agency_user,
      reservation: @supplier_reservation,
      attributes: response_params,
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_arrangement_reservation_path(@departure, @supplier_arrangement, @supplier_reservation),
      notice: result.status == :replayed ? "Reservation response was already recorded." : "Reservation response recorded."
  rescue AgencyCommand::DuplicateReviewRequired => error
    prepare_reservation_show!
    @acknowledgement_token = error.token
    @duplicate_candidates = error.candidates
    flash.now[:alert] = error.message
    render :show, status: :unprocessable_entity
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    prepare_reservation_show!
    flash.now[:alert] = error.message
    render :show, status: :unprocessable_entity
  end

  def cancel_scopes
    result = CancelSupplierReservationScopes.new(
      agency: Current.agency,
      actor: Current.agency_user,
      reservation: @supplier_reservation,
      scope_ids: params[:scope_ids],
      reason: params[:reason],
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_arrangement_reservation_path(@departure, @supplier_arrangement, @supplier_reservation),
      notice: result.status == :replayed ? "Scope cancellation was already recorded." : "Confirmed scopes cancelled."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    prepare_reservation_show!
    flash.now[:alert] = error.message
    render :show, status: :unprocessable_entity
  end

  def revise
    result = CreateSupplierReservationRevision.new(
      agency: Current.agency,
      actor: Current.agency_user,
      reservation: @supplier_reservation,
      attributes: {},
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to edit_departure_arrangement_reservation_path(@departure, @supplier_arrangement, @supplier_reservation),
      notice: result.status == :replayed ? "A planned revision already exists." : "New planned revision created."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    prepare_reservation_show!
    flash.now[:alert] = error.message
    render :show, status: :unprocessable_entity
  end

  private

  def prepare_reservation_show!
    @projection = @supplier_reservation.projection
    @revisions = @supplier_reservation.revisions
      .includes(:supplier_arrangement_version, scopes: [ :arrangement_item, :service_occurrence, :supplier_resource, :capacity_pool ])
      .order(revision_number: :desc)
    @events = @supplier_reservation.events
      .includes(:scope_outcomes, :supplier_contact)
      .order(recorded_at: :desc, id: :desc)
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    @scopes_by_latest_outcome = nil
    @pending_scopes = pending_scopes
    @confirmed_scopes = confirmed_scopes
    @unresolved_commitment_triggers = UnresolvedReservationCommitmentTriggers.call(
      agency: Current.agency, reservation: @supplier_reservation
    )
    requested_revision = @supplier_reservation.revisions.where(status: "requested").order(revision_number: :desc).first
    @response_version = requested_revision&.supplier_arrangement_version
    @capacity_pool_options = if @response_version
      CapacityPool.where(
        id: @response_version.capacity_pool_definitions.select(:capacity_pool_id)
      ).includes(:supplying_supplier).order(:id)
    else
      CapacityPool.none
    end
    @reservation_triggers = if @response_version
      @response_version.supplier_commitment_trigger_definitions
        .where(trigger_kind: "reservation_confirmation", committed_supplier_id: @supplier_reservation.booking_supplier_id)
        .order(:position, :id)
    else
      SupplierCommitmentTriggerDefinition.none
    end
    @existing_confirmations = if @response_version
      @response_version.supplier_confirmations
        .where(confirming_supplier_id: @supplier_reservation.booking_supplier_id)
        .order(recorded_at: :desc, id: :desc)
    else
      SupplierConfirmation.none
    end
  end

  def set_reservation_version
    @supplier_arrangement_version =
      if @supplier_arrangement.active?
        @supplier_arrangement.governing_version
      else
        @supplier_arrangement.versions.find_by(status: "draft")
      end || @supplier_arrangement.versions.order(:version_number).last ||
        raise(ActiveRecord::RecordNotFound)
  end

  def set_supplier_reservation
    @supplier_reservation = @supplier_arrangement.supplier_reservations.find(params[:id])
  end

  def reservation_params
    params.fetch(:supplier_reservation, ActionController::Parameters.new).permit(
      :booking_supplier_id, :supplier_arrangement_version_id,
      scopes: [
        :target_kind, :arrangement_item_id, :service_occurrence_id,
        :supplier_resource_id, :capacity_pool_id, :label,
        :requested_quantity, :quantity_basis
      ]
    )
  end

  def existing_reservation_params
    reservation_params.to_h.merge(
      params.fetch(:existing_reservation, ActionController::Parameters.new).permit(
        :channel, :reference_note, :request_reference_note, :response_reference_note,
        :occurred_at, :confirmed_without_identifier_reason,
        evidence: [
          :evidence_kind, :other_evidence_label, :evidence_on, :channel, :reference_note,
          :confirmed_without_identifier_reason
        ],
        identifier: [ :identifier_type, :other_type_label, :display_value, :issuer_context ]
      ).to_h
    )
  end

  def request_params
    params.fetch(:request_event, ActionController::Parameters.new).permit(
      :occurred_at, :supplier_contact_id, :channel, :safe_contact_snapshot, :reference_note
    )
  end

  def response_params
    permitted = params.fetch(:response_event, ActionController::Parameters.new).permit(
      :occurred_at, :channel, :reference_note, :existing_confirmation_id,
      :duplicate_acknowledgement_token,
      scope_ids: [],
      evidence: [
        :evidence_kind, :other_evidence_label, :evidence_on, :channel, :reference_note,
        :confirmed_without_identifier_reason
      ],
      identifier: [ :identifier_type, :other_type_label, :display_value, :issuer_context ],
      capacity_consequences: [
        :capacity_pool_id, :event_type, :quantity, :effective_on, :supplier_reservation_scope_id,
        { evidence: [ :evidence_kind, :evidence_on, :evidence_reference_note, :evidence_external_reference ] }
      ],
      confirmed_amounts_minor_units: {},
      confirmed_quantities: {},
      coverage_scope_ids: {}
    )
    permitted[:scope_ids] = params[:scope_ids] if params[:scope_ids].present?
    if params[:duplicate_acknowledgement_token].present?
      permitted[:duplicate_acknowledgement_token] = params[:duplicate_acknowledgement_token]
    end
    if params[:outcomes].present?
      outcomes = {}
      params.fetch(:outcomes).each do |scope_id, values|
        next unless values.respond_to?(:permit)

        outcomes[scope_id] = values.permit(
          :outcome_kind, :quantity, :quantity_basis, :supplier_note, :decline_reason
        ).to_h
      end
      permitted[:outcomes] = outcomes
    end
    %i[confirmed_amounts_minor_units confirmed_quantities coverage_scope_ids].each do |key|
      raw = params[key].presence || params.dig(:response_event, key)
      next if raw.blank?
      next unless raw.respond_to?(:permit)

      version = @supplier_reservation.revisions.where(status: "requested")
        .order(revision_number: :desc).first&.supplier_arrangement_version
      allowed = version&.supplier_commitment_trigger_definitions
        &.pluck(:id)
        &.flat_map { |id| [ id.to_s, id ] } || []
      permitted[key] = raw.permit(*allowed).to_h
    end
    if params[:capacity_consequences].present?
      raw_consequences = params[:capacity_consequences]
      entries = if raw_consequences.is_a?(ActionController::Parameters) || raw_consequences.is_a?(Hash)
        raw_consequences.values
      else
        Array(raw_consequences)
      end
      permitted[:capacity_consequences] = entries.filter_map do |entry|
        next unless entry.respond_to?(:permit)

        entry.permit(
          :capacity_pool_id, :event_type, :quantity, :effective_on, :supplier_reservation_scope_id,
          evidence: [ :evidence_kind, :evidence_on, :evidence_reference_note, :evidence_external_reference ]
        ).to_h
      end
    end
    permitted
  end

  def load_scope_options(version = @supplier_arrangement_version)
    @supplier_arrangement_version = version
    @booking_supplier_options = Current.agency.suppliers
      .where(id: eligible_booking_supplier_ids_for(version))
      .ordered_for_directory
    @item_definitions = version.arrangement_item_definitions.includes(:arrangement_item).order(:position, :id)
    @occurrence_definitions = version.service_occurrence_definitions.includes(:service_occurrence).order(:starts_on, :id)
    @resource_definitions = version.supplier_resource_definitions.includes(:supplier_resource).order(:position, :id)
    @capacity_pool_definitions = version.capacity_pool_definitions.includes(:capacity_pool).order(:position, :id)
  end

  def eligible_booking_supplier_ids_for(version)
    ids = [ @supplier_arrangement.contracting_supplier_id ]
    item_provider_by_id = version.arrangement_item_definitions.pluck(:arrangement_item_id, :default_service_provider_id).to_h
    ids.concat(item_provider_by_id.values)
    version.service_occurrence_definitions.find_each do |definition|
      ids << (definition.service_provider_id || item_provider_by_id[definition.arrangement_item_id] || @supplier_arrangement.contracting_supplier_id)
    end
    ids.compact.uniq
  end

  def pending_scopes
    scopes_by_latest_outcome.select { |_scope, outcome| outcome&.requested? }.keys
  end

  def confirmed_scopes
    scopes_by_latest_outcome.select { |_scope, outcome| outcome&.confirmed? }.keys
  end

  def scopes_by_latest_outcome
    @scopes_by_latest_outcome ||= begin
      revision = @supplier_reservation.revisions.where(status: "requested").order(revision_number: :desc).first
      if revision.nil?
        {}
      else
        latest = SupplierReservationEventScopeOutcome
          .where(supplier_reservation_revision_id: revision.id)
          .order(:created_at, :id)
          .group_by(&:supplier_reservation_scope_id)
          .transform_values(&:last)
        revision.scopes.order(:position, :id).index_with { |scope| latest[scope.id] }
      end
    end
  end
end
