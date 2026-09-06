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
