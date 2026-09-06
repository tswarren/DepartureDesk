module ApplicationHelper
  def status_badge(status, modifier:)
    tag.span status, class: "dd-badge dd-badge--#{modifier}"
  end

  def office_status_badge(office)
    status_badge(office.status.titleize, modifier: office.active? ? "success" : "neutral")
  end

  def membership_role_badge(membership)
    status_badge(membership.role.titleize, modifier: membership.administrator? ? "info" : "neutral")
  end

  def membership_status_badge(membership)
    modifier = case membership.status
    when "active" then "success"
    when "invited" then "info"
    when "suspended" then "warning"
    else "neutral"
    end

    status_badge(membership.status.titleize, modifier:)
  end

  def party_kind_badge(party)
    status_badge(party.kind_label, modifier: "info")
  end

  def party_status_badge(party)
    status_badge(party.status.titleize, modifier: party.active? ? "success" : "neutral")
  end

  def role_profile_status_badge(profile)
    if profile.nil?
      status_badge("Not assigned", modifier: "neutral")
    elsif profile.active?
      status_badge("Active", modifier: "success")
    else
      status_badge("Inactive", modifier: "neutral")
    end
  end

  def office_choice_label(office)
    "#{office.name} (#{office.code})"
  end

  def responsible_office_text(profile)
    office = profile.responsible_office
    return "—" unless office

    label = office_choice_label(office)
    return label unless office.inactive?

    "#{label} · Inactive"
  end

  def advisor_membership_label(membership)
    return "—" if membership.blank?

    membership.agency_display_name
  end

  def communication_preference_label(preference)
    {
      "no_preference" => "No preference",
      "email" => "Email",
      "phone" => "Phone",
      "postal_mail" => "Postal mail"
    }.fetch(preference.to_s, preference.to_s.humanize)
  end

  def general_primary_assignments(party, date)
    party.contact_point_purpose_assignments.select do |assignment|
      assignment.general? &&
        assignment.primary? &&
        assignment.current_on?(date) &&
        assignment.contact_point&.eligible_destination?
    end
  end

  def client_preference_contact_lines(party, profile, date)
    assignments = general_primary_assignments(party, date)
    kind_for = { "email" => "email", "phone" => "phone", "postal_mail" => "postal_address" }
    preferred_kind = kind_for[profile.communication_preference]
    lines = []

    if profile.no_preference? || preferred_kind.blank?
      if assignments.empty?
        lines << "No eligible general primary."
      else
        assignments.each do |assignment|
          lines << "#{assignment.contact_kind.titleize}: #{assignment.contact_point.display_value.to_s.split("\n").first}"
        end
      end
      return lines
    end

    preferred = assignments.select { |assignment| assignment.contact_kind == preferred_kind }
    if preferred.empty?
      lines << "Preferred contact unavailable."
      assignments.each do |assignment|
        lines << "#{assignment.contact_kind.titleize}: #{assignment.contact_point.display_value.to_s.split("\n").first}"
      end
    else
      preferred.each do |assignment|
        lines << assignment.contact_point.display_value.to_s.split("\n").first
      end
      assignments.reject { |assignment| assignment.contact_kind == preferred_kind }.each do |assignment|
        lines << "#{assignment.contact_kind.titleize}: #{assignment.contact_point.display_value.to_s.split("\n").first}"
      end
    end
    lines
  end

  def party_selector_option_label(candidate)
    label = "#{candidate.display_name} (#{candidate.party_kind.titleize})"
    extras = []
    extras << "client #{candidate.client_status}" if candidate.client_status
    extras << "supplier #{candidate.supplier_status}" if candidate.supplier_status
    extras << "team member" if candidate.team_member
    extras.any? ? "#{label} · #{extras.join(" · ")}" : label
  end

  def supplier_category_label(code)
    code.to_s.tr("_", " ").titleize
  end

  def supplier_general_primary_lines(party, date)
    assignments = general_primary_assignments(party, date)
    return [ "No eligible general primary." ] if assignments.empty?

    assignments.map do |assignment|
      "#{assignment.contact_kind.titleize}: #{assignment.contact_point.display_value.to_s.split("\n").first}"
    end
  end

  def contact_point_status_badge(contact_point)
    if contact_point.suppressed?
      status_badge("Do not use", modifier: "danger")
    elsif contact_point.deactivated?
      status_badge("Deactivated", modifier: "neutral")
    else
      status_badge("Active", modifier: "success")
    end
  end

  def party_named_route?(name)
    Rails.application.routes.named_routes.key?(name)
  end

  def current_purpose_assignments(contact_point, date)
    contact_point.purpose_assignments.select { |assignment| assignment.current_on?(date) }
  end

  def agency_status_badge(agency)
    modifier = case agency.status
    when "active" then "success"
    when "suspended" then "warning"
    else "neutral"
    end

    status_badge(agency.status.titleize, modifier:)
  end

  def field_error_id(record, attribute)
    "#{record.model_name.param_key}_#{attribute}_error"
  end

  def field_aria(record, attribute)
    errors = record.errors[attribute]

    {
      invalid: errors.any?,
      describedby: (field_error_id(record, attribute) if errors.any?)
    }
  end

  def field_error(record, attribute)
    return unless record.errors[attribute].any?

    tag.p record.errors[attribute].to_sentence,
      id: field_error_id(record, attribute),
      class: "dd-field-error"
  end
end
