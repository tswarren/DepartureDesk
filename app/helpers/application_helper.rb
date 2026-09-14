module ApplicationHelper
  ICON_NAMES = %w[
    house users briefcase boat calendar_blank suitcase coins gear dots_three list x
    envelope phone map_pin caret_down warning_circle check_circle lock_simple plus
    pencil_simple users_two file_text magnifying_glass info spinner globe
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
