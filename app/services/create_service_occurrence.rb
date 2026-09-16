class CreateServiceOccurrence < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, item:, attributes:, version_lock_version:, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @item = item
    @attributes = attributes.to_h.with_indifferent_access
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key || @attributes.delete(:idempotency_key)
  end

  def call
    ensure_arrangement_actor!
    provider_id = parse_optional_uuid(@attributes[:service_provider_id], "Service provider")

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      locked_suppliers = lock_suppliers_in_uuid_order!(@item.supplier_arrangement.contracting_supplier_id, provider_id)
      contractor = locked_suppliers.find { |supplier| supplier.id == @item.supplier_arrangement.contracting_supplier_id }
      provider = provider_id && locked_suppliers.find { |supplier| supplier.id == provider_id }
      raise ActiveRecord::RecordNotFound if provider_id && provider.nil?
      ensure_active_effective_provider!(provider) if provider

      departure, arrangement, version = lock_departure_arrangement_version!(@item.supplier_arrangement)
      attrs = normalize_occurrence_attributes(@attributes, departure)
      item = lock_arrangement_item_for!(arrangement, @item)
      item_definition = version.arrangement_item_definitions.find_by!(arrangement_item: item)
      ensure_ordinary_planning_edit!(departure, arrangement, version, contractor)

      effective_provider = provider || item_definition.default_service_provider || contractor
      ensure_active_effective_provider!(effective_provider)

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: attrs.merge(
          supplier_arrangement_id: arrangement.id,
          supplier_arrangement_version_id: version.id,
          arrangement_item_id: item.id,
          service_provider_id: provider&.id
        ),
        result_class: ServiceOccurrence
      ) do
        ensure_current_lock_version!(version, @version_lock_version)
        occurrence = item.service_occurrences.create!(
          agency: @agency,
          departure: departure,
          supplier_arrangement: arrangement,
          status: "planned"
        )
        definition = version.service_occurrence_definitions.create!(
          attrs.merge(
            agency: @agency,
            departure: departure,
            supplier_arrangement: arrangement,
            arrangement_item: item,
            service_occurrence: occurrence,
            service_provider: provider
          )
        )
        bump_version!(version)
        audit!(
          agency: @agency,
          action: "supplier_arrangement.occurrence_created",
          subject: arrangement,
          actor: @actor,
          details: {
            "child_type" => "service_occurrence",
            "supplier_arrangement_id" => arrangement.id,
            "supplier_arrangement_version_id" => version.id,
            "arrangement_item_id" => item.id,
            "service_occurrence_id" => occurrence.id,
            "service_occurrence_definition_id" => definition.id,
            "name" => definition.name,
            "starts_on" => definition.starts_on.iso8601,
            "ends_on" => definition.ends_on.iso8601,
            "starts_at_local" => definition.starts_at_local&.strftime("%H:%M:%S"),
            "ends_at_local" => definition.ends_at_local&.strftime("%H:%M:%S"),
            "time_zone" => definition.time_zone,
            "service_provider_id" => definition.service_provider_id
          }
        )
        occurrence
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
