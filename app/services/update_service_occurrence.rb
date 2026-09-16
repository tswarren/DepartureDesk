class UpdateServiceOccurrence < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, definition:, attributes:, lock_version:)
    @agency = agency
    @actor = actor
    @definition = definition
    @attributes = attributes.to_h.with_indifferent_access
    @lock_version = lock_version
  end

  def call
    ensure_arrangement_actor!
    provider_id = parse_optional_uuid(@attributes[:service_provider_id], "Service provider")

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      locked_suppliers = lock_suppliers_in_uuid_order!(@definition.supplier_arrangement.contracting_supplier_id, provider_id)
      contractor = locked_suppliers.find { |supplier| supplier.id == @definition.supplier_arrangement.contracting_supplier_id }
      provider = provider_id && locked_suppliers.find { |supplier| supplier.id == provider_id }
      raise ActiveRecord::RecordNotFound if provider_id && provider.nil?
      ensure_active_effective_provider!(provider) if provider

      departure, arrangement, version = lock_departure_arrangement_version!(@definition.supplier_arrangement)
      attrs = normalize_occurrence_attributes(@attributes, departure)
      item = lock_arrangement_item_for!(arrangement, @definition.arrangement_item)
      occurrence = lock_occurrence_for!(item, @definition.service_occurrence)
      definition = lock_occurrence_definition_for!(version, @definition)
      item_definition = version.arrangement_item_definitions.find_by!(arrangement_item: item)
      attrs[:service_provider_id] = provider&.id
      ensure_occurrence_update_allowed!(departure, arrangement, version, contractor, definition, item_definition, attrs, provider)
      ensure_current_lock_version!(definition)

      return Result.new(status: :noop, record: definition) if same_values?(definition, attrs)

      definition.update!(attrs)
      audit!(
        agency: @agency,
        action: "supplier_arrangement.occurrence_updated",
        subject: arrangement,
        actor: @actor,
        details: {
          "child_type" => "service_occurrence",
          "supplier_arrangement_id" => arrangement.id,
          "supplier_arrangement_version_id" => version.id,
          "arrangement_item_id" => item.id,
          "service_occurrence_id" => occurrence.id,
          "service_occurrence_definition_id" => definition.id,
          "changed_fields" => changed_fields(definition, attrs),
          "starts_on" => definition.starts_on.iso8601,
          "ends_on" => definition.ends_on.iso8601,
          "starts_at_local" => definition.starts_at_local&.strftime("%H:%M:%S"),
          "ends_at_local" => definition.ends_at_local&.strftime("%H:%M:%S"),
          "time_zone" => definition.time_zone,
          "service_provider_id" => definition.service_provider_id
        }
      )
      Result.new(status: :updated, record: definition)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def ensure_occurrence_update_allowed!(departure, arrangement, version, contractor, definition, item_definition, attrs, provider)
    ensure_draft_graph!(arrangement, version)
    if ordinary_planning_state?(departure, contractor)
      effective = provider || item_definition.default_service_provider || contractor
      ensure_active_effective_provider!(effective)
      return
    end
    if contractor.inactive?
      raise Error.new(recovery_message, code: :invalid_state)
    end

    return if inactive_provider_recovery_only?(definition, attrs, :service_provider_id) &&
      (departure.departed? || departure.draft? || departure.active?)

    raise Error.new(recovery_message, code: :invalid_state)
  end
end
