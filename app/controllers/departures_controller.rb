class DeparturesController < ApplicationController
  class_attribute :page_size, default: 50

  before_action :set_departure, only: %i[
    show edit update start_planning cancel transfer_office
    assign_team_member replace_team_member end_team_assignment
    assign_party_role end_party_role set_primary_party_role
  ]

  def index
    @q = params[:q].to_s.strip.presence
    @status = params[:status]
    @office_id = params[:office_id]
    @from = params[:from]
    @to = params[:to]
    @page = [ params[:page].to_i, 1 ].max
    office = visible_offices.find_by(id: @office_id) if @office_id.present?
    raise ActiveRecord::RecordNotFound if @office_id.present? && office.nil?

    scope = DepartureSelector.new(
      relation: visible_departures,
      q: @q,
      status: @status,
      office_id: office&.id,
      from: @from,
      to: @to
    ).relation
    records = scope.offset((@page - 1) * page_size).limit(page_size + 1).to_a
    @has_next_page = records.size > page_size
    @departures = records.first(page_size)
    @offices = visible_offices.order(:name)
  end

  def show
    @team_assignments = @departure.team_assignments.current.includes(agency_membership: { person_party: :party }).order(:assignment_role)
    @party_roles = @departure.party_role_assignments.current.includes(:party).order(:role, :id)
    @ended_team = @departure.team_assignments.where.not(effective_until: nil).order(ended_at: :desc)
    @eligible_memberships = eligible_memberships_for(@departure.office)
    @transfer_offices = Current.agency.offices.active.order(:name) if Current.agency_membership.administrator?
    @party_candidates = Current.agency.parties.active.order(:sort_name).limit(100)
  end

  def new
    office = default_create_office
    @departure = Current.agency.departures.new(
      office:,
      start_date: Date.new(2027, 7, 12),
      end_date: Date.new(2027, 7, 19),
      default_currency: Current.agency.default_currency
    )
    @creation_idempotency_key = SecureRandom.uuid
    @group_manager_membership_id = default_manager_id(office)
    assign_form_collections(office)
  end

  def create
    office = visible_offices.find(departure_params[:office_id])
    result = CreateDeparture.new(
      agency: Current.agency,
      actor: Current.user,
      office:,
      travel_program: selected_program,
      name: departure_params[:name],
      description: departure_params[:description],
      client_facing_description: departure_params[:client_facing_description],
      primary_destination: departure_params[:primary_destination],
      start_date: departure_params[:start_date],
      end_date: departure_params[:end_date],
      sales_open_on: departure_params[:sales_open_on],
      sales_close_on: departure_params[:sales_close_on],
      default_currency: departure_params[:default_currency],
      group_manager_membership: selected_membership(departure_params[:group_manager_membership_id]),
      responsible_advisor_membership: selected_membership(departure_params[:responsible_advisor_membership_id]),
      creation_idempotency_key: departure_params[:creation_idempotency_key]
    ).call
    redirect_to departure_path(result.departure), notice: "Departure created."
  rescue MembershipCommand::Error => error
    assign_create_form_from_params
    flash.now[:alert] = error.message
    render :new, status: error.code == :idempotency_conflict ? :conflict : :unprocessable_entity
  end

  def edit
    unless @departure.nonterminal?
      redirect_to departure_path(@departure), alert: "Only a draft or planning departure can be edited."
    end
    assign_form_collections(@departure.office)
  end

  def update
    UpdateDeparture.new(
      agency: Current.agency,
      actor: Current.user,
      departure: @departure,
      travel_program: selected_program,
      name: departure_params[:name],
      description: departure_params[:description],
      client_facing_description: departure_params[:client_facing_description],
      primary_destination: departure_params[:primary_destination],
      start_date: departure_params[:start_date],
      end_date: departure_params[:end_date],
      sales_open_on: departure_params[:sales_open_on],
      sales_close_on: departure_params[:sales_close_on],
      default_currency: departure_params[:default_currency],
      lock_version: departure_params[:lock_version]
    ).call
    redirect_to departure_path(@departure), notice: "Departure updated."
  rescue MembershipCommand::Error => error
    @departure.assign_attributes(departure_params.except(:lock_version, :office_id, :group_manager_membership_id, :responsible_advisor_membership_id, :creation_idempotency_key))
    assign_form_collections(@departure.office)
    flash.now[:alert] = error.message
    render :edit, status: error.code == :conflict ? :conflict : :unprocessable_entity
  end

  def start_planning
    StartDeparturePlanning.new(agency: Current.agency, actor: Current.user, departure: @departure, lock_version: params[:lock_version]).call
    redirect_to departure_path(@departure), notice: "Planning started."
  rescue MembershipCommand::Error => error
    redirect_to departure_path(@departure), alert: error.message
  end

  def cancel
    CancelDeparture.new(agency: Current.agency, actor: Current.user, departure: @departure, reason: params[:reason], lock_version: params[:lock_version]).call
    redirect_to departure_path(@departure), notice: "Departure cancelled."
  rescue MembershipCommand::Error => error
    redirect_to departure_path(@departure), alert: error.message
  end

  def transfer_office
    office = Current.agency.offices.find(params[:office_id])
    TransferDepartureOffice.new(agency: Current.agency, actor: Current.user, departure: @departure, office:, lock_version: params[:lock_version]).call
    redirect_to departure_path(@departure), notice: "Office transferred."
  rescue MembershipCommand::Error => error
    redirect_to departure_path(@departure), alert: error.message
  end

  def assign_team_member
    AssignDepartureTeamMember.new(
      agency: Current.agency,
      actor: Current.user,
      departure: @departure,
      membership: Current.agency.agency_memberships.find(params[:agency_membership_id]),
      role: params[:role],
      lock_version: params[:lock_version]
    ).call
    redirect_to departure_path(@departure), notice: "Team member assigned."
  rescue MembershipCommand::Error => error
    redirect_to departure_path(@departure), alert: error.message
  end

  def replace_team_member
    ReplaceDepartureTeamMember.new(
      agency: Current.agency,
      actor: Current.user,
      departure: @departure,
      role: params[:role],
      membership: Current.agency.agency_memberships.find(params[:agency_membership_id]),
      reason: params[:reason],
      lock_version: params[:lock_version]
    ).call
    redirect_to departure_path(@departure), notice: "Team member replaced."
  rescue MembershipCommand::Error => error
    redirect_to departure_path(@departure), alert: error.message
  end

  def end_team_assignment
    assignment = @departure.team_assignments.find(params[:assignment_id])
    EndDepartureTeamAssignment.new(
      agency: Current.agency,
      actor: Current.user,
      departure: @departure,
      assignment:,
      reason: params[:reason],
      lock_version: params[:lock_version]
    ).call
    redirect_to departure_path(@departure), notice: "Assignment ended."
  rescue MembershipCommand::Error => error
    redirect_to departure_path(@departure), alert: error.message
  end

  def assign_party_role
    AssignDeparturePartyRole.new(
      agency: Current.agency,
      actor: Current.user,
      departure: @departure,
      party: Current.agency.parties.find(params[:party_id]),
      role: params[:role],
      lock_version: params[:lock_version]
    ).call
    redirect_to departure_path(@departure), notice: "Party role assigned."
  rescue MembershipCommand::Error => error
    redirect_to departure_path(@departure), alert: error.message
  end

  def end_party_role
    assignment = @departure.party_role_assignments.find(params[:assignment_id])
    replacement = @departure.party_role_assignments.find_by(id: params[:replacement_id])
    EndDeparturePartyRole.new(
      agency: Current.agency,
      actor: Current.user,
      departure: @departure,
      assignment:,
      replacement:,
      end_all_for_role: params[:end_all_for_role] == "1",
      reason: params[:reason],
      lock_version: params[:lock_version]
    ).call
    redirect_to departure_path(@departure), notice: "Party role ended."
  rescue MembershipCommand::Error => error
    redirect_to departure_path(@departure), alert: error.message
  end

  def set_primary_party_role
    assignment = @departure.party_role_assignments.find(params[:assignment_id])
    SetPrimaryDeparturePartyRole.new(
      agency: Current.agency,
      actor: Current.user,
      departure: @departure,
      assignment:,
      lock_version: params[:lock_version]
    ).call
    redirect_to departure_path(@departure), notice: "Primary assignment updated."
  rescue MembershipCommand::Error => error
    redirect_to departure_path(@departure), alert: error.message
  end

  private

  def visible_departures
    DepartureQuery.new(agency: Current.agency, membership: Current.agency_membership).relation
  end

  def visible_offices
    if Current.agency_membership.administrator?
      Current.agency.offices
    else
      Current.agency_membership.accessible_offices
    end
  end

  def set_departure
    @departure = visible_departures.find(params[:id])
  end

  def default_create_office
    current = Current.office
    return current if current && Current.agency_membership.can_access_office?(current)

    Current.agency_membership.accessible_offices.order(:name).first
  end

  def default_manager_id(office)
    membership = Current.agency_membership
    membership.id if office && membership.can_access_office?(office)
  end

  def assign_form_collections(office)
    @offices = Current.agency_membership.accessible_offices.order(:name)
    @offices = Current.agency.offices.active.order(:name) if Current.agency_membership.administrator?
    @programs = Current.agency.travel_programs.active.order(:name)
    @eligible_memberships = office ? eligible_memberships_for(office) : Current.agency.agency_memberships.none
  end

  def eligible_memberships_for(office)
    ids = Current.agency.agency_memberships.active.administrator.pluck(:id)
    ids |= Current.agency.office_assignments.active.where(office_id: office.id).pluck(:agency_membership_id)
    Current.agency.agency_memberships.active.where(id: ids).includes(person_party: :party).order(:id)
  end

  def selected_program
    id = departure_params[:travel_program_id]
    return if id.blank?

    Current.agency.travel_programs.find(id)
  end

  def selected_membership(id)
    return if id.blank?

    Current.agency.agency_memberships.find(id)
  end

  def assign_create_form_from_params
    office = visible_offices.find_by(id: departure_params[:office_id]) || default_create_office
    @departure = Current.agency.departures.new(departure_params.except(:lock_version, :group_manager_membership_id, :responsible_advisor_membership_id, :creation_idempotency_key, :travel_program_id))
    @departure.office = office
    @creation_idempotency_key = departure_params[:creation_idempotency_key]
    @group_manager_membership_id = departure_params[:group_manager_membership_id]
    @responsible_advisor_membership_id = departure_params[:responsible_advisor_membership_id]
    assign_form_collections(office)
  end

  def departure_params
    params.require(:departure).permit(
      :name,
      :description,
      :client_facing_description,
      :primary_destination,
      :start_date,
      :end_date,
      :sales_open_on,
      :sales_close_on,
      :default_currency,
      :office_id,
      :travel_program_id,
      :group_manager_membership_id,
      :responsible_advisor_membership_id,
      :creation_idempotency_key,
      :lock_version
    )
  end
end
