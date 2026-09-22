# frozen_string_literal: true

class DetectCruiseArrangementShape
  Result = Data.define(
    :compatible?,
    :version,
    :item,
    :item_definition,
    :occurrence,
    :occurrence_definition,
    :resources,
    :cabin_category_count,
    :summary,
    :reasons
  )

  def initialize(agency:, arrangement:, version: nil)
    @agency = agency
    @arrangement = arrangement
    @version = version
  end

  def call
    arrangement = resolve_arrangement!
    version = resolve_version!(arrangement)
    return incompatible(version, [ "No editable draft or governing version is available." ]) if version.nil?

    item_definitions = association_records(version, :arrangement_item_definitions) do
      version.arrangement_item_definitions.includes(:arrangement_item).order(:position, :id).to_a
    end.sort_by { |definition| [ definition.position, definition.id ] }

    occurrence_definitions = association_records(version, :service_occurrence_definitions) do
      version.service_occurrence_definitions.includes(:service_occurrence).order(:id).to_a
    end.sort_by(&:id)

    resource_definitions = association_records(version, :supplier_resource_definitions) do
      version.supplier_resource_definitions.includes(:supplier_resource).order(:position, :id).to_a
    end.sort_by { |definition| [ definition.position, definition.id ] }

    pool_definitions = association_records(version, :capacity_pool_definitions) do
      version.capacity_pool_definitions.includes(:capacity_pool).to_a
    end

    pair_definitions = association_records(version, :capacity_pair_definitions) do
      version.capacity_pair_definitions.to_a
    end

    reasons = []
    reasons << "Cruise setup requires exactly one Arrangement Item." unless item_definitions.size == 1
    item_definition = item_definitions.first
    if item_definition && item_definition.category != "cruise"
      reasons << "Cruise setup requires the Item category to be cruise."
    end
    reasons << "Cruise setup requires exactly one sailing Occurrence." unless occurrence_definitions.size == 1

    if occurrence_definitions.size == 1 && resource_definitions.any?
      occurrence = occurrence_definitions.first.service_occurrence
      pools_by_resource = pool_definitions.group_by(&:supplier_resource_id)
      resource_definitions.each do |resource_definition|
        resource_id = resource_definition.supplier_resource_id
        matching_pools = pools_by_resource.fetch(resource_id, []).select do |pool|
          pool.service_occurrence_id == occurrence.id
        end
        if matching_pools.size > 1
          reasons << "Cruise setup allows at most one Pool per sailing and cabin category."
          break
        end
        next if matching_pools.empty?

        pool_definition = matching_pools.first
        pool = pool_definition.capacity_pool
        unless pool&.resource_units?
          reasons << "Cruise setup requires cabin inventory measured in resource units."
          break
        end
        unless pool_definition.unit_label.to_s.casecmp("cabins").zero?
          reasons << "Cruise setup requires cabin inventory labeled as cabins."
          break
        end
      end
    end

    if pair_definitions.any? { |pair| !pair.pooled? }
      reasons << "Cruise setup cannot render non-pooled capacity pairs."
    end

    if reasons.any?
      return incompatible(
        version,
        reasons,
        item_definition: item_definition,
        occurrence_definition: occurrence_definitions.first,
        resource_definitions: resource_definitions
      )
    end

    occurrence_definition = occurrence_definitions.first
    Result.new(
      compatible?: true,
      version: version,
      item: item_definition.arrangement_item,
      item_definition: item_definition,
      occurrence: occurrence_definition.service_occurrence,
      occurrence_definition: occurrence_definition,
      resources: resource_definitions.map(&:supplier_resource),
      cabin_category_count: resource_definitions.size,
      summary: summary_for(
        arrangement: arrangement,
        item_definition: item_definition,
        occurrence_definition: occurrence_definition,
        cabin_category_count: resource_definitions.size
      ),
      reasons: []
    )
  end

  private

  def resolve_arrangement!
    if @arrangement.is_a?(SupplierArrangement) && @arrangement.agency_id == @agency.id
      return @arrangement
    end

    @agency.supplier_arrangements.find(@arrangement.id)
  end

  def resolve_version!(arrangement)
    return arrangement.versions.find(@version.id) if @version

    if arrangement.association(:versions).loaded?
      arrangement.versions.find { |version| version.draft? } ||
        arrangement.versions.find { |version| version.id == arrangement.governing_version_id }
    else
      arrangement.versions.find_by(status: "draft") || arrangement.governing_version
    end
  end

  def association_records(version, name)
    association = version.association(name)
    return association.target if association.loaded?

    yield
  end

  def incompatible(version, reasons, item_definition: nil, occurrence_definition: nil, resource_definitions: [])
    Result.new(
      compatible?: false,
      version: version,
      item: item_definition&.arrangement_item,
      item_definition: item_definition,
      occurrence: occurrence_definition&.service_occurrence,
      occurrence_definition: occurrence_definition,
      resources: resource_definitions.map(&:supplier_resource),
      cabin_category_count: resource_definitions.size,
      summary: {
        "compatible" => false,
        "reasons" => reasons
      },
      reasons: reasons
    )
  end

  def summary_for(arrangement:, item_definition:, occurrence_definition:, cabin_category_count:)
    {
      "compatible" => true,
      "arrangement_name" => arrangement.name,
      "contracting_supplier_id" => arrangement.contracting_supplier_id,
      "ship_name" => item_definition.name,
      "sailing_name" => occurrence_definition.name,
      "starts_on" => occurrence_definition.starts_on.iso8601,
      "ends_on" => occurrence_definition.ends_on.iso8601,
      "time_zone" => occurrence_definition.time_zone,
      "cabin_category_count" => cabin_category_count,
      "version_status" => item_definition.supplier_arrangement_version.status
    }
  end
end
