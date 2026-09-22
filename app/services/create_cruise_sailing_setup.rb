# frozen_string_literal: true

class CreateCruiseSailingSetup < AgencyCommand
  include ArrangementCommandSupport

  SetupResult = Data.define(:arrangement, :item, :occurrence)

  def initialize(agency:, actor:, departure:, arrangement_attributes:, item_attributes:,
    occurrence_attributes:, idempotency_key:)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement_attributes = arrangement_attributes.to_h.with_indifferent_access
    @item_attributes = item_attributes.to_h.with_indifferent_access
    @occurrence_attributes = occurrence_attributes.to_h.with_indifferent_access
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    arrangement_name = normalize_arrangement_name(@arrangement_attributes[:name])
    item_attrs = normalize_item_attributes(
      @item_attributes.merge(category: "cruise", other_category_label: nil)
    ).merge(capacity_management: "managed")
    item_provider_id = parse_optional_uuid(
      @item_attributes[:default_service_provider_id],
      "Default service provider"
    )
    occurrence_provider_id = parse_optional_uuid(
      @occurrence_attributes[:service_provider_id],
      "Service provider"
    )

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      contractor = resolve_active_supplier!(
        @arrangement_attributes[:contracting_supplier_id],
        "Contracting supplier"
      )
      contact = resolve_optional_contact!(contractor, @arrangement_attributes[:supplier_contact_id])
      suppliers = lock_suppliers_in_uuid_order!(
        contractor.id, item_provider_id, occurrence_provider_id
      ).index_by(&:id)
      item_provider = item_provider_id && suppliers.fetch(item_provider_id)
      occurrence_provider = occurrence_provider_id && suppliers.fetch(occurrence_provider_id)
      ensure_active_effective_provider!(item_provider) if item_provider
      ensure_active_effective_provider!(occurrence_provider) if occurrence_provider

      departure = lock_departure_for!(@departure)
      ensure_departure_accepts_new_planning!(departure)
      occurrence_attrs = normalize_occurrence_attributes(@occurrence_attributes, departure)
      ensure_active_effective_provider!(occurrence_provider || item_provider || contractor)

      payload = {
        departure_id: departure.id,
        name: arrangement_name,
        contracting_supplier_id: contractor.id,
        supplier_contact_id: contact&.id,
        item: item_attrs.merge(default_service_provider_id: item_provider&.id),
        occurrence: occurrence_attrs.merge(service_provider_id: occurrence_provider&.id)
      }

      result = idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: payload,
        result_class: SupplierArrangement
      ) do
        arrangement, version = build_supplier_arrangement_already_locked!(
          departure: departure,
          contractor: contractor,
          contact: contact,
          name: arrangement_name
        )
        item, item_definition = build_arrangement_item_already_locked!(
          departure: departure,
          arrangement: arrangement,
          version: version,
          attributes: item_attrs,
          provider: item_provider
        )
        occurrence, occurrence_definition = build_service_occurrence_already_locked!(
          departure: departure,
          arrangement: arrangement,
          version: version,
          item: item,
          attributes: occurrence_attrs,
          provider: occurrence_provider
        )
        audit!(
          agency: @agency,
          action: "supplier_arrangement.created",
          subject: arrangement,
          actor: @actor,
          details: {
            "supplier_arrangement_id" => arrangement.id,
            "supplier_arrangement_version_id" => version.id,
            "departure_id" => departure.id,
            "contracting_supplier_id" => contractor.id,
            "supplier_contact_id" => contact&.id,
            "name" => arrangement.name
          }
        )
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
            "service_occurrence_id" => occurrence.id,
            "service_occurrence_definition_id" => occurrence_definition.id,
            "supplier_resource_id" => nil,
            "supplier_resource_definition_id" => nil,
            "default_service_provider_id" => item_provider&.id,
            "service_provider_id" => occurrence_provider&.id
          }
        )
        arrangement
      end

      AgencyCommand::Result.new(
        status: result.status,
        record: setup_result_for(result.record)
      )
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def setup_result_for(arrangement)
    item = arrangement.arrangement_items.sole
    occurrence = item.service_occurrences.sole
    SetupResult.new(
      arrangement: arrangement,
      item: item,
      occurrence: occurrence
    )
  end
end
