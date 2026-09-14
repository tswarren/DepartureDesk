module ApplicationHelper
  ICON_NAMES = %w[
    house users briefcase boat calendar_blank suitcase coins gear dots_three list x
    envelope phone map_pin caret_down warning_circle check_circle lock_simple plus
    pencil_simple users_two file_text magnifying_glass info spinner globe star
  ].freeze

  def icon_tag(name, html_class: "dd-icon dd-icon--md")
    key = name.to_s
    raise ArgumentError, "Unknown icon #{key}" unless ICON_NAMES.include?(key)

    render partial: "shared/icons/#{key}", locals: { class: html_class }
  end

  def status_badge(status, modifier:)
    tag.span status, class: "dd-badge dd-badge--#{modifier}"
  end

  def office_status_badge(office)
    status_badge(office.status.titleize, modifier: office.active? ? "success" : "neutral")
  end

  def agency_status_badge(agency)
    modifier = case agency.status
    when "active" then "success"
    when "suspended" then "warning"
    else "neutral"
    end

    status_badge(agency.status.titleize, modifier:)
  end

  def agency_user_role_badge(agency_user)
    modifier = agency_user.role_administrator? ? "info" : "neutral"
    status_badge(agency_user.access_role.titleize, modifier:)
  end

  def contact_destination(record)
    case record
    when ClientPersonEmailAddress then record.address
    when ClientOrganizationEmailAddress then record.address
    when ClientPersonPhoneNumber
      record.formatted_number(viewer_country: Current.agency&.country_code)
    when ClientOrganizationPhoneNumber
      PhoneNumberNormalizer.display(
        normalized_number: record.normalized_number,
        country_code: record.country_code,
        extension: record.extension,
        viewer_country: Current.agency&.country_code
      )
    when ClientPersonPostalAddress
      [ record.line_1, record.line_2, record.locality, record.region, record.postal_code, record.country_code ].compact_blank.join(", ")
    when ClientOrganizationPostalAddress
      [ record.line_1, record.line_2, record.locality, record.region, record.postal_code, record.country_code ].compact_blank.join(", ")
    when ClientOrganizationWebsite
      record.url
    end
  end

  def contact_form_url(person, record)
    case record
    when ClientPersonEmailAddress
      record.persisted? ? client_person_email_address_path(person, record) : client_person_email_addresses_path(person)
    when ClientPersonPhoneNumber
      record.persisted? ? client_person_phone_number_path(person, record) : client_person_phone_numbers_path(person)
    when ClientPersonPostalAddress
      record.persisted? ? client_person_postal_address_path(person, record) : client_person_postal_addresses_path(person)
    end
  end

  def contact_edit_path(record)
    case record
    when ClientPersonEmailAddress then edit_client_person_email_address_path(record.client_person_id, record)
    when ClientPersonPhoneNumber then edit_client_person_phone_number_path(record.client_person_id, record)
    when ClientPersonPostalAddress then edit_client_person_postal_address_path(record.client_person_id, record)
    end
  end

  def contact_set_primary_path(record)
    case record
    when ClientPersonEmailAddress then set_primary_client_person_email_address_path(record.client_person_id, record)
    when ClientPersonPhoneNumber then set_primary_client_person_phone_number_path(record.client_person_id, record)
    when ClientPersonPostalAddress then set_primary_client_person_postal_address_path(record.client_person_id, record)
    end
  end

  def contact_status_path(record)
    case record
    when ClientPersonEmailAddress then status_edit_client_person_email_address_path(record.client_person_id, record)
    when ClientPersonPhoneNumber then status_edit_client_person_phone_number_path(record.client_person_id, record)
    when ClientPersonPostalAddress then status_edit_client_person_postal_address_path(record.client_person_id, record)
    end
  end

  def organization_contact_form_url(organization, record)
    case record
    when ClientOrganizationEmailAddress
      record.persisted? ? client_organization_email_address_path(organization, record) : client_organization_email_addresses_path(organization)
    when ClientOrganizationPhoneNumber
      record.persisted? ? client_organization_phone_number_path(organization, record) : client_organization_phone_numbers_path(organization)
    when ClientOrganizationPostalAddress
      record.persisted? ? client_organization_postal_address_path(organization, record) : client_organization_postal_addresses_path(organization)
    when ClientOrganizationWebsite
      record.persisted? ? client_organization_website_path(organization, record) : client_organization_websites_path(organization)
    end
  end

  def organization_contact_edit_path(record)
    case record
    when ClientOrganizationEmailAddress then edit_client_organization_email_address_path(record.client_organization_id, record)
    when ClientOrganizationPhoneNumber then edit_client_organization_phone_number_path(record.client_organization_id, record)
    when ClientOrganizationPostalAddress then edit_client_organization_postal_address_path(record.client_organization_id, record)
    when ClientOrganizationWebsite then edit_client_organization_website_path(record.client_organization_id, record)
    end
  end

  def organization_contact_set_primary_path(record)
    case record
    when ClientOrganizationEmailAddress then set_primary_client_organization_email_address_path(record.client_organization_id, record)
    when ClientOrganizationPhoneNumber then set_primary_client_organization_phone_number_path(record.client_organization_id, record)
    when ClientOrganizationPostalAddress then set_primary_client_organization_postal_address_path(record.client_organization_id, record)
    when ClientOrganizationWebsite then set_primary_client_organization_website_path(record.client_organization_id, record)
    end
  end

  def organization_contact_status_path(record)
    case record
    when ClientOrganizationEmailAddress then status_edit_client_organization_email_address_path(record.client_organization_id, record)
    when ClientOrganizationPhoneNumber then status_edit_client_organization_phone_number_path(record.client_organization_id, record)
    when ClientOrganizationPostalAddress then status_edit_client_organization_postal_address_path(record.client_organization_id, record)
    when ClientOrganizationWebsite then status_edit_client_organization_website_path(record.client_organization_id, record)
    end
  end

  def duplicate_candidate_path(candidate)
    if candidate.class.name.include?("Organization")
      client_organization_path(candidate.id)
    else
      client_person_path(candidate.id)
    end
  end

  def preferred_indicator(record)
    label = record.preferred? ? "Preferred" : "Not preferred"
    tag.span class: "dd-preferred-mark#{ " is-preferred" if record.preferred? }", title: label do
      safe_join([
        icon_tag("star", html_class: "dd-icon dd-icon--sm"),
        tag.span(label, class: "dd-visually-hidden")
      ])
    end
  end

  def primary_contact_indicator(assignment)
    label = assignment.primary? ? "Primary" : "Not primary"
    tag.span class: "dd-preferred-mark#{ " is-preferred" if assignment.primary? }", title: label do
      safe_join([
        icon_tag("star", html_class: "dd-icon dd-icon--sm"),
        tag.span(label, class: "dd-visually-hidden")
      ])
    end
  end

  def directory_status_badge(status)
    status_badge(status.to_s.titleize, modifier: status.to_s == "active" ? "success" : "neutral")
  end

  def agency_user_status_badge(agency_user)
    modifier = case agency_user.status
    when "active" then "success"
    when "invited" then "info"
    when "suspended" then "warning"
    else "neutral"
    end

    status_badge(agency_user.status.titleize, modifier:)
  end

  def office_choice_label(office)
    "#{office.name} (#{office.code})"
  end

  def user_initials(user)
    initials_from_name(user.display_name)
  end

  def initials_from_name(name)
    words = name.to_s.scan(/[[:alpha:]]+/)
    letters = words.first(2).map { |word| word[0] }
    letters.join.upcase.presence || "?"
  end

  def empty_state_classes(family: :inline)
    [ "dd-empty-state", "dd-empty-state--#{family}" ]
  end
end
