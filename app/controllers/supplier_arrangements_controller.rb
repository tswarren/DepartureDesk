class SupplierArrangementsController < ApplicationController
  before_action :set_departure
  before_action :set_arrangement, except: %i[index create]

  def index
    load_index_workspace
  end

  def show
    load_arrangement_workspace
  end

  def create
    result = CreateSupplierArrangement.new(
      agency: Current.agency,
      actor: Current.user,
      departure: @departure,
      supplier_party: Current.agency.parties.find(params[:supplier_party_id]),
      service_provider_party: selected_party(params[:service_provider_party_id]),
      parent_arrangement: selected_arrangement(params[:parent_arrangement_id]),
      name: params[:name],
      description: params[:description],
      client_facing_description: params[:client_facing_description],
      lock_version: params[:lock_version]
    ).call
    redirect_to departure_supplier_arrangement_path(@departure, result.supplier_arrangement), notice: "Supplier arrangement created."
  rescue MembershipCommand::Error => error
    load_index_workspace
    flash.now[:alert] = error.message
    render :index, status: status_for(error)
  end

  def activate
    ActivateSupplierArrangement.new(agency: Current.agency, actor: Current.user, arrangement: @arrangement, lock_version: params[:lock_version]).call
    redirect_to departure_supplier_arrangement_path(@departure, @arrangement), notice: "Supplier arrangement activated."
  rescue MembershipCommand::Error => error
    redirect_with_error(error)
  end

  def cancel
    CancelSupplierArrangement.new(agency: Current.agency, actor: Current.user, arrangement: @arrangement, reason: params[:reason], lock_version: params[:lock_version]).call
    redirect_to departure_supplier_arrangement_path(@departure, @arrangement), notice: "Supplier arrangement cancelled."
  rescue MembershipCommand::Error => error
    redirect_with_error(error)
  end

  def create_reservation
    result = CreateSupplierReservation.new(
      agency: Current.agency,
      actor: Current.user,
      arrangement: @arrangement,
      name: params[:name],
      resources: selected_resources,
      operational_notes: params[:operational_notes],
      lock_version: params[:lock_version]
    ).call
    redirect_to departure_supplier_arrangement_path(@departure, @arrangement, anchor: "reservations"), notice: "Supplier reservation created."
  rescue MembershipCommand::Error => error
    redirect_with_error(error, anchor: "reservations")
  end

  def confirm_reservation
    reservation = @arrangement.supplier_reservations.find(params[:reservation_id])
    ConfirmSupplierReservation.new(
      agency: Current.agency,
      actor: Current.user,
      reservation:,
      without_identifier_reason: params[:without_identifier_reason],
      lock_version: params[:reservation_lock_version]
    ).call
    redirect_to departure_supplier_arrangement_path(@departure, @arrangement, anchor: "reservations"), notice: "Supplier reservation confirmed."
  rescue MembershipCommand::Error => error
    redirect_with_error(error, anchor: "reservations")
  end

  def create_resource
    CreateSupplierResource.new(
      agency: Current.agency,
      actor: Current.user,
      arrangement: @arrangement,
      name: params[:name],
      resource_kind: params[:resource_kind],
      capacity_unit: params[:capacity_unit],
      description: params[:description],
      lock_version: params[:lock_version]
    ).call
    redirect_to departure_supplier_arrangement_path(@departure, @arrangement, anchor: "resources"), notice: "Supplier resource created."
  rescue MembershipCommand::Error => error
    redirect_with_error(error, anchor: "resources")
  end

  def create_occurrence
    resource = @arrangement.supplier_resources.find(params[:resource_id])
    CreateSupplierServiceOccurrence.new(
      agency: Current.agency,
      actor: Current.user,
      resource:,
      occurrence_kind: params[:occurrence_kind],
      service_date: params[:service_date].presence,
      segment_type: params[:segment_type],
      segment_identifier: params[:segment_identifier],
      label: params[:label],
      lock_version: params[:resource_lock_version]
    ).call
    redirect_to departure_supplier_arrangement_path(@departure, @arrangement, anchor: "resources"), notice: "Supplier occurrence created."
  rescue MembershipCommand::Error => error
    redirect_with_error(error, anchor: "resources")
  end

  def record_confirmation
    owner = confirmation_owner
    RecordSupplierConfirmation.new(
      agency: Current.agency,
      actor: Current.user,
      arrangement: owner.is_a?(SupplierArrangement) ? owner : nil,
      reservation: owner.is_a?(SupplierReservation) ? owner : nil,
      issuer_party: Current.agency.parties.find(params[:issuer_party_id]),
      identifier_type: params[:identifier_type],
      context: params[:context],
      raw_value: params[:raw_value],
      source_channel: params[:source_channel],
      document_reference: params[:document_reference]
    ).call
    redirect_to departure_supplier_arrangement_path(@departure, @arrangement, anchor: "confirmations"), notice: "Supplier confirmation recorded."
  rescue MembershipCommand::Error => error
    redirect_with_error(error, anchor: "confirmations")
  end

  def create_cost_term
    term = CreateSupplierCostTerm.new(
      agency: Current.agency,
      actor: Current.user,
      arrangement: @arrangement,
      reservation: selected_reservation(params[:reservation_id]),
      resource: selected_resource(params[:resource_id]),
      service_occurrence: selected_occurrence(params[:service_occurrence_id]),
      shape: params[:shape],
      basis: params[:basis],
      cost_category: params[:cost_category],
      quantity_basis: params[:quantity_basis],
      quantity_unit: params[:quantity_unit],
      currency: params[:currency],
      rounding_method: params[:rounding_method].presence || "nearest_minor_unit",
      tax_fee_treatment: params[:tax_fee_treatment].presence || "excluded",
      detail_attributes: cost_term_detail_attributes,
      provenance: params[:provenance],
      evaluation_inputs: cost_term_evaluation_inputs,
      lock_version: params[:lock_version]
    ).call.supplier_cost_term
    redirect_to departure_supplier_arrangement_path(@departure, @arrangement, anchor: "terms"), notice: "#{term.shape.humanize} cost term created."
  rescue MembershipCommand::Error => error
    redirect_with_error(error, anchor: "terms")
  end

  def activate_cost_term
    term = @arrangement.supplier_cost_terms.find(params[:term_id])
    ActivateSupplierCostTerm.new(agency: Current.agency, actor: Current.user, term:, lock_version: params[:term_lock_version]).call
    redirect_to departure_supplier_arrangement_path(@departure, @arrangement, anchor: "terms"), notice: "Supplier cost term activated."
  rescue MembershipCommand::Error => error
    redirect_with_error(error, anchor: "terms")
  end

  def create_commitment
    term = @arrangement.supplier_cost_terms.find(params[:term_id])
    CreateSupplierCommitment.new(agency: Current.agency, actor: Current.user, governing_term: term, reason: params[:reason], lock_version: params[:term_lock_version]).call
    redirect_to departure_supplier_arrangement_path(@departure, @arrangement, anchor: "commitments"), notice: "Supplier commitment opened."
  rescue MembershipCommand::Error => error
    redirect_with_error(error, anchor: "commitments")
  end

  def create_deposit_requirement
    CreateSupplierDepositRequirement.new(
      agency: Current.agency,
      actor: Current.user,
      arrangement: @arrangement,
      supplier_cost_term: selected_cost_term(params[:supplier_cost_term_id]),
      name: params[:name],
      amount_minor_units: params[:amount_minor_units],
      currency: params[:currency],
      due_rule: params[:due_rule],
      due_on: params[:due_on].presence,
      refundable: params[:refundable] == "1",
      applies_to_final_balance: params[:applies_to_final_balance] != "0",
      trigger_condition: params[:trigger_condition],
      provenance: params[:provenance],
      lock_version: params[:lock_version]
    ).call
    redirect_to departure_supplier_arrangement_path(@departure, @arrangement, anchor: "terms"), notice: "Supplier deposit requirement created."
  rescue MembershipCommand::Error => error
    redirect_with_error(error, anchor: "terms")
  end

  def create_deadline
    CreateSupplierDeadline.new(
      agency: Current.agency,
      actor: Current.user,
      deposit_requirement: selected_deposit(params[:source_deposit_requirement_id]),
      clause: selected_clause(params[:source_clause_id]),
      name: params[:name],
      due_on: params[:due_on].presence,
      lock_version: params[:source_lock_version]
    ).call
    redirect_to departure_supplier_arrangement_path(@departure, @arrangement, anchor: "deadlines"), notice: "Supplier deadline created."
  rescue MembershipCommand::Error => error
    redirect_with_error(error, anchor: "deadlines")
  end

  def hold_capacity
    resource = @arrangement.supplier_resources.find(params[:resource_id])
    occurrence = resource.supplier_service_occurrences.find(params[:service_occurrence_id])
    HoldSupplierCapacity.new(
      agency: Current.agency,
      actor: Current.user,
      resource:,
      service_occurrence: occurrence,
      quantity: params[:quantity],
      guaranteed_quantity: params[:guaranteed_quantity],
      reason: params[:reason],
      idempotency_key: params[:idempotency_key],
      lock_version: params[:resource_lock_version]
    ).call
    redirect_to departure_supplier_arrangement_path(@departure, @arrangement, anchor: "capacity"), notice: "Supplier capacity held."
  rescue MembershipCommand::Error => error
    redirect_with_error(error, anchor: "capacity")
  end

  def create_clause
    CreateSupplierClause.new(
      agency: Current.agency,
      actor: Current.user,
      arrangement: @arrangement,
      resource: selected_resource(params[:resource_id]),
      service_occurrence: selected_occurrence(params[:service_occurrence_id]),
      governing_term: selected_cost_term(params[:governing_term_id]),
      affected_commitment: selected_commitment(params[:affected_commitment_id]),
      clause_type: params[:clause_type],
      name: params[:name],
      capacity_action: params[:capacity_action],
      capacity_quantity: params[:capacity_quantity].presence,
      guaranteed_quantity: params[:guaranteed_quantity].presence,
      commitment_action: params[:commitment_action],
      provenance: params[:provenance],
      deadline_due_on: params[:deadline_due_on].presence,
      lock_version: params[:lock_version]
    ).call
    redirect_to departure_supplier_arrangement_path(@departure, @arrangement, anchor: "clauses"), notice: "Supplier clause created."
  rescue MembershipCommand::Error => error
    redirect_with_error(error, anchor: "clauses")
  end

  def preview_clause
    @clause_preview = ApplySupplierClause.new(
      agency: Current.agency,
      actor: Current.user,
      clause: selected_clause(params[:clause_id]),
      reason: params[:reason],
      idempotency_key: params[:idempotency_key]
    ).preview
    load_arrangement_workspace
    flash.now[:notice] = "Supplier clause preview ready."
    render :show
  rescue MembershipCommand::Error => error
    load_arrangement_workspace
    flash.now[:alert] = error.message
    render :show, status: status_for(error)
  end

  def apply_clause
    ApplySupplierClause.new(
      agency: Current.agency,
      actor: Current.user,
      clause: selected_clause(params[:clause_id]),
      reason: params[:reason],
      idempotency_key: params[:idempotency_key],
      lock_version: params[:clause_lock_version]
    ).call
    redirect_to departure_supplier_arrangement_path(@departure, @arrangement, anchor: "clauses"), notice: "Supplier clause applied."
  rescue MembershipCommand::Error => error
    redirect_with_error(error, anchor: "clauses")
  end

  private

  def visible_departures
    DepartureQuery.new(agency: Current.agency, membership: Current.agency_membership).relation
  end

  def set_departure
    @departure = visible_departures.find(params[:departure_id])
  end

  def set_arrangement
    @arrangement = @departure.supplier_arrangements.find(params[:id])
  end

  def load_index_workspace
    @supplier_q = params[:supplier_q].to_s.strip.presence
    @supplier_candidates = DirectoryPartySelector.new(agency: Current.agency, mode: "active_supplier", q: @supplier_q).results
    @arrangements = @departure.supplier_arrangements.includes(:supplier_party, :service_provider_party, :parent_arrangement).order(created_at: :desc, id: :desc)
    @forecast_report = SupplierForecastCostReporter.call(agency: Current.agency, departure: @departure)
    @exposure_report = SupplierGuaranteeExposureReporter.call(agency: Current.agency, departure: @departure)
  end

  def load_arrangement_workspace
    @resources = @arrangement.supplier_resources.includes(:supplier_service_occurrences).order(:name)
    @reservations = @arrangement.supplier_reservations.includes(:supplier_resources, :supplier_confirmations).order(created_at: :desc)
    @confirmations = @arrangement.supplier_confirmations.effective.order(created_at: :desc).to_a +
      SupplierConfirmation.effective.where(reservation: @reservations).order(created_at: :desc).to_a
    @terms = @arrangement.supplier_cost_terms.order(created_at: :desc)
    @commitments = @arrangement.supplier_commitments.order(created_at: :desc)
    @deposits = @arrangement.supplier_deposit_requirements.order(created_at: :desc)
    @deadlines = @arrangement.supplier_deadlines.order(due_on: :asc, created_at: :asc)
    @clauses = @arrangement.supplier_clauses.includes(:resource, :service_occurrence, :affected_commitment, :governing_term).order(created_at: :desc)
    @capacity_positions = @arrangement.supplier_capacity_positions.includes(:resource, :service_occurrence, :supplier_capacity_events).order(created_at: :desc)
    @issuer_candidates = DirectoryPartySelector.new(agency: Current.agency, mode: "active_supplier").results
    @forecast_report = SupplierForecastCostReporter.call(agency: Current.agency, departure: @departure)
    @exposure_report = SupplierGuaranteeExposureReporter.call(agency: Current.agency, departure: @departure)
    @capacity_idempotency_key = SecureRandom.uuid
    @clause_idempotency_key = SecureRandom.uuid
  end

  def selected_party(id)
    Current.agency.parties.find(id) if id.present?
  end

  def selected_arrangement(id)
    @departure.supplier_arrangements.find(id) if id.present?
  end

  def selected_resources
    ids = Array(params[:resource_ids]).reject(&:blank?)
    return [] if ids.empty?

    @arrangement.supplier_resources.where(id: ids).to_a
  end

  def selected_resource(id)
    @arrangement.supplier_resources.find(id) if id.present?
  end

  def selected_reservation(id)
    @arrangement.supplier_reservations.find(id) if id.present?
  end

  def selected_occurrence(id)
    return if id.blank?

    SupplierServiceOccurrence.where(arrangement: @arrangement).find(id)
  end

  def selected_cost_term(id)
    @arrangement.supplier_cost_terms.find(id) if id.present?
  end

  def selected_commitment(id)
    @arrangement.supplier_commitments.find(id) if id.present?
  end

  def selected_deposit(id)
    @arrangement.supplier_deposit_requirements.find(id) if id.present?
  end

  def selected_clause(id)
    @arrangement.supplier_clauses.find(id) if id.present?
  end

  def confirmation_owner
    return selected_reservation(params[:reservation_id]) if params[:reservation_id].present?

    @arrangement
  end

  def cost_term_detail_attributes
    case params[:shape]
    when "fixed"
      { amount_minor_units: params[:amount_minor_units] }
    when "minimum_guarantee"
      { minimum_quantity: params[:minimum_quantity], unit_amount_minor_units: params[:unit_amount_minor_units] }
    else
      {}
    end
  end

  def cost_term_evaluation_inputs
    inputs = {}
    inputs["qualifying_quantity"] = params[:qualifying_quantity] if params[:qualifying_quantity].present?
    inputs
  end

  def redirect_with_error(error, anchor: nil)
    redirect_to departure_supplier_arrangement_path(@departure, @arrangement, anchor:), alert: error.message, status: :see_other
  end

  def status_for(error)
    error.code == :conflict ? :conflict : :unprocessable_entity
  end
end
