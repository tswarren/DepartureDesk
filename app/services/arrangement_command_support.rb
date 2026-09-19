require "digest"
require "json"

module ArrangementCommandSupport
  extend ActiveSupport::Concern

  include DepartureCommandSupport

  IDEMPOTENCY_KEY_LIMIT = 120
  DESCRIPTION_LIMIT = 2_000
  OTHER_CATEGORY_LABEL_LIMIT = 80

  private

  def ensure_arrangement_actor!(permission = :manage_departures)
    ensure_directory_actor!(@actor, @agency, permission)
    ensure_active_agency!(@agency)
  end

  def lock_authorized_arrangement_agency!(permission = :manage_departures)
    lock_authorized_agency!(permission)
  end

  def lock_departure_for!(departure)
    @agency.departures.lock.find(departure.is_a?(Departure) ? departure.id : departure)
  end

  def lock_arrangement_for!(arrangement)
    @agency.supplier_arrangements.lock.find(arrangement.is_a?(SupplierArrangement) ? arrangement.id : arrangement)
  end

  def lock_editable_draft_version_for!(arrangement)
    arrangement.versions.lock.find_by(status: "draft") ||
      raise(AgencyCommand::Error.new(
        "That supplier arrangement has no editable draft.", code: :invalid_state
      ))
  end

  # Contract order: Departure → Arrangement → version.
  def lock_departure_arrangement_version!(arrangement)
    departure = lock_departure_for!(arrangement.departure_id)
    locked_arrangement = lock_arrangement_for!(arrangement)
    version = lock_editable_draft_version_for!(locked_arrangement)
    [ departure, locked_arrangement, version ]
  end

  def lock_suppliers_in_uuid_order!(*supplier_ids)
    ids = supplier_ids.flatten.compact.map { |value| value.respond_to?(:id) ? value.id : value }.uniq.sort
    ids.map { |id| @agency.suppliers.lock.find(id) }
  end

  def locked_supplier!(id)
    @agency.suppliers.lock.find(id)
  end

  def lock_arrangement_item_for!(arrangement, item)
    arrangement.arrangement_items.lock.find(item.id)
  end

  def lock_item_definition_for!(version, definition)
    version.arrangement_item_definitions.lock.find(definition.id)
  end

  def lock_occurrence_for!(item, occurrence)
    item.service_occurrences.lock.find(occurrence.id)
  end

  def lock_occurrence_definition_for!(version, definition)
    version.service_occurrence_definitions.lock.find(definition.id)
  end

  def lock_resource_for!(item, resource)
    item.supplier_resources.lock.find(resource.id)
  end

  def lock_resource_definition_for!(version, definition)
    version.supplier_resource_definitions.lock.find(definition.id)
  end

  def ensure_departure_accepts_new_planning!(departure)
    return if departure.draft? || departure.active?

    raise AgencyCommand::Error.new("A departed departure cannot create supplier arrangement planning.", code: :invalid_state) if departure.departed?

    raise AgencyCommand::Error.new("That departure cannot be edited.", code: :invalid_state)
  end

  def ensure_draft_graph!(arrangement, version)
    editable_draft = arrangement.versions.find_by(status: "draft")
    unless (arrangement.draft? || arrangement.active?) &&
        version.draft? && editable_draft&.id == version.id
      raise AgencyCommand::Error.new("That supplier arrangement cannot be edited.", code: :invalid_state)
    end
  end

  def ordinary_planning_state?(departure, contractor)
    (departure.draft? || departure.active?) && contractor.active?
  end

  def ensure_ordinary_planning_edit!(departure, arrangement, version, contractor)
    ensure_draft_graph!(arrangement, version)
    return if ordinary_planning_state?(departure, contractor)

    if departure.departed?
      raise AgencyCommand::Error.new("A departed departure cannot expand supplier arrangement planning.", code: :invalid_state)
    end
    unless contractor.active?
      raise AgencyCommand::Error.new("An inactive contracting supplier cannot expand supplier arrangement planning.", code: :invalid_state)
    end

    raise AgencyCommand::Error.new("That departure cannot be edited.", code: :invalid_state)
  end

  def ensure_cleanup_edit!(departure, arrangement, version)
    ensure_draft_graph!(arrangement, version)
    return if departure.draft? || departure.active? || departure.departed?

    raise AgencyCommand::Error.new("That departure cannot be edited.", code: :invalid_state)
  end

  def ensure_no_capacity_structure_for_item!(version, item)
    if version.capacity_pair_definitions.where(arrangement_item: item).exists? ||
        version.capacity_pool_definitions.where(arrangement_item: item).exists? ||
        item.capacity_pools.exists?
      raise AgencyCommand::Error.new(
        "Remove capacity pools and pair classifications before removing this item.",
        code: :dependency_exists
      )
    end
  end

  def ensure_no_capacity_structure_for_occurrence!(version, occurrence)
    if version.capacity_pair_definitions.where(service_occurrence: occurrence).exists? ||
        version.capacity_pool_definitions.where(service_occurrence: occurrence).exists? ||
        occurrence.capacity_pools.exists?
      raise AgencyCommand::Error.new(
        "Remove capacity pools and pair classifications before removing this occurrence.",
        code: :dependency_exists
      )
    end
  end

  def ensure_no_capacity_structure_for_resource!(version, resource)
    if version.capacity_pair_definitions.where(supplier_resource: resource).exists? ||
        version.capacity_pool_definitions.where(supplier_resource: resource).exists? ||
        resource.capacity_pools.exists?
      raise AgencyCommand::Error.new(
        "Remove capacity pools and pair classifications before removing this resource.",
        code: :dependency_exists
      )
    end
  end

  def ensure_no_cost_structure_for_item!(version, item)
    if version.supplier_cost_sources.where(arrangement_item: item).exists? ||
        version.supplier_cost_usage_assumptions.where(arrangement_item: item).exists? ||
        version.supplier_cost_participant_categories.where(arrangement_item: item).exists?
      raise AgencyCommand::Error.new(
        "Remove cost sources, assumptions, and participant categories before removing this item.",
        code: :dependency_exists
      )
    end
  end

  def ensure_no_cost_structure_for_occurrence!(version, occurrence)
    if version.supplier_cost_sources.where(service_occurrence: occurrence).exists? ||
        version.supplier_cost_usage_assumptions.where(service_occurrence: occurrence).exists?
      raise AgencyCommand::Error.new(
        "Remove cost sources and assumptions before removing this occurrence.",
        code: :dependency_exists
      )
    end
  end

  def ensure_no_cost_structure_for_resource!(version, resource)
    if version.supplier_cost_sources.where(supplier_resource: resource).exists? ||
        version.supplier_cost_usage_assumptions.where(supplier_resource: resource).exists?
      raise AgencyCommand::Error.new(
        "Remove cost sources and assumptions before removing this resource.",
        code: :dependency_exists
      )
    end
  end

  def ensure_editable_draft_arrangement!(departure, arrangement, version, allow_departed: false)
    ensure_draft_graph!(arrangement, version)

    return if departure.draft? || departure.active?
    return if allow_departed && departure.departed?

    raise AgencyCommand::Error.new("A departed departure cannot expand supplier arrangement planning.", code: :invalid_state) if departure.departed?

    raise AgencyCommand::Error.new("That departure cannot be edited.", code: :invalid_state)
  end

  def ensure_not_abandoned!(arrangement, version)
    return unless arrangement.abandoned? || version.abandoned?

    raise AgencyCommand::Error.new("That supplier arrangement has been abandoned.", code: :invalid_state)
  end

  def ensure_active_effective_provider!(provider)
    return if provider.nil? || provider.active?

    raise AgencyCommand::Error.new("That service provider is not active.", code: :invalid_state)
  end

  def inactive_provider_recovery_only?(definition, attrs, provider_attribute)
    non_provider_attrs = attrs.except(provider_attribute)
    return false unless same_values?(definition, non_provider_attrs)

    previous_id = definition.public_send(provider_attribute)
    next_id = attrs[provider_attribute]
    return false if previous_id.nil?
    return false if previous_id == next_id

    previous = @agency.suppliers.find_by(id: previous_id)
    previous&.inactive?
  end

  def recovery_message
    "That supplier arrangement can only clear an inactive contact, clear or replace an inactive service provider, remove draft structure, or be abandoned."
  end

  def ensure_current_lock_version!(record, submitted = nil)
    expected = submitted.nil? ? @lock_version : submitted
    if expected.nil? || record.lock_version != expected.to_i
      raise AgencyCommand::Error.new(STALE_MESSAGE, code: :conflict)
    end
  end

  def bump_version!(version)
    version.touch
    version.reload
  end

  def normalize_idempotency_key(value)
    key = value.to_s.strip
    raise AgencyCommand::Error.new("Enter an idempotency key.", code: :invalid) if key.blank?
    if key.length > IDEMPOTENCY_KEY_LIMIT
      raise AgencyCommand::Error.new("Idempotency key must be #{IDEMPOTENCY_KEY_LIMIT} characters or fewer.", code: :invalid)
    end

    key
  end

  def idempotent_create!(command_name:, idempotency_key:, payload:, result_class:)
    key = normalize_idempotency_key(idempotency_key)
    digest = payload_digest(payload)
    lock_idempotency_slot!(command_name, key)

    existing = AgencyCommandIdempotencyKey.where(
      agency: @agency,
      command_name: command_name,
      idempotency_key: key
    ).lock.first
    if existing
      raise AgencyCommand::Error.new("That idempotency key was already used for different input.", code: :conflict) unless existing.payload_digest == digest

      return AgencyCommand::Result.new(status: :replayed, record: result_class.find(existing.result_record_id))
    end

    record = yield
    AgencyCommandIdempotencyKey.create!(
      agency: @agency,
      command_name: command_name,
      idempotency_key: key,
      payload_digest: digest,
      result_record_type: result_class.name,
      result_record_id: record.id
    )
    AgencyCommand::Result.new(status: :created, record: record)
  rescue ActiveRecord::RecordNotUnique
    raise AgencyCommand::Error.new("That idempotency key was already used for different input.", code: :conflict)
  end

  def payload_digest(payload)
    canonical = deep_sort_for_digest(payload)
    "sha256:#{Digest::SHA256.hexdigest(JSON.generate(canonical))}"
  end

  def deep_sort_for_digest(value)
    case value
    when Hash
      value.each_with_object({}) do |(key, item), sorted|
        sorted[key.to_s] = deep_sort_for_digest(item)
      end.sort.to_h
    when Array
      value.map { |item| deep_sort_for_digest(item) }
    when Date, Time, ActiveSupport::TimeWithZone
      value.iso8601
    else
      value
    end
  end

  def lock_idempotency_slot!(command_name, key)
    quoted = ActiveRecord::Base.connection.quote("#{@agency.id}:#{command_name}:#{key}")
    ActiveRecord::Base.connection.execute("SELECT pg_advisory_xact_lock(hashtextextended(#{quoted}, 0))")
  end

  def normalize_arrangement_name(value)
    name = value.to_s.strip
    raise AgencyCommand::Error.new("Enter a name.", code: :invalid) if name.blank?
    if name.length > SupplierArrangement::NAME_LIMIT
      raise AgencyCommand::Error.new("Name must be #{SupplierArrangement::NAME_LIMIT} characters or fewer.", code: :invalid)
    end

    name
  end

  def normalize_definition_name(value)
    name = value.to_s.strip
    raise AgencyCommand::Error.new("Enter a name.", code: :invalid) if name.blank?
    if name.length > ArrangementItemDefinition::NAME_LIMIT
      raise AgencyCommand::Error.new("Name must be #{ArrangementItemDefinition::NAME_LIMIT} characters or fewer.", code: :invalid)
    end

    name
  end

  def normalize_definition_description(value)
    description = value.to_s.strip.presence
    if description && description.length > DESCRIPTION_LIMIT
      raise AgencyCommand::Error.new("Description must be #{DESCRIPTION_LIMIT} characters or fewer.", code: :invalid)
    end

    description
  end

  def normalize_category(value)
    category = value.to_s.strip.presence
    unless ArrangementItemDefinition::CATEGORIES.include?(category)
      raise AgencyCommand::Error.new("Choose a valid item category.", code: :invalid)
    end

    category
  end

  def normalize_other_category_label(category, value)
    label = value.to_s.strip.presence
    if category == "other"
      raise AgencyCommand::Error.new("Enter an other category label.", code: :invalid) if label.blank?
      if label.length > OTHER_CATEGORY_LABEL_LIMIT
        raise AgencyCommand::Error.new("Other category label must be #{OTHER_CATEGORY_LABEL_LIMIT} characters or fewer.", code: :invalid)
      end
    elsif label.present?
      raise AgencyCommand::Error.new("Other category label must be blank unless category is other.", code: :invalid)
    end

    label
  end

  def normalize_local_time(value, label)
    return nil if value.blank?
    return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

    Time.zone.parse(value.to_s).tap do |parsed|
      raise AgencyCommand::Error.new("#{label} is not a valid local time.", code: :invalid) if parsed.blank?
    end
  rescue ArgumentError, TypeError
    raise AgencyCommand::Error.new("#{label} is not a valid local time.", code: :invalid)
  end

  def normalize_optional_zone(value, fallback:)
    raw = value.to_s.strip.presence || fallback
    raise AgencyCommand::Error.new("Enter a recognized time zone.", code: :invalid) if raw.blank?

    normalize_time_zone(raw)
  end

  def normalize_item_attributes(attrs)
    attrs = attrs.to_h.with_indifferent_access
    category = normalize_category(attrs[:category])
    {
      name: normalize_definition_name(attrs[:name]),
      description: normalize_definition_description(attrs[:description]),
      category: category,
      other_category_label: normalize_other_category_label(category, attrs[:other_category_label])
    }
  end

  def normalize_occurrence_attributes(attrs, departure)
    attrs = attrs.to_h.with_indifferent_access
    starts_on = parse_date(attrs[:starts_on], "Start date")
    ends_on = parse_date(attrs[:ends_on], "End date")
    if starts_on.blank? || ends_on.blank?
      raise AgencyCommand::Error.new("Enter a start date and an end date.", code: :invalid)
    end
    if starts_on > ends_on
      raise AgencyCommand::Error.new("End date must be on or after the start date.", code: :invalid)
    end

    starts_at = normalize_local_time(attrs[:starts_at_local], "Start time")
    ends_at = normalize_local_time(attrs[:ends_at_local], "End time")
    if starts_at.blank? ^ ends_at.blank?
      raise AgencyCommand::Error.new("Enter both a local start time and local end time, or leave both blank.", code: :invalid)
    end

    {
      name: normalize_definition_name(attrs[:name]),
      description: normalize_definition_description(attrs[:description]),
      starts_on: starts_on,
      ends_on: ends_on,
      starts_at_local: starts_at,
      ends_at_local: ends_at,
      time_zone: normalize_optional_zone(attrs[:time_zone], fallback: departure.time_zone)
    }
  end

  def normalize_resource_attributes(attrs)
    attrs = attrs.to_h.with_indifferent_access
    {
      name: normalize_definition_name(attrs[:name]),
      description: normalize_definition_description(attrs[:description])
    }
  end

  def resolve_active_supplier!(id, label)
    uuid = parse_optional_uuid(id, label)
    raise AgencyCommand::Error.new("#{label} is required.", code: :invalid) if uuid.blank?

    supplier = @agency.suppliers.lock.find_by(id: uuid)
    raise ActiveRecord::RecordNotFound if supplier.nil?
    raise AgencyCommand::Error.new("That supplier is not active.", code: :invalid_state) unless supplier.active?

    supplier
  end

  def resolve_optional_active_supplier!(id, label)
    uuid = parse_optional_uuid(id, label)
    return if uuid.blank?

    resolve_active_supplier!(uuid, label)
  end

  def resolve_optional_contact!(supplier, id, allow_inactive_clear: false)
    uuid = parse_optional_uuid(id, "Supplier contact")
    return if uuid.blank?

    contact = supplier.contacts.lock.find_by(id: uuid)
    raise ActiveRecord::RecordNotFound if contact.nil?
    if contact.inactive? && !allow_inactive_clear
      raise AgencyCommand::Error.new("That supplier contact is not active.", code: :invalid_state)
    end

    contact
  end

  def next_item_position(version)
    version.arrangement_item_definitions.maximum(:position).to_i + 1
  end

  def next_resource_position(version, item)
    version.supplier_resource_definitions.where(arrangement_item: item).maximum(:position).to_i + 1
  end

  # Internal create operations for composite commands. Callers must already hold
  # the canonical agency/Departure/Arrangement/version/member locks and perform
  # authorization, state, optimistic-lock, idempotency, version-bump, and audit
  # work at the public command boundary.
  def build_arrangement_item_already_locked!(departure:, arrangement:, version:, attributes:, provider: nil)
    item = arrangement.arrangement_items.create!(agency: @agency, departure: departure)
    definition = version.arrangement_item_definitions.create!(
      attributes.merge(
        agency: @agency,
        departure: departure,
        supplier_arrangement: arrangement,
        arrangement_item: item,
        default_service_provider: provider,
        position: next_item_position(version)
      )
    )
    [ item, definition ]
  end

  def build_service_occurrence_already_locked!(
    departure:, arrangement:, version:, item:, attributes:, provider: nil
  )
    occurrence = item.service_occurrences.create!(
      agency: @agency,
      departure: departure,
      supplier_arrangement: arrangement,
      status: "planned"
    )
    definition = version.service_occurrence_definitions.create!(
      attributes.merge(
        agency: @agency,
        departure: departure,
        supplier_arrangement: arrangement,
        arrangement_item: item,
        service_occurrence: occurrence,
        service_provider: provider
      )
    )
    [ occurrence, definition ]
  end

  def build_supplier_resource_already_locked!(
    departure:, arrangement:, version:, item:, attributes:
  )
    resource = item.supplier_resources.create!(
      agency: @agency,
      departure: departure,
      supplier_arrangement: arrangement
    )
    definition = version.supplier_resource_definitions.create!(
      attributes.merge(
        agency: @agency,
        departure: departure,
        supplier_arrangement: arrangement,
        arrangement_item: item,
        supplier_resource: resource,
        position: next_resource_position(version, item)
      )
    )
    [ resource, definition ]
  end

  def same_values?(record, attrs)
    attrs.all? { |field, value| record.public_send(field) == value }
  end

  def changed_fields(record, attrs)
    attrs.keys.select { |field| record.saved_change_to_attribute?(field) }.map(&:to_s)
  end

  def rebuild_exposure_projection_already_locked!(arrangement, version: nil, at: Time.current)
    RebuildSupplierExposureProjectionAlreadyLocked.new(
      agency: @agency,
      arrangement:,
      version:,
      at:
    ).call
  end
end
