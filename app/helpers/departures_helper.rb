module DeparturesHelper
  def departure_status_badge(departure)
    modifier = case departure.status
    when "draft" then "info"
    when "planning" then "success"
    else "neutral"
    end

    status_badge(departure.status.titleize, modifier:)
  end

  def travel_program_status_badge(program)
    status_badge(program.status.titleize, modifier: program.active? ? "success" : "neutral")
  end

  def departure_team_member_label(assignment)
    return "—" unless assignment

    assignment.member_name_snapshot
  end

  def departure_date_range(departure)
    if departure.start_date == departure.end_date
      departure.start_date.to_fs(:long)
    else
      "#{departure.start_date.to_fs(:long)} – #{departure.end_date.to_fs(:long)}"
    end
  end

  def eligible_team_memberships_for(office)
    ids = Current.agency.agency_memberships.active.administrator.pluck(:id)
    ids |= Current.agency.office_assignments.active.where(office_id: office.id).pluck(:agency_membership_id)
    Current.agency.agency_memberships.active.where(id: ids).includes(person_party: :party).order(:id)
  end

  def team_membership_option_label(membership)
    membership.agency_display_name
  end

  def visible_program_departures(program)
    DepartureQuery.new(agency: Current.agency, membership: Current.agency_membership).for_program(program)
  end

  def visible_program_upcoming_count(program, on:)
    DepartureQuery.new(agency: Current.agency, membership: Current.agency_membership)
      .upcoming_for_program(program, on:).count
  end

  def visible_program_next_departure(program, on:)
    DepartureQuery.new(agency: Current.agency, membership: Current.agency_membership)
      .upcoming_for_program(program, on:).first
  end
end
