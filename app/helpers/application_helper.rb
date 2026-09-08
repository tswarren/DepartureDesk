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
    status_badge(party.kind_label, modifier: "kind")
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

  def party_edit_label(party)
    "Edit #{party.kind_label.downcase}"
  end

  def party_breadcrumb_items(party)
    items = [ { label: "Directory", path: directory_parties_path } ]
    if party.supplier_profile
      items << { label: "Suppliers", path: directory_suppliers_path }
    elsif party.client_profile
      items << { label: "Clients", path: directory_clients_path }
    end
    items << { label: party.display_name, path: nil }
    items
  end

  def party_identity_line(party)
    party_header_metadata(party)
  end

  def party_attention_path(party, item)
    case item.path
    when :contact then directory_party_contact_information_path(party)
    when :roles then directory_party_roles_path(party)
    else directory_party_path(party)
    end
  end

  def overview_primary_contact_text(assignments)
    direct = assignments.select { |row| row.general? && %w[email phone].include?(row.contact_kind) }
    chosen = direct.first || assignments.find(&:general?) || assignments.first
    return "None" unless chosen

    chosen.contact_point.display_value.to_s.split("\n").first
  end

  def overview_responsible_office_text(client_profile, supplier_profile)
    profile = [ supplier_profile, client_profile ].compact.find(&:active?) || supplier_profile || client_profile
    return "—" unless profile

    responsible_office_text(profile)
  end

  def overview_supplier_services_text(party, supplier_profile)
    return "Not a supplier" if party.household? || supplier_profile.nil?
    return "Inactive" if supplier_profile.inactive?
    return "None assigned" if supplier_profile.category_codes.empty?

    supplier_profile.service_category_assignments.sort_by(&:category_code).map(&:category_label).to_sentence
  end

  def party_workspace?
    return false unless controller_path.start_with?("directory/")
    return false if %w[index].include?(action_name) && %w[parties clients suppliers].include?(controller_name)

    true
  end

  def user_initials(user)
    initials_from_name(user.display_name)
  end

  def party_initials(party)
    initials_from_name(party.display_name)
  end

  def initials_from_name(name)
    words = name.to_s.scan(/[[:alpha:]]+/)
    letters = words.first(2).map { |word| word[0] }
    letters.join.upcase.presence || "?"
  end

  def party_header_metadata(party)
    if party.organization?
      org = party.organization
      return org.legal_name if org.legal_name.present? && org.legal_name != party.display_name
    elsif party.household?
      correspondence = party.household.correspondence_name
      return correspondence if correspondence.present? && correspondence != party.household.name
    elsif party.person?
      preferred = party.person.preferred_name
      return preferred if preferred.present? && preferred != party.display_name
    end

    nil
  end

  def dd_display_date(value)
    return if value.blank?

    date = value.respond_to?(:to_date) ? value.to_date : value
    date.strftime("%b %-d, %Y")
  end

  def disclosure_populated_summary(value)
    value.to_s.strip.present? ? "Provided" : "Not provided"
  end

  def empty_state_classes(family: :inline)
    [ "dd-empty-state", "dd-empty-state--#{family}" ]
  end

  def selected_action?(action, id: nil, param: :id)
    return false unless params[:acting].to_s == action.to_s
    return true if id.nil?

    params[param].to_s == id.to_s
  end
end
