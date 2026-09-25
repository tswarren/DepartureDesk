# frozen_string_literal: true

module TypedItemWrite
  extend ActiveSupport::Concern

  include ArrangementCommandSupport

  Setup = Data.define(:arrangement, :item, :occurrence, :resource)

  private

  def establish_typed_item!(
    departure:, category:, capacity_management:, arrangement_attributes:, item_attributes:,
    occurrence_attributes:, idempotency_key:, arrangement: nil, resource_attributes: nil,
    version_lock_version: nil
  )
    ensure_arrangement_actor!
    item_attrs = normalize_item_attributes(
      item_attributes.merge(category: category, other_category_label: nil)
    ).merge(capacity_management: capacity_management)
    item_provider_id = parse_optional_uuid(item_attributes[:default_service_provider_id], "Default service provider")
    occurrence_provider_id = parse_optional_uuid(occurrence_attributes[:service_provider_id], "Service provider")
    resource_attrs = resource_attributes.present? ? normalize_resource_attributes(resource_attributes) : nil

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      if arrangement
        add_typed_item!(
          arrangement: arrangement, departure: departure, item_attrs: item_attrs,
          item_provider_id: item_provider_id, occurrence_provider_id: occurrence_provider_id,
          occurrence_attributes: occurrence_attributes, resource_attrs: resource_attrs,
          idempotency_key: idempotency_key, version_lock_version: version_lock_version
        )
      else
        create_typed_shell!(
          departure: departure, arrangement_attributes: arrangement_attributes, item_attrs: item_attrs,
          item_provider_id: item_provider_id, occurrence_provider_id: occurrence_provider_id,
          occurrence_attributes: occurrence_attributes, resource_attrs: resource_attrs,
          idempotency_key: idempotency_key
        )
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  def create_typed_shell!(
    departure:, arrangement_attributes:, item_attrs:, item_provider_id:, occurrence_provider_id:,
    occurrence_attributes:, resource_attrs:, idempotency_key:
  )
    arrangement_name = normalize_arrangement_name(arrangement_attributes[:name])
    contractor = resolve_active_supplier!(arrangement_attributes[:contracting_supplier_id], "Contracting supplier")
    contact = resolve_optional_contact!(contractor, arrangement_attributes[:supplier_contact_id])
    suppliers = lock_suppliers_in_uuid_order!(contractor.id, item_provider_id, occurrence_provider_id).index_by(&:id)
    item_provider = item_provider_id && suppliers.fetch(item_provider_id)
    occurrence_provider = occurrence_provider_id && suppliers.fetch(occurrence_provider_id)
    ensure_active_effective_provider!(item_provider) if item_provider
    ensure_active_effective_provider!(occurrence_provider) if occurrence_provider
    departure = lock_departure_for!(departure)
    ensure_departure_accepts_new_planning!(departure)
    occurrence_attrs = normalize_occurrence_attributes(occurrence_attributes, departure)
    ensure_active_effective_provider!(occurrence_provider || item_provider || contractor)
    payload = {
      departure_id: departure.id, name: arrangement_name, contracting_supplier_id: contractor.id,
      supplier_contact_id: contact&.id, item: item_attrs.merge(default_service_provider_id: item_provider&.id),
      occurrence: occurrence_attrs.merge(service_provider_id: occurrence_provider&.id),
      resource: resource_attrs
    }
    result = idempotent_create!(
      command_name: self.class.name, idempotency_key: idempotency_key, payload: payload,
      result_class: SupplierArrangement
    ) do
      arrangement, version = build_supplier_arrangement_already_locked!(
        departure: departure, contractor: contractor, contact: contact, name: arrangement_name
      )
      item, occurrence, resource = write_item_graph!(
        departure: departure, arrangement: arrangement, version: version, item_attrs: item_attrs,
        item_provider: item_provider, occurrence_attrs: occurrence_attrs,
        occurrence_provider: occurrence_provider, resource_attrs: resource_attrs
      )
      audit!(
        agency: @agency, action: "supplier_arrangement.created", subject: arrangement, actor: @actor,
        details: {
          "supplier_arrangement_id" => arrangement.id, "supplier_arrangement_version_id" => version.id,
          "departure_id" => departure.id, "contracting_supplier_id" => contractor.id,
          "supplier_contact_id" => contact&.id, "name" => arrangement.name
        }
      )
      audit_typed_item!(arrangement, version, item, occurrence, resource)
      arrangement
    end
    setup_from_arrangement(result)
  end

  def add_typed_item!(
    arrangement:, departure:, item_attrs:, item_provider_id:, occurrence_provider_id:,
    occurrence_attributes:, resource_attrs:, idempotency_key:, version_lock_version:
  )
    arrangement = lock_arrangement_for!(arrangement)
    version = arrangement.versions.find_by(status: "draft")
    unless version
      raise AgencyCommand::Error.new("Open a successor draft before changing this arrangement.", code: :invalid_state)
    end
    departure = lock_departure_for!(departure || arrangement.departure)
    ensure_departure_accepts_new_planning!(departure)
    suppliers = lock_suppliers_in_uuid_order!(
      arrangement.contracting_supplier_id, item_provider_id, occurrence_provider_id
    ).index_by(&:id)
    item_provider = item_provider_id && suppliers.fetch(item_provider_id)
    occurrence_provider = occurrence_provider_id && suppliers.fetch(occurrence_provider_id)
    ensure_active_effective_provider!(item_provider) if item_provider
    ensure_active_effective_provider!(occurrence_provider) if occurrence_provider
    occurrence_attrs = normalize_occurrence_attributes(occurrence_attributes, departure)
    payload = {
      supplier_arrangement_id: arrangement.id, supplier_arrangement_version_id: version.id,
      item: item_attrs.merge(default_service_provider_id: item_provider&.id),
      occurrence: occurrence_attrs.merge(service_provider_id: occurrence_provider&.id),
      resource: resource_attrs
    }
    result = idempotent_create!(
      command_name: self.class.name, idempotency_key: idempotency_key, payload: payload,
      result_class: ArrangementItem
    ) do
      ensure_current_lock_version!(version, version_lock_version)
      item, occurrence, resource = write_item_graph!(
        departure: departure, arrangement: arrangement, version: version, item_attrs: item_attrs,
        item_provider: item_provider, occurrence_attrs: occurrence_attrs,
        occurrence_provider: occurrence_provider, resource_attrs: resource_attrs
      )
      bump_version!(version)
      audit_typed_item!(arrangement, version, item, occurrence, resource)
      item
    end
    AgencyCommand::Result.new(status: result.status, record: setup_from_item(result.record, arrangement))
  end

  def write_item_graph!(
    departure:, arrangement:, version:, item_attrs:, item_provider:, occurrence_attrs:,
    occurrence_provider:, resource_attrs:
  )
    item, = build_arrangement_item_already_locked!(
      departure: departure, arrangement: arrangement, version: version, attributes: item_attrs, provider: item_provider
    )
    occurrence, = build_service_occurrence_already_locked!(
      departure: departure, arrangement: arrangement, version: version, item: item,
      attributes: occurrence_attrs, provider: occurrence_provider
    )
    resource = nil
    if resource_attrs
      resource, = build_supplier_resource_already_locked!(
        departure: departure, arrangement: arrangement, version: version, item: item, attributes: resource_attrs
      )
    end
    [ item, occurrence, resource ]
  end

  def audit_typed_item!(arrangement, version, item, occurrence, resource)
    audit!(
      agency: @agency, action: "supplier_arrangement.typed_item_setup", subject: arrangement, actor: @actor,
      details: {
        "supplier_arrangement_id" => arrangement.id,
        "supplier_arrangement_version_id" => version.id,
        "arrangement_item_id" => item.id,
        "service_occurrence_id" => occurrence.id,
        "supplier_resource_id" => resource&.id
      }
    )
  end

  def setup_from_arrangement(result)
    arrangement = result.record
    item = arrangement.arrangement_items.order(:created_at).last
    AgencyCommand::Result.new(
      status: result.status,
      record: Setup.new(
        arrangement: arrangement, item: item,
        occurrence: item.service_occurrences.order(:created_at).last,
        resource: item.supplier_resources.order(:created_at).last
      )
    )
  end

  def setup_from_item(item, arrangement)
    Setup.new(
      arrangement: arrangement, item: item,
      occurrence: item.service_occurrences.order(:created_at).last,
      resource: item.supplier_resources.order(:created_at).last
    )
  end
end
