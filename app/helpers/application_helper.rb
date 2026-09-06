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
