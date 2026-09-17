class CreateArrangementItemSetup < AgencyCommand
  include ArrangementCommandSupport

  SetupResult = Data.define(:item, :occurrence, :resource)

  def initialize(agency:, actor:, arrangement:, item_attributes:, occurrence_attributes: nil,
    resource_attributes: nil, version_lock_version:, idempotency_key:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @item_attributes = item_attributes
    @occurrence_attributes = occurrence_attributes
    @resource_attributes = resource_attributes
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    item_attrs = normalize_item_attributes(@item_attributes)
    item_provider_id = parse_optional_uuid(
      @item_attributes.to_h.with_indifferent_access[:default_service_provider_id],
      "Default service provider"
    )
    occurrence_input = @occurrence_attributes&.to_h&.with_indifferent_access
    occurrence_provider_id = parse_optional_uuid(
      occurrence_input&.[](:service_provider_id), "Service provider"
    )
    resource_input = @resource_attributes&.to_h&.with_indifferent_access

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      suppliers = lock_suppliers_in_uuid_order!(
        @arrangement.contracting_supplier_id, item_provider_id, occurrence_provider_id
      ).index_by(&:id)
      contractor = suppliers.fetch(@arrangement.contracting_supplier_id)
      item_provider = item_provider_id && suppliers.fetch(item_provider_id)
      occurrence_provider = occurrence_provider_id && suppliers.fetch(occurrence_provider_id)
      ensure_active_effective_provider!(item_provider) if item_provider
      ensure_active_effective_provider!(occurrence_provider) if occurrence_provider

      departure, arrangement, version = lock_departure_arrangement_version!(@arrangement)
      ensure_ordinary_planning_edit!(departure, arrangement, version, contractor)
      occurrence_attrs = occurrence_input && normalize_occurrence_attributes(occurrence_input, departure)
      resource_attrs = resource_input && normalize_resource_attributes(resource_input)
      ensure_active_effective_provider!(occurrence_provider || item_provider || contractor) if occurrence_attrs

      payload = {
        supplier_arrangement_id: arrangement.id,
        supplier_arrangement_version_id: version.id,
        item: item_attrs.merge(default_service_provider_id: item_provider&.id),
        occurrence: occurrence_attrs&.merge(service_provider_id: occurrence_provider&.id),
        resource: resource_attrs
      }
      occurrence = nil
      resource = nil
      result = idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: payload,
        result_class: ArrangementItem
      ) do
        ensure_current_lock_version!(version, @version_lock_version)
        item, item_definition = build_arrangement_item_already_locked!(
          departure: departure, arrangement: arrangement, version: version,
          attributes: item_attrs, provider: item_provider
        )
        occurrence, occurrence_definition = if occurrence_attrs
          build_service_occurrence_already_locked!(
            departure: departure, arrangement: arrangement, version: version, item: item,
            attributes: occurrence_attrs, provider: occurrence_provider
          )
        end
        resource, resource_definition = if resource_attrs
          build_supplier_resource_already_locked!(
            departure: departure, arrangement: arrangement, version: version, item: item,
            attributes: resource_attrs
          )
        end
        bump_version!(version)
        audit!(
          agency: @agency,
          action: "supplier_arrangement.item_setup_created",
          subject: arrangement,
          actor: @actor,
          details: {
            "supplier_arrangement_id" => arrangement.id,
            "supplier_arrangement_version_id" => version.id,
            "arrangement_item_id" => item.id,
            "arrangement_item_definition_id" => item_definition.id,
            "service_occurrence_id" => occurrence&.id,
            "service_occurrence_definition_id" => occurrence_definition&.id,
            "supplier_resource_id" => resource&.id,
            "supplier_resource_definition_id" => resource_definition&.id,
            "default_service_provider_id" => item_provider&.id,
            "service_provider_id" => occurrence_provider&.id
          }
        )
        item
      end

      key = AgencyCommandIdempotencyKey.find_by!(
        agency: @agency,
        command_name: self.class.name,
        idempotency_key: normalize_idempotency_key(@idempotency_key)
      )
      setup_result = if result.status == :created
        ArrangementItemSetupResult.create!(
          agency: @agency,
          agency_command_idempotency_key: key,
          arrangement_item: result.record,
          service_occurrence: occurrence,
          supplier_resource: resource
        )
      else
        ArrangementItemSetupResult.find_by!(agency: @agency, agency_command_idempotency_key: key)
      end

      AgencyCommand::Result.new(
        status: result.status,
        record: SetupResult.new(
          item: setup_result.arrangement_item,
          occurrence: setup_result.service_occurrence,
          resource: setup_result.supplier_resource
        )
      )
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
