module ApplicationHelper
  ICON_NAMES = %w[
    house users briefcase boat calendar_blank suitcase coins gear dots_three list x
    envelope phone map_pin caret_down warning_circle check_circle lock_simple plus
    pencil_simple users_two file_text magnifying_glass info spinner globe star
  ].freeze
  IANA_TIMEZONE_IDENTIFIERS = TZInfo::Timezone.all_identifiers.sort.freeze

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
    when SupplierEmailAddress then record.address
    when SupplierContactEmailAddress then record.address
    when ClientPersonPhoneNumber
      record.formatted_number(viewer_country: Current.agency&.country_code)
    when ClientOrganizationPhoneNumber
      PhoneNumberNormalizer.display(
        normalized_number: record.normalized_number,
        country_code: record.country_code,
        extension: record.extension,
        viewer_country: Current.agency&.country_code
      )
    when SupplierPhoneNumber, SupplierContactPhoneNumber
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
    when SupplierPostalAddress
      [ record.line_1, record.line_2, record.locality, record.region, record.postal_code, record.country_code ].compact_blank.join(", ")
    when ClientOrganizationWebsite
      record.url
    when SupplierWebsite
      record.url
    when SupplierLocation
      supplier_location_phone_display(record)
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

  def supplier_contact_form_url(supplier, record)
    case record
    when SupplierEmailAddress
      record.persisted? ? supplier_email_address_path(supplier, record) : supplier_email_addresses_path(supplier)
    when SupplierPhoneNumber
      record.persisted? ? supplier_phone_number_path(supplier, record) : supplier_phone_numbers_path(supplier)
    when SupplierPostalAddress
      record.persisted? ? supplier_postal_address_path(supplier, record) : supplier_postal_addresses_path(supplier)
    when SupplierWebsite
      record.persisted? ? supplier_website_path(supplier, record) : supplier_websites_path(supplier)
    end
  end

  def supplier_contact_edit_path(record)
    case record
    when SupplierEmailAddress then edit_supplier_email_address_path(record.supplier_id, record)
    when SupplierPhoneNumber then edit_supplier_phone_number_path(record.supplier_id, record)
    when SupplierPostalAddress then edit_supplier_postal_address_path(record.supplier_id, record)
    when SupplierWebsite then edit_supplier_website_path(record.supplier_id, record)
    end
  end

  def supplier_contact_set_primary_path(record)
    case record
    when SupplierEmailAddress then set_primary_supplier_email_address_path(record.supplier_id, record)
    when SupplierPhoneNumber then set_primary_supplier_phone_number_path(record.supplier_id, record)
    when SupplierPostalAddress then set_primary_supplier_postal_address_path(record.supplier_id, record)
    when SupplierWebsite then set_primary_supplier_website_path(record.supplier_id, record)
    end
  end

  def supplier_contact_status_path(record)
    case record
    when SupplierEmailAddress then status_edit_supplier_email_address_path(record.supplier_id, record)
    when SupplierPhoneNumber then status_edit_supplier_phone_number_path(record.supplier_id, record)
    when SupplierPostalAddress then status_edit_supplier_postal_address_path(record.supplier_id, record)
    when SupplierWebsite then status_edit_supplier_website_path(record.supplier_id, record)
    end
  end

  def supplier_contact_status_update_path(record)
    case record
    when SupplierEmailAddress then status_supplier_email_address_path(record.supplier_id, record)
    when SupplierPhoneNumber then status_supplier_phone_number_path(record.supplier_id, record)
    when SupplierPostalAddress then status_supplier_postal_address_path(record.supplier_id, record)
    when SupplierWebsite then status_supplier_website_path(record.supplier_id, record)
    end
  end

  def supplier_contact_owned_destination_form_url(supplier, contact, record)
    case record
    when SupplierContactEmailAddress
      if record.persisted?
        supplier_contact_email_address_path(supplier, contact, record)
      else
        supplier_contact_email_addresses_path(supplier, contact)
      end
    when SupplierContactPhoneNumber
      if record.persisted?
        supplier_contact_phone_number_path(supplier, contact, record)
      else
        supplier_contact_phone_numbers_path(supplier, contact)
      end
    end
  end

  def supplier_contact_owned_destination_edit_path(supplier, contact, record)
    case record
    when SupplierContactEmailAddress then edit_supplier_contact_email_address_path(supplier, contact, record)
    when SupplierContactPhoneNumber then edit_supplier_contact_phone_number_path(supplier, contact, record)
    end
  end

  def supplier_contact_owned_destination_set_primary_path(supplier, contact, record)
    case record
    when SupplierContactEmailAddress then set_primary_supplier_contact_email_address_path(supplier, contact, record)
    when SupplierContactPhoneNumber then set_primary_supplier_contact_phone_number_path(supplier, contact, record)
    end
  end

  def supplier_contact_owned_destination_status_edit_path(supplier, contact, record)
    case record
    when SupplierContactEmailAddress then status_edit_supplier_contact_email_address_path(supplier, contact, record)
    when SupplierContactPhoneNumber then status_edit_supplier_contact_phone_number_path(supplier, contact, record)
    end
  end

  def supplier_contact_owned_destination_status_path(supplier, contact, record)
    case record
    when SupplierContactEmailAddress then status_supplier_contact_email_address_path(supplier, contact, record)
    when SupplierContactPhoneNumber then status_supplier_contact_phone_number_path(supplier, contact, record)
    end
  end

  def supplier_directory_result_path(result)
    case result.result_kind
    when "supplier" then supplier_path(result.id)
    when "location" then supplier_location_path(result.supplier_id, result.id)
    when "contact" then supplier_contact_path(result.supplier_id, result.id)
    end
  end

  def supplier_directory_result_context(result)
    case result.result_kind
    when "supplier"
      kind = result.supplier_kind.to_s.titleize
      categories = Array(result.category_codes).map { |code| SupplierCategory::LABELS.fetch(code) }.to_sentence
      categories.present? ? "#{kind} · #{categories}" : kind
    when "location"
      "Location · #{result.supplier_display_name}"
    when "contact"
      "Contact · #{result.supplier_display_name}"
    end
  end

  def supplier_location_address_display(location)
    [
      location.address_line_1,
      location.address_line_2,
      [ location.address_locality, location.address_region ].compact_blank.join(", "),
      location.address_postal_code,
      location.address_country_code
    ].compact_blank.join(", ")
  end

  def supplier_location_phone_display(location)
    return if location.phone_normalized_number.blank?

    PhoneNumberNormalizer.display(
      normalized_number: location.phone_normalized_number,
      country_code: location.phone_country_code,
      extension: location.phone_extension,
      viewer_country: Current.agency&.country_code
    )
  end

  def duplicate_candidate_path(candidate)
    class_name = candidate.class.name
    if class_name.include?("FindSupplierLocationDuplicates")
      supplier_location_path(@supplier, candidate.id)
    elsif class_name.include?("FindSupplierContactDuplicates")
      supplier_contact_path(@supplier, candidate.id)
    elsif class_name.include?("Supplier") || class_name == "FindSupplierDuplicates::Candidate"
      supplier_path(candidate.id)
    elsif class_name.include?("Organization")
      client_organization_path(candidate.id)
    else
      client_person_path(candidate.id)
    end
  end

  def preferred_indicator(record, preferred_label: "Preferred", not_preferred_label: "Not preferred")
    preferred = record.preferred?
    label = preferred ? preferred_label : not_preferred_label
    tag.span class: "dd-preferred-mark#{ " is-preferred" if preferred }", title: label do
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

  def iana_timezone_options
    IANA_TIMEZONE_IDENTIFIERS
  end

  def departure_status_badge(status)
    modifier = case status.to_s
    when "active" then "success"
    when "departed" then "info"
    else "neutral"
    end

    status_badge(status.to_s.titleize, modifier:)
  end

  def supplier_arrangement_status_badge(status)
    modifier = case status.to_s
    when "active" then "success"
    when "ended" then "info"
    when "abandoned" then "neutral"
    else "warning"
    end

    status_badge(status.to_s.titleize, modifier:)
  end

  def supplier_option_label(supplier)
    label = supplier.display_name_for_directory
    label = "#{label} (Inactive)" if supplier.inactive?
    "#{label} · #{supplier.supplier_reference}"
  end

  def supplier_contact_option_label(contact)
    label = contact.display_name_for_directory
    label = "#{label} (Inactive)" if contact.inactive?
    "#{contact.supplier.display_name_for_directory} · #{label}"
  end

  def arrangement_item_category_label(category, other_label = nil)
    label = category.to_s.titleize
    other_label.present? ? "#{label}: #{other_label}" : label
  end

  def occurrence_date_label(definition)
    label = if definition.starts_on == definition.ends_on
      definition.starts_on.to_fs(:long)
    else
      "#{definition.starts_on.to_fs(:long)} - #{definition.ends_on.to_fs(:long)}"
    end

    times = [ definition.starts_at_local, definition.ends_at_local ].compact
    return label if times.empty?

    "#{label}, #{times.map { |time| time.strftime("%H:%M") }.join(" - ")} #{definition.time_zone}"
  end

  def effective_service_provider(arrangement, item_definition, occurrence_definition = nil)
    occurrence_definition&.service_provider ||
      item_definition.default_service_provider ||
      arrangement.contracting_supplier
  end

  def capacity_management_label(value)
    case value
    when "managed" then "Managed capacity"
    when "unmanaged" then "No managed capacity"
    else "Not decided"
    end
  end

  def capacity_configuration_mode(departure:, arrangement:, version:, contractor:, supplying_suppliers: [])
    return :read_only unless Current.agency_user&.permitted?(:manage_departures)
    return :read_only if arrangement.abandoned? || version.abandoned?
    return :read_only unless (arrangement.draft? || arrangement.active?) && version.draft?
    return :recovery if departure.departed? ||
      contractor&.inactive? ||
      Array(supplying_suppliers).compact.any?(&:inactive?)
    return :ordinary if departure.draft? || departure.active?

    :read_only
  end

  def capacity_pair_label(pair)
    case pair&.classification
    when "pooled" then "Pooled"
    when "not_applicable" then "Not applicable"
    else "Needs decision"
    end
  end

  def capacity_pair_badge(pair)
    modifier = case pair&.classification
    when "pooled" then "success"
    when "not_applicable" then "neutral"
    else "warning"
    end

    status_badge(capacity_pair_label(pair), modifier:)
  end

  def capacity_inventory_mode_label(mode)
    mode.to_s.tr("_", " ").titleize
  end

  def capacity_measurement_basis_label(basis)
    case basis
    when "resource_units" then "Resource units"
    when "traveler_positions" then "Traveler positions"
    else basis.to_s.titleize
    end
  end

  def scope_target_label(scope)
    case scope.target_kind
    when "arrangement"
      "Whole Arrangement"
    when "item"
      scope.arrangement_item&.definitions&.find_by(supplier_arrangement_version_id: scope.supplier_arrangement_version_id)&.name || "Item"
    when "occurrence"
      scope.service_occurrence&.definitions&.find_by(supplier_arrangement_version_id: scope.supplier_arrangement_version_id)&.name || "Occurrence"
    when "resource"
      scope.supplier_resource&.definitions&.find_by(supplier_arrangement_version_id: scope.supplier_arrangement_version_id)&.name || "Resource"
    when "capacity_pool"
      scope.capacity_pool&.definitions&.find_by(supplier_arrangement_version_id: scope.supplier_arrangement_version_id)&.label || "Capacity Pool"
    else
      scope.target_kind.to_s.humanize
    end
  end

  def capacity_quantity_label(pool_definition)
    return "Quantity not tracked" unless pool_definition.capacity_pool.numeric_inventory?

    pool_definition.proposed_opening_quantity.presence || "Proposed opening quantity missing"
  end

  def capacity_evidence_label(pool_definition)
    if pool_definition.override?
      "Administrator override recorded"
    elsif pool_definition.evidence_kind.present? && pool_definition.evidence_on.present? && pool_definition.evidence_reference_note.present?
      "#{pool_definition.evidence_kind.tr("_", " ").titleize} on #{pool_definition.evidence_on.to_fs(:long)}"
    else
      "Evidence incomplete"
    end
  end

  def capacity_pool_warnings(pool_definition, arrangement, item_definition, occurrence_definition)
    warnings = []
    pool = pool_definition.capacity_pool
    expected_provider = effective_service_provider(arrangement, item_definition, occurrence_definition)
    warnings << "Supplying Supplier is inactive." if pool.supplying_supplier.inactive?
    warnings << "Supplying Supplier no longer matches the effective provider." if expected_provider && pool.supplying_supplier_id != expected_provider.id
    warnings << "Pool time zone no longer matches the Occurrence definition." if occurrence_definition && pool.effective_time_zone != occurrence_definition.time_zone
    if pool.numeric_inventory?
      warnings << "Proposed opening quantity is missing." if pool_definition.proposed_opening_quantity.blank?
      unless pool_definition.override? || (pool_definition.evidence_kind.present? && pool_definition.evidence_on.present? && pool_definition.evidence_reference_note.present?)
        warnings << "Supplier evidence is incomplete."
      end
    end
    warnings
  end

  def capacity_item_warnings(item_definition, occurrence_definitions, resource_definitions, pairs_by_members, pool_definitions_by_pair_id, arrangement)
    warnings = []
    active_occurrence_definitions = occurrence_definitions.reject { |definition| definition.service_occurrence.cancelled? }
    if item_definition.capacity_management.blank?
      warnings << "Capacity management has not been decided."
    elsif item_definition.managed?
      warnings << "Managed capacity needs at least one Occurrence." if active_occurrence_definitions.empty?
      warnings << "Managed capacity needs at least one Resource." if resource_definitions.empty?
      active_occurrence_definitions.each do |occurrence_definition|
        resource_definitions.each do |resource_definition|
          pair = pairs_by_members[[ occurrence_definition.service_occurrence_id, resource_definition.supplier_resource_id ]]
          if pair.nil?
            warnings << "#{occurrence_definition.name} / #{resource_definition.name} needs a capacity decision."
          elsif pair.pooled? && pool_definitions_by_pair_id.fetch(pair.id, []).empty?
            warnings << "#{occurrence_definition.name} / #{resource_definition.name} is pooled but has no Pool."
          end
        end
      end
      pool_definitions_by_pair_id.values.flatten.each do |pool_definition|
        occurrence_definition = occurrence_definitions.find { |definition| definition.service_occurrence_id == pool_definition.service_occurrence_id }
        warnings.concat(capacity_pool_warnings(pool_definition, arrangement, item_definition, occurrence_definition))
      end
    end
    warnings.uniq
  end

  def departure_office_options(departure)
    records = Current.agency.offices.where(status: "active").order(:name).to_a
    current = departure.responsible_office
    records.unshift(current) if current && records.none? { |office| office.id == current.id }
    records.map { |office| [ office_choice_label(office), office.id ] }
  end

  def departure_user_options(departure)
    records = Current.agency.agency_users.where(status: "active").order(:last_name, :first_name).to_a
    current = departure.responsible_agency_user
    records.unshift(current) if current && records.none? { |user| user.id == current.id }
    records.map { |user| [ user.display_name, user.id ] }
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

  def dd_field_options(form, attribute, **options)
    object = form.object
    field_id = "#{object.model_name.param_key}_#{attribute}"
    error_id = "#{field_id}_error"
    described_by = [ options.delete(:aria_describedby_extra), (error_id if object.errors[attribute].any?) ].compact.join(" ").presence

    options[:class] = [ options[:class], "dd-field" ].compact.join(" ")
    options[:aria] = (options[:aria] || {}).merge(
      invalid: (object.errors[attribute].any? || nil),
      describedby: described_by
    ).compact
    options
  end

  def dd_field_error(form, attribute)
    return unless form.object.errors[attribute].any?

    tag.p(form.object.errors[attribute].to_sentence, class: "dd-field-error", id: "#{form.object.model_name.param_key}_#{attribute}_error")
  end

  def dd_tag_field_options(error_form, attribute, **options)
    options = options.dup
    options[:class] = [ options[:class], "dd-field" ].compact.join(" ")
    return options if error_form.nil?

    field_id = options[:id].presence || "#{error_form.model_name.param_key}_#{attribute}"
    error_id = "#{field_id}_error"
    has_error = error_form.errors[attribute].any?
    described_by = [ options.delete(:aria_describedby_extra), (error_id if has_error) ].compact.join(" ").presence
    options[:id] ||= field_id
    options[:aria] = (options[:aria] || {}).merge(
      invalid: (has_error || nil),
      describedby: described_by
    ).compact
    options
  end

  def dd_tag_field_error(error_form, attribute, field_id: nil)
    return if error_form.nil? || error_form.errors[attribute].blank?

    id = field_id || "#{error_form.model_name.param_key}_#{attribute}_error"
    tag.p(error_form.errors[attribute].to_sentence, class: "dd-field-error", id: id)
  end

  def attention_action_group_label(action_group)
    {
      "dispose_or_satisfy_commitment" => "Dispose or satisfy commitment",
      "resolve_deadline" => "Resolve Deadline",
      "complete_deposit_inputs" => "Complete deposit inputs",
      "inspect_exposure" => "Inspect exposure",
      "resolve_reservation_response" => "Resolve reservation response",
      "review_capacity" => "Review capacity"
    }.fetch(action_group.to_s, action_group.to_s.humanize)
  end

  def attention_severity_label(finding, at: Time.current)
    return "Overdue" if finding.overdue?(at)
    return "Blocking" if finding.blocking?

    "Needs attention"
  end

  def attention_finding_path(departure, arrangement, finding, version: nil)
    version ||= arrangement.governing_version || arrangement.versions.order(:version_number, :id).last
    case finding.primary_path
    when "commitments"
      departure_arrangement_commitments_path(departure, arrangement)
    when "exposure"
      departure_arrangement_exposure_path(departure, arrangement)
    when "deadlines"
      departure_arrangement_version_deadlines_path(departure, arrangement, version)
    when "deposits"
      departure_arrangement_version_deposits_path(departure, arrangement, version)
    when "capacity"
      departure_arrangement_path(departure, arrangement, anchor: "current-supplier-capacity")
    else
      departure_arrangement_path(departure, arrangement)
    end
  end

  def group_attention_findings(findings)
    findings.group_by(&:action_group).sort_by { |group, _| group }
  end
end
