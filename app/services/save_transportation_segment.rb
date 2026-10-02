# frozen_string_literal: true

class SaveTransportationSegment < AgencyCommand
  include ArrangementCommandSupport

  RATE_LABEL = "Supplier rate per motorcoach"
  POOL_LABEL = "Motorcoaches"
  RESOURCE_NAME = "Motorcoach"
  ADVANCED = "Advanced Supplier planning"

  def initialize(agency:, actor:, departure:, arrangement: nil, item: nil, attributes:, idempotency_key:)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @item = item
    @attributes = attributes.to_h.with_indifferent_access
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    ActiveRecord::Base.transaction do
      arrangement = ensure_arrangement!
      version = draft_version!(arrangement)
      if @item && TransportationAgreementShape.structural_reason(version, @item)
        raise Error.new(ADVANCED, code: :invalid_state)
      end
      item = ensure_segment!(arrangement, version)
      version = draft_version!(arrangement)
      sync_capacity!(arrangement, version, item)
      version = draft_version!(arrangement)
      sync_rate!(arrangement, version, item) if rate_minor_units
      version = draft_version!(arrangement)
      sync_deadline!(arrangement, version, item) if final_count_on.present?
      audit!(
        agency: @agency,
        action: "supplier_arrangement.transportation_segment_saved",
        subject: arrangement,
        actor: @actor,
        details: {
          "supplier_arrangement_id" => arrangement.id,
          "arrangement_item_id" => item.id,
          "confirmed_motorcoaches" => confirmed_count,
          "maximum_total_resource_units" => total_ceiling(version, item)
        }
      )
      item
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def ensure_arrangement!
    return @arrangement if @arrangement

    CreateSupplierArrangement.new(
      agency: @agency, actor: @actor, departure: @departure,
      idempotency_key: key("arrangement"),
      attributes: {
        name: @attributes[:arrangement_name].presence || @attributes[:name],
        contracting_supplier_id: @attributes[:contracting_supplier_id]
      }
    ).call.record
  end

  def ensure_segment!(arrangement, version)
    return @item if @item

    CreateArrangementItemSetup.new(
      agency: @agency, actor: @actor, arrangement:,
      version_lock_version: version.lock_version,
      idempotency_key: key("setup"),
      item_attributes: {
        name: @attributes[:name],
        category: "ground_transportation",
        default_service_provider_id: arrangement.contracting_supplier_id
      },
      occurrence_attributes: occurrence_attributes(arrangement),
      resource_attributes: {
        name: RESOURCE_NAME,
        maximum_occupancy: @attributes[:maximum_occupancy]
      }
    ).call.record.item
  end

  def sync_capacity!(arrangement, version, item)
    occurrence = item.service_occurrences.order(:created_at).first
    resource = item.supplier_resources.order(:created_at).first
    occurrence_definition = version.service_occurrence_definitions.find_by!(service_occurrence: occurrence)
    resource_definition = version.supplier_resource_definitions.find_by!(supplier_resource: resource)
    if @item
      UpdateServiceOccurrence.new(
        agency: @agency, actor: @actor, definition: occurrence_definition,
        lock_version: occurrence_definition.lock_version,
        attributes: occurrence_attributes(arrangement)
      ).call
      version = draft_version!(arrangement)
      resource_definition = version.supplier_resource_definitions.find_by!(supplier_resource: resource)
      UpdateSupplierResource.new(
        agency: @agency, actor: @actor, definition: resource_definition,
        lock_version: resource_definition.lock_version,
        attributes: { name: RESOURCE_NAME, maximum_occupancy: @attributes[:maximum_occupancy] }
      ).call
      version = draft_version!(arrangement)
    end

    item_definition = version.arrangement_item_definitions.find_by!(arrangement_item: item)
    SetItemCapacityManagement.new(
      agency: @agency, actor: @actor, definition: item_definition,
      capacity_management: "managed", lock_version: item_definition.lock_version
    ).call
    version = draft_version!(arrangement)
    pool_definition = version.capacity_pool_definitions.find_by(arrangement_item: item)
    if pool_definition
      UpdateCapacityPool.new(
        agency: @agency, actor: @actor, definition: pool_definition,
        lock_version: pool_definition.lock_version,
        attributes: pool_attributes(pool_definition)
      ).call
    else
      ConfigureCapacityPairWithPool.new(
        agency: @agency, actor: @actor, item:, service_occurrence: occurrence,
        supplier_resource: resource, version_lock_version: version.lock_version,
        idempotency_key: key("pool"),
        pool_attributes: pool_attributes(nil).merge(
          inventory_mode: "block", measurement_basis: "resource_units"
        )
      ).call
    end
    version = draft_version!(arrangement)
    definition = version.capacity_pool_definitions.find_by!(arrangement_item: item)
    ceiling = resolved_ceiling(definition)
    definition.update!(maximum_total_resource_units: ceiling) if definition.maximum_total_resource_units != ceiling
  end

  def sync_rate!(arrangement, version, item)
    component = coach_component(version, item)
    minor = rate_minor_units
    if component
      UpdateSupplierCostComponent.new(
        agency: @agency, actor: @actor, component:,
        lock_version: component.lock_version,
        attributes: { amount: Money.new(minor, arrangement.departure.operating_currency).format(symbol: false, thousands_separator: false) }
      ).call
      definition = component.supplier_cost_definition.reload
      MarkCostDefinitionForecastReady.new(
        agency: @agency, actor: @actor, definition:,
        lock_version: definition.lock_version,
        readiness_provenance: "Transportation agreement per-coach rate"
      ).call
    else
      occurrence = item.service_occurrences.order(:created_at).first
      resource = item.supplier_resources.order(:created_at).first
      created = CreateSupplierCostSetup.new(
        agency: @agency, actor: @actor, arrangement:,
        version_lock_version: version.lock_version,
        idempotency_key: key("cost"),
        source_attributes: {
          charging_supplier_id: arrangement.contracting_supplier_id,
          label: @attributes[:name],
          arrangement_item_id: item.id,
          service_occurrence_id: occurrence.id,
          supplier_resource_id: resource.id
        },
        definition_attributes: { stage: "contracted", mode: "calculated", currency: arrangement.departure.operating_currency },
        component_attributes: {
          label: RATE_LABEL,
          economic_role: "supplier_charge",
          calculation_kind: "unit_rate",
          quantity_basis: "resource_units",
          amount_minor_units: minor,
          pass_through: false
        },
        assumption_attributes: { expected_resource_units: confirmed_count }
      ).call.record
      pool = version.capacity_pool_definitions.find_by!(arrangement_item: item).capacity_pool
      created.update!(quantity_capacity_pool_id: pool.id)
      definition = created.supplier_cost_definition.reload
      MarkCostDefinitionForecastReady.new(
        agency: @agency, actor: @actor, definition:,
        lock_version: definition.lock_version,
        readiness_provenance: "Transportation agreement per-coach rate"
      ).call
    end
    sync_usage!(draft_version!(arrangement), item)
  end

  def sync_usage!(version, item)
    assumption = version.supplier_cost_usage_assumptions.find_by(arrangement_item: item)
    return if assumption.nil?
    return if assumption.expected_resource_units == confirmed_count

    UpdateSupplierCostUsageAssumption.new(
      agency: @agency, actor: @actor, assumption:,
      lock_version: assumption.lock_version,
      attributes: { expected_resource_units: confirmed_count }
    ).call
  end

  def sync_deadline!(arrangement, version, item)
    definition = deadline_for(version, item)
    attributes = deadline_attributes(item)
    if definition
      UpdateSupplierDeadlineDefinition.new(
        agency: @agency, actor: @actor, definition:,
        lock_version: definition.lock_version, attributes:
      ).call
    else
      CreateSupplierDeadlineDefinition.new(
        agency: @agency, actor: @actor, version:,
        version_lock_version: version.lock_version,
        idempotency_key: key("deadline"),
        attributes:
      ).call
    end
  end

  def occurrence_attributes(arrangement)
    {
      name: @attributes[:name],
      starts_on: @attributes[:starts_on],
      ends_on: @attributes[:ends_on].presence || @attributes[:starts_on],
      starts_at_local: @attributes[:starts_at_local],
      ends_at_local: @attributes[:ends_at_local],
      time_zone: @attributes[:time_zone].presence || arrangement.departure.time_zone,
      origin_name: @attributes[:origin_name],
      destination_name: @attributes[:destination_name],
      service_provider_id: arrangement.contracting_supplier_id
    }
  end

  def pool_attributes(definition)
    {
      label: POOL_LABEL,
      unit_label: "motorcoaches",
      proposed_opening_quantity: confirmed_count,
      evidence_kind: definition&.evidence_kind || "contract",
      evidence_on: definition&.evidence_on || Date.current,
      evidence_reference_note: definition&.evidence_reference_note || "Transportation agreement"
    }
  end

  def deadline_attributes(item)
    {
      deadline_type: "final_count_due",
      kind: "actionable",
      rule_shape: "fixed_date",
      precision: "date_only",
      time_zone: @attributes[:time_zone].presence || @departure.time_zone,
      description: "Final passenger and luggage count due",
      warning_lead_days: 0,
      cardinality: "one_shared",
      rule_parameters: { date: final_count_on },
      coverage_links: [ { arrangement_item_id: item.id } ],
      commitment_lines: [ {
        authority_shape: "fixed_quantity",
        committed_supplier_id: item.supplier_arrangement.contracting_supplier_id,
        description: "Final passenger and luggage count",
        fixed_quantity: 1,
        quantity_basis: "resource_units"
      } ]
    }
  end

  def resolved_ceiling(definition)
    explicit = @attributes[:maximum_total_resource_units].presence
    return Integer(explicit) if explicit

    additional = @attributes[:additional_motorcoaches].presence
    return confirmed_count + Integer(additional) if additional
    return definition.maximum_total_resource_units if definition.maximum_total_resource_units

    confirmed_count
  end

  def total_ceiling(version, item)
    version.capacity_pool_definitions.find_by!(arrangement_item: item).maximum_total_resource_units
  end

  def coach_component(version, item)
    version.supplier_cost_components.joins(supplier_cost_definition: :supplier_cost_source)
      .where(supplier_cost_sources: { arrangement_item_id: item.id })
      .where(calculation_kind: "unit_rate", quantity_basis: "resource_units")
      .order(:position).first
  end

  def deadline_for(version, item)
    version.supplier_deadline_definitions.joins(:supplier_deadline_definition_coverage_links)
      .where(deadline_type: "final_count_due")
      .where(supplier_deadline_definition_coverage_links: { arrangement_item_id: item.id })
      .first
  end

  def confirmed_count
    Integer(@attributes.fetch(:confirmed_motorcoaches))
  end

  def rate_minor_units
    raw = @attributes[:rate_amount].presence
    return nil if raw.blank?

    currency = @departure.operating_currency
    Money.from_amount(BigDecimal(raw.to_s), currency).fractional
  end

  def final_count_on
    @attributes[:final_count_on].presence
  end

  def draft_version!(arrangement)
    arrangement.versions.find_by!(status: "draft").reload
  end

  def key(suffix)
    "#{normalize_idempotency_key(@idempotency_key)}:#{suffix}"
  end
end
