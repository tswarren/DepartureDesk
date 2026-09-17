module CapacityGraphHelper
  def create_capacity_supplier(agency, name, reference: nil, status: "active")
    agency.suppliers.create!(
      kind: "organization",
      supplier_reference: reference || "SUP-#{SecureRandom.random_number(900000) + 100000}",
      display_name: name,
      status: status
    )
  end

  def create_capacity_departure(agency, name: "Capacity Departure", status: "draft")
    agency.departures.create!(
      name: name,
      starts_on: Date.new(2026, 6, 1),
      ends_on: Date.new(2026, 6, 8),
      time_zone: "UTC",
      operating_currency: "USD",
      responsible_office: agency.offices.first,
      responsible_agency_user: agency.agency_users.active.first,
      status: status
    )
  end

  def create_capacity_graph(
    agency: @agency,
    departure: @departure,
    contractor: @contractor,
    provider: @provider,
    prefix: "Capacity",
    capacity_management: "managed",
    occurrence_provider: provider,
    item_provider: provider
  )
    arrangement = SupplierArrangement.create!(
      agency: agency,
      departure: departure,
      contracting_supplier: contractor,
      name: "#{prefix} Arrangement",
      status: "draft"
    )
    version = arrangement.versions.create!(
      agency: agency,
      departure: departure,
      version_number: 1,
      status: "draft"
    )
    item = arrangement.arrangement_items.create!(agency: agency, departure: departure)
    item_definition = version.arrangement_item_definitions.create!(
      agency: agency,
      departure: departure,
      supplier_arrangement: arrangement,
      arrangement_item: item,
      name: "#{prefix} item",
      category: "lodging",
      capacity_management: capacity_management,
      default_service_provider: item_provider,
      position: 1
    )
    occurrence = item.service_occurrences.create!(
      agency: agency,
      departure: departure,
      supplier_arrangement: arrangement,
      status: "planned"
    )
    occurrence_definition = version.service_occurrence_definitions.create!(
      agency: agency,
      departure: departure,
      supplier_arrangement: arrangement,
      arrangement_item: item,
      service_occurrence: occurrence,
      name: "#{prefix} occurrence",
      starts_on: Date.new(2026, 6, 1),
      ends_on: Date.new(2026, 6, 1),
      time_zone: "America/New_York",
      service_provider: occurrence_provider
    )
    resource = item.supplier_resources.create!(
      agency: agency,
      departure: departure,
      supplier_arrangement: arrangement
    )
    resource_definition = version.supplier_resource_definitions.create!(
      agency: agency,
      departure: departure,
      supplier_arrangement: arrangement,
      arrangement_item: item,
      supplier_resource: resource,
      name: "#{prefix} resource",
      position: 1
    )

    {
      arrangement: arrangement,
      version: version,
      item: item,
      item_definition: item_definition,
      occurrence: occurrence,
      occurrence_definition: occurrence_definition,
      resource: resource,
      resource_definition: resource_definition
    }
  end

  def classify_capacity_graph_pair(graph, classification: "pooled")
    CapacityPairDefinition.create!(
      agency: graph[:arrangement].agency,
      departure: graph[:departure] || graph[:arrangement].departure,
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      arrangement_item: graph[:item],
      service_occurrence: graph[:occurrence],
      supplier_resource: graph[:resource],
      classification: classification
    )
  end
end
