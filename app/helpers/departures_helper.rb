module DeparturesHelper
  def departure_status_badge(departure)
    modifier = case departure.status
    when "draft" then "info"
    when "planning" then "success"
    else "neutral"
    end

    status_badge(departure.status.titleize, modifier:)
  end

  def supplier_planning_status_badge(record)
    modifier = case record.status
    when "active", "confirmed", "completed", "open" then "success"
    when "draft", "requested", "submitted" then "info"
    when "cancelled", "declined", "unable_to_confirm", "void" then "warning"
    else "neutral"
    end

    status_badge(record.status.titleize, modifier:)
  end

  def supplier_money_minor_units(amount_minor_units, currency)
    return "—" if amount_minor_units.nil? || currency.blank?

    Money.new(amount_minor_units, currency).format
  end

  def supplier_cost_term_value(term)
    supplier_money_minor_units(SupplierCostTermEvaluation.evaluate(term).amount_minor_units, term.currency)
  rescue MembershipCommand::Error, ActiveRecord::RecordInvalid
    "Draft needs complete inputs"
  end

  def supplier_occurrence_label(occurrence)
    if occurrence.night_slice?
      [ occurrence.service_date&.to_fs(:medium), occurrence.label ].compact.join(" · ")
    else
      [ occurrence.segment_type&.humanize, occurrence.segment_identifier, occurrence.label ].compact.join(" · ")
    end
  end

  def supplier_capacity_position_label(position)
    "#{position.resource.name} · #{supplier_occurrence_label(position.service_occurrence)}"
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
end
