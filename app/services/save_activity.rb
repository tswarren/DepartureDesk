# frozen_string_literal: true

class SaveActivity < AgencyCommand
  include ArrangementCommandSupport

  RATE_LABEL = "Supplier rate per participant"
  RESOURCE_NAME = "Participant"
  POOL_LABEL = "Participant spaces"
  REVIEW_LABEL = "Minimum-enrollment review"
  INCLUSIONS = "Supplier rate includes transportation, guide services, admissions, and taxes. Gratuities are not included."
  CANCELLATION = <<~TEXT.strip
    Before November 1, 2027, the Agency may reduce enrollment or cancel under the stated terms.

    Beginning November 1, 2027, confirmed participation is non-cancellable and non-refundable.
  TEXT
  ADVANCED = ActivityAgreementShape::ADVANCED

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
      if @item && ActivityAgreementShape.structural_reason(version, @item)
        raise Error.new(ADVANCED, code: :invalid_state)
      end
      item = ensure_activity!(arrangement, version)
      sync_details!(arrangement, item) if @item
      version = draft_version!(arrangement)
      sync_capacity!(arrangement, version, item)
      version = draft_version!(arrangement)
      sync_rate!(arrangement, version, item) if rate_minor_units
      version = draft_version!(arrangement)
      sync_threshold!(version, item) if minimum_quantity
      sync_deadlines!(arrangement, version, item) if terms_on.present?
      sync_wording!(version, item, "rate_inclusions", inclusion_wording) if inclusion_wording.present?
      sync_wording!(version, item, "cancellation", cancellation_wording) if cancellation_wording.present?
      version = draft_version!(arrangement)
      sync_payment!(version, item) if terms_on.present? && rate_component(version, item)
      audit!(
        agency: @agency, action: "supplier_arrangement.activity_saved", subject: arrangement, actor: @actor,
        details: {
          "supplier_arrangement_id" => arrangement.id,
          "arrangement_item_id" => item.id,
          "participant_spaces" => spaces
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

  def ensure_activity!(arrangement, version)
    return @item if @item

    CreateArrangementItemSetup.new(
      agency: @agency, actor: @actor, arrangement:,
      version_lock_version: version.lock_version,
      idempotency_key: key("setup"),
      item_attributes: {
        name: @attributes[:name],
        category: "activity_attraction",
        default_service_provider_id: arrangement.contracting_supplier_id
      },
      occurrence_attributes: occurrence_attributes(arrangement),
      resource_attributes: { name: RESOURCE_NAME, maximum_occupancy: nil }
    ).call.record.item
  end

  def sync_details!(arrangement, item)
    version = draft_version!(arrangement)
    item_definition = version.arrangement_item_definitions.find_by!(arrangement_item: item)
    UpdateArrangementItem.new(
      agency: @agency, actor: @actor, definition: item_definition,
      lock_version: item_definition.lock_version,
      attributes: {
        name: @attributes[:name], category: "activity_attraction",
        default_service_provider_id: arrangement.contracting_supplier_id
      }
    ).call
    version = draft_version!(arrangement)
    occurrence = item.service_occurrences.order(:created_at).first
    occurrence_definition = version.service_occurrence_definitions.find_by!(service_occurrence: occurrence)
    UpdateServiceOccurrence.new(
      agency: @agency, actor: @actor, definition: occurrence_definition,
      lock_version: occurrence_definition.lock_version,
      attributes: occurrence_attributes(arrangement)
    ).call
    version = draft_version!(arrangement)
    resource = item.supplier_resources.order(:created_at).first
    resource_definition = version.supplier_resource_definitions.find_by!(supplier_resource: resource)
    UpdateSupplierResource.new(
      agency: @agency, actor: @actor, definition: resource_definition,
      lock_version: resource_definition.lock_version,
      attributes: { name: RESOURCE_NAME, maximum_occupancy: nil }
    ).call
  end

  def sync_capacity!(arrangement, version, item)
    occurrence = item.service_occurrences.order(:created_at).first
    resource = item.supplier_resources.order(:created_at).first
    item_definition = version.arrangement_item_definitions.find_by!(arrangement_item: item)
    SetItemCapacityManagement.new(
      agency: @agency, actor: @actor, definition: item_definition,
      capacity_management: "managed", lock_version: item_definition.lock_version
    ).call
    version = draft_version!(arrangement)
    pool_definition = version.capacity_pool_definitions.find_by(arrangement_item: item)
    attributes = {
      label: POOL_LABEL, unit_label: "participant spaces",
      proposed_opening_quantity: spaces,
      evidence_kind: pool_definition&.evidence_kind || "contract",
      evidence_on: pool_definition&.evidence_on || Date.current,
      evidence_reference_note: pool_definition&.evidence_reference_note || "Activity agreement"
    }
    if pool_definition
      UpdateCapacityPool.new(
        agency: @agency, actor: @actor, definition: pool_definition,
        lock_version: pool_definition.lock_version, attributes:
      ).call
    else
      ConfigureCapacityPairWithPool.new(
        agency: @agency, actor: @actor, item:, service_occurrence: occurrence,
        supplier_resource: resource, version_lock_version: version.lock_version,
        idempotency_key: key("pool"),
        pool_attributes: attributes.merge(inventory_mode: "block", measurement_basis: "traveler_positions")
      ).call
    end
  end

  def sync_rate!(arrangement, version, item)
    component = rate_component(version, item)
    minor = rate_minor_units
    if component
      UpdateSupplierCostComponent.new(
        agency: @agency, actor: @actor, component:, lock_version: component.lock_version,
        attributes: { amount: Money.new(minor, arrangement.departure.operating_currency).format(symbol: false, thousands_separator: false) }
      ).call
      definition = component.supplier_cost_definition.reload
      MarkCostDefinitionForecastReady.new(
        agency: @agency, actor: @actor, definition:, lock_version: definition.lock_version,
        readiness_provenance: "Activity agreement per-participant rate"
      ).call
    else
      occurrence = item.service_occurrences.order(:created_at).first
      resource = item.supplier_resources.order(:created_at).first
      CreateSupplierCostSetup.new(
        agency: @agency, actor: @actor, arrangement:,
        version_lock_version: version.lock_version, idempotency_key: key("cost"),
        source_attributes: {
          charging_supplier_id: arrangement.contracting_supplier_id,
          label: @attributes[:name], arrangement_item_id: item.id,
          service_occurrence_id: occurrence.id, supplier_resource_id: resource.id
        },
        definition_attributes: { stage: "contracted", mode: "calculated", currency: arrangement.departure.operating_currency },
        component_attributes: {
          label: RATE_LABEL, economic_role: "supplier_charge", calculation_kind: "unit_rate",
          quantity_basis: "persons", amount_minor_units: minor, pass_through: false
        },
        assumption_attributes: { expected_persons: expected_persons }
      ).call
    end
    sync_usage!(draft_version!(arrangement), item)
    definition = rate_component(draft_version!(arrangement), item)&.supplier_cost_definition
    return if definition.nil? || definition.forecast_ready?

    MarkCostDefinitionForecastReady.new(
      agency: @agency, actor: @actor, definition: definition.reload, lock_version: definition.lock_version,
      readiness_provenance: "Activity agreement per-participant rate"
    ).call
  end

  def sync_usage!(version, item)
    assumption = version.supplier_cost_usage_assumptions.find_by(arrangement_item: item)
    return if assumption.nil? || expected_persons.nil? || assumption.expected_persons == expected_persons

    UpdateSupplierCostUsageAssumption.new(
      agency: @agency, actor: @actor, assumption:, lock_version: assumption.lock_version,
      attributes: { expected_persons: expected_persons }
    ).call
  end

  def sync_threshold!(version, item)
    occurrence = item.service_occurrences.order(:created_at).first
    existing = version.supplier_operating_threshold_definitions.find_by(arrangement_item: item)
    if existing
      existing.update!(minimum_quantity: minimum_quantity, service_occurrence: occurrence)
      return
    end

    version.supplier_operating_threshold_definitions.create!(
      agency: @agency, departure: @departure, supplier_arrangement: version.supplier_arrangement,
      arrangement_item: item, service_occurrence: occurrence,
      threshold_kind: "minimum_enrollment", quantity_basis: "persons",
      below_threshold_authority: "supplier_decision", minimum_quantity: minimum_quantity,
      position: version.supplier_operating_threshold_definitions.maximum(:position).to_i + 1
    )
  end

  def sync_deadlines!(arrangement, version, item)
    sync_deadline!(arrangement, version, item, "other", REVIEW_LABEL, other_label: REVIEW_LABEL)
    version = draft_version!(arrangement)
    sync_deadline!(arrangement, version, item, "final_count_due", "Final participant count due")
    version = draft_version!(arrangement)
    sync_deadline!(arrangement, version, item, "cancellation_cutoff", "Cancellation cutoff")
  end

  def sync_deadline!(arrangement, version, item, deadline_type, description, other_label: nil)
    existing = ActivityAgreementShape.deadline(version, item, deadline_type)
    attributes = deadline_attributes(item, deadline_type, description, other_label)
    if existing
      return if existing.rule_parameters["date"].to_s == terms_on

      UpdateSupplierDeadlineDefinition.new(
        agency: @agency, actor: @actor, definition: existing, lock_version: existing.lock_version,
        attributes: attributes
      ).call
    else
      CreateSupplierDeadlineDefinition.new(
        agency: @agency, actor: @actor, version:, attributes:,
        version_lock_version: version.lock_version, idempotency_key: key("deadline-#{deadline_type}")
      ).call
    end
  end

  def sync_wording!(version, item, kind, wording)
    existing = version.supplier_agreement_references.find_by(arrangement_item_id: item.id, kind: kind)
    RecordSupplierAgreementReference.new(
      agency: @agency, actor: @actor, kind: kind, scope: "stay", arrangement_item: item,
      supplier_arrangement_version: version, governing_wording: wording,
      source_description: item_name(version, item),
      lock_version: existing&.lock_version, idempotency_key: key("wording-#{kind}")
    ).call
  end

  def sync_payment!(version, item)
    component = rate_component(version, item)
    existing = version.supplier_payment_requirement_definitions.find_by(arrangement_item: item)
    if existing
      existing.update!(due_on: terms_on, supplier_cost_component: component, currency: @departure.operating_currency)
      return
    end

    version.supplier_payment_requirement_definitions.create!(
      agency: @agency, departure: @departure, supplier_arrangement: version.supplier_arrangement,
      arrangement_item: item, supplier_cost_component: component, kind: "full_payment",
      due_on: terms_on, currency: @departure.operating_currency,
      quantity_status: "authoritative_quantity_unavailable",
      position: version.supplier_payment_requirement_definitions.maximum(:position).to_i + 1
    )
  end

  def occurrence_attributes(arrangement)
    {
      name: @attributes[:name],
      starts_on: @attributes[:starts_on],
      ends_on: @attributes[:starts_on],
      starts_at_local: @attributes[:starts_at_local],
      ends_at_local: @attributes[:ends_at_local],
      time_zone: @attributes[:time_zone].presence || "America/Nassau",
      origin_name: @attributes[:location],
      destination_name: @attributes[:location],
      service_provider_id: arrangement.contracting_supplier_id
    }
  end

  def deadline_attributes(item, deadline_type, description, other_label)
    {
      deadline_type: deadline_type, other_label: other_label, kind: "informational",
      rule_shape: "fixed_date", precision: "date_only",
      time_zone: @attributes[:time_zone].presence || "America/Nassau",
      description: description, warning_lead_days: 0, cardinality: "one_shared",
      rule_parameters: { date: terms_on },
      coverage_links: [ { arrangement_item_id: item.id } ],
      commitment_lines: []
    }
  end

  def rate_component(version, item)
    ActivityAgreementShape.sole_component(version, item)
  end

  def item_name(version, item)
    version.arrangement_item_definitions.find_by!(arrangement_item: item).name
  end

  def spaces
    Integer(@attributes.fetch(:participant_spaces))
  end

  def minimum_quantity
    raw = @attributes[:minimum_quantity].presence
    raw && Integer(raw)
  end

  def expected_persons
    raw = @attributes[:expected_persons].presence
    raw && Integer(raw)
  end

  def rate_minor_units
    raw = @attributes[:rate_amount].presence
    return nil if raw.blank?

    Money.from_amount(BigDecimal(raw.to_s), @departure.operating_currency).fractional
  end

  def terms_on
    @attributes[:terms_on].presence
  end

  def inclusion_wording
    @attributes[:inclusion_wording].presence || (rate_minor_units && INCLUSIONS)
  end

  def cancellation_wording
    @attributes[:cancellation_wording].presence || (terms_on.present? && CANCELLATION)
  end

  def draft_version!(arrangement)
    arrangement.versions.find_by!(status: "draft").reload
  end

  def key(suffix)
    "#{normalize_idempotency_key(@idempotency_key)}:#{suffix}"
  end
end
