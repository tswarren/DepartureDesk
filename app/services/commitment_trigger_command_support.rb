module CommitmentTriggerCommandSupport
  extend ActiveSupport::Concern

  include ArrangementCommandSupport

  private

  def lock_trigger_graph!
    arrangement = @agency.supplier_arrangements.find(
      @version.is_a?(SupplierArrangementVersion) ? @version.supplier_arrangement_id : @arrangement.id
    )
    departure = lock_departure_for!(arrangement.departure_id)
    arrangement = lock_arrangement_for!(arrangement)
    version_id = @version.is_a?(SupplierArrangementVersion) ? @version.id : @version
    version = arrangement.versions.lock.find(version_id)
    contractor = lock_suppliers_in_uuid_order!(arrangement.contracting_supplier_id).first
    [ departure, arrangement, version, contractor ]
  end

  def ensure_trigger_editable!(departure, arrangement, version, contractor)
    unless version.draft? && (departure.draft? || departure.active?) &&
        !arrangement.abandoned? && contractor.active?
      raise AgencyCommand::Error.new(
        "That Arrangement version cannot edit commitment triggers.", code: :invalid_state
      )
    end
  end

  def normalize_trigger_attributes(version, arrangement, attributes)
    attrs = attributes.to_h.with_indifferent_access
    shape = attrs[:authority_shape].to_s
    trigger_kind = attrs[:trigger_kind].to_s
    unless SupplierCommitmentTriggerDefinition::AUTHORITY_SHAPES.include?(shape) &&
        SupplierCommitmentTriggerDefinition::TRIGGER_KINDS.include?(trigger_kind)
      raise AgencyCommand::Error.new("Choose a valid trigger and authority shape.", code: :invalid)
    end

    committed_supplier = resolve_active_supplier!(attrs[:committed_supplier_id], "Committed supplier")
    context = resolve_trigger_context(version, attrs)
    monetary = resolve_trigger_monetary_authority(version, shape, attrs)
    eligible = eligible_trigger_supplier_ids(arrangement, version, context, monetary)
    unless eligible.include?(committed_supplier.id)
      raise AgencyCommand::Error.new(
        "The committed supplier is not eligible for this trigger scope and authority.", code: :invalid
      )
    end

    {
      trigger_kind:,
      authority_shape: shape,
      committed_supplier_id: committed_supplier.id,
      description: normalize_trigger_text(attrs[:description]),
      fixed_quantity: shape == "fixed_quantity" ? positive_trigger_integer(attrs[:fixed_quantity]) : nil,
      quantity_basis: quantity_shape?(shape) ? normalize_trigger_basis(attrs[:quantity_basis]) : nil,
      currency: monetary[:currency],
      supplier_cost_source_id: monetary[:source]&.id,
      supplier_cost_definition_id: monetary[:definition]&.id,
      supplier_cost_component_id: monetary[:component]&.id
    }.merge(context.transform_values { |record| record&.id })
  end

  def resolve_trigger_context(version, attrs)
    item_id = parse_optional_uuid(attrs[:arrangement_item_id], "Item")
    occurrence_id = parse_optional_uuid(attrs[:service_occurrence_id], "Occurrence")
    resource_id = parse_optional_uuid(attrs[:supplier_resource_id], "Resource")
    pool_id = parse_optional_uuid(attrs[:capacity_pool_id], "Capacity Pool")
    item = item_id && version.arrangement_item_definitions.find_by!(arrangement_item_id: item_id).arrangement_item
    occurrence = occurrence_id && version.service_occurrence_definitions
      .find_by!(arrangement_item_id: item_id, service_occurrence_id: occurrence_id).service_occurrence
    resource = resource_id && version.supplier_resource_definitions
      .find_by!(arrangement_item_id: item_id, supplier_resource_id: resource_id).supplier_resource
    pool = pool_id && version.capacity_pool_definitions
      .find_by!(
        arrangement_item_id: item_id, service_occurrence_id: occurrence_id,
        supplier_resource_id: resource_id, capacity_pool_id: pool_id
      ).capacity_pool
    { arrangement_item: item, service_occurrence: occurrence, supplier_resource: resource, capacity_pool: pool }
  end

  def resolve_trigger_monetary_authority(version, shape, attrs)
    unless %w[fixed_contracted_amount contracted_unit_rate_times_confirmed_quantity].include?(shape)
      currency = shape == "confirmed_amount" ? version.departure.operating_currency : nil
      return { source: nil, definition: nil, component: nil, currency: }
    end

    component_id = required_uuid(attrs[:supplier_cost_component_id], "Contracted cost component")
    component = version.supplier_cost_components.includes(
      supplier_cost_definition: :supplier_cost_source
    ).find(component_id)
    definition = component.supplier_cost_definition
    source = definition.supplier_cost_source
    valid_kind = shape == "fixed_contracted_amount" ? component.fixed? : component.unit_rate?
    unless definition.contracted? && definition.forecast_ready? &&
        component.supplier_charge? && valid_kind
      raise AgencyCommand::Error.new(
        "Choose a ready contracted Supplier-charge component with the required calculation kind.",
        code: :invalid
      )
    end
    { source:, definition:, component:, currency: definition.currency }
  end

  def eligible_trigger_supplier_ids(arrangement, version, context, monetary)
    ids = [ arrangement.contracting_supplier_id ]
    if context[:arrangement_item]
      item_definition = version.arrangement_item_definitions.find_by!(
        arrangement_item: context[:arrangement_item]
      )
      ids << item_definition.default_service_provider_id
      if context[:service_occurrence]
        ids << version.service_occurrence_definitions.find_by!(
          service_occurrence: context[:service_occurrence]
        ).service_provider_id
      end
    end
    ids << monetary[:source]&.charging_supplier_id
    ids.compact.uniq
  end

  def normalize_trigger_text(value)
    text = value.to_s.strip
    if text.blank? || text.length > SupplierCommitmentTriggerDefinition::DESCRIPTION_LIMIT
      raise AgencyCommand::Error.new("Enter a description of 500 characters or fewer.", code: :invalid)
    end
    text
  end

  def positive_trigger_integer(value)
    number = Integer(value)
    raise ArgumentError unless number.positive?
    number
  rescue ArgumentError, TypeError
    raise AgencyCommand::Error.new("Fixed quantity must be a positive whole number.", code: :invalid)
  end

  def normalize_trigger_basis(value)
    basis = value.to_s
    return basis if SupplierCommitmentTriggerDefinition::QUANTITY_BASES.include?(basis)

    raise AgencyCommand::Error.new("Choose a valid quantity basis.", code: :invalid)
  end

  def quantity_shape?(shape)
    %w[fixed_quantity confirmed_quantity contracted_unit_rate_times_confirmed_quantity].include?(shape)
  end

  def trigger_details(trigger)
    {
      "supplier_commitment_trigger_definition_id" => trigger.id,
      "supplier_arrangement_version_id" => trigger.supplier_arrangement_version_id,
      "trigger_kind" => trigger.trigger_kind,
      "authority_shape" => trigger.authority_shape,
      "committed_supplier_id" => trigger.committed_supplier_id
    }
  end
end
