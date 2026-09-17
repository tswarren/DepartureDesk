class CreateArrangementItem < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, arrangement:, attributes:, version_lock_version:, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @attributes = attributes.to_h.with_indifferent_access
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key || @attributes.delete(:idempotency_key)
  end

  def call
    ensure_arrangement_actor!
    attrs = normalize_item_attributes(@attributes)
    provider_id = parse_optional_uuid(@attributes[:default_service_provider_id], "Default service provider")

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      locked_suppliers = lock_suppliers_in_uuid_order!(@arrangement.contracting_supplier_id, provider_id)
      contractor = locked_suppliers.find { |supplier| supplier.id == @arrangement.contracting_supplier_id }
      provider = provider_id && locked_suppliers.find { |supplier| supplier.id == provider_id }
      raise ActiveRecord::RecordNotFound if provider_id && provider.nil?
      ensure_active_effective_provider!(provider) if provider

      departure, arrangement, version = lock_departure_arrangement_version!(@arrangement)
      ensure_ordinary_planning_edit!(departure, arrangement, version, contractor)

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: attrs.merge(
          supplier_arrangement_id: arrangement.id,
          supplier_arrangement_version_id: version.id,
          default_service_provider_id: provider&.id
        ),
        result_class: ArrangementItem
      ) do
        ensure_current_lock_version!(version, @version_lock_version)
        item, definition = build_arrangement_item_already_locked!(
          departure: departure,
          arrangement: arrangement,
          version: version,
          attributes: attrs,
          provider: provider
        )
        bump_version!(version)
        audit!(
          agency: @agency,
          action: "supplier_arrangement.item_created",
          subject: arrangement,
          actor: @actor,
          details: {
            "child_type" => "arrangement_item",
            "supplier_arrangement_id" => arrangement.id,
            "supplier_arrangement_version_id" => version.id,
            "arrangement_item_id" => item.id,
            "arrangement_item_definition_id" => definition.id,
            "name" => definition.name,
            "category" => definition.category,
            "other_category_label" => definition.other_category_label,
            "default_service_provider_id" => definition.default_service_provider_id,
            "position" => definition.position
          }
        )
        item
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
