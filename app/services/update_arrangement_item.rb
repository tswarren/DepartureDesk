class UpdateArrangementItem < AgencyCommand
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
    attrs = normalize_item_attributes(@attributes)
    provider_id = parse_optional_uuid(@attributes[:default_service_provider_id], "Default service provider")

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      locked_suppliers = lock_suppliers_in_uuid_order!(@definition.supplier_arrangement.contracting_supplier_id, provider_id)
      contractor = locked_suppliers.find { |supplier| supplier.id == @definition.supplier_arrangement.contracting_supplier_id }
      provider = provider_id && locked_suppliers.find { |supplier| supplier.id == provider_id }
      raise ActiveRecord::RecordNotFound if provider_id && provider.nil?
      ensure_active_effective_provider!(provider) if provider

      departure, arrangement, version = lock_departure_arrangement_version!(@definition.supplier_arrangement)
      item = lock_arrangement_item_for!(arrangement, @definition.arrangement_item)
      definition = lock_item_definition_for!(version, @definition)
      attrs[:default_service_provider_id] = provider&.id
      ensure_item_update_allowed!(departure, arrangement, version, contractor, definition, attrs)
      ensure_current_lock_version!(definition)

      return Result.new(status: :noop, record: definition) if same_values?(definition, attrs)

      definition.update!(attrs)
      audit!(
        agency: @agency,
        action: "supplier_arrangement.item_updated",
        subject: arrangement,
        actor: @actor,
        details: {
          "child_type" => "arrangement_item",
          "supplier_arrangement_id" => arrangement.id,
          "supplier_arrangement_version_id" => version.id,
          "arrangement_item_id" => item.id,
          "arrangement_item_definition_id" => definition.id,
          "changed_fields" => changed_fields(definition, attrs),
          "default_service_provider_id" => definition.default_service_provider_id,
          "category" => definition.category,
          "position" => definition.position
        }
      )
      Result.new(status: :updated, record: definition)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def ensure_item_update_allowed!(departure, arrangement, version, contractor, definition, attrs)
    ensure_draft_graph!(arrangement, version)
    return if ordinary_planning_state?(departure, contractor)
    if contractor.inactive?
      raise Error.new(recovery_message, code: :invalid_state)
    end
    return if inactive_provider_recovery_only?(definition, attrs, :default_service_provider_id) &&
      (departure.departed? || departure.draft? || departure.active?)

    raise Error.new(recovery_message, code: :invalid_state)
  end
end
