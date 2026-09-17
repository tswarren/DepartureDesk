module CostCommandSupport
  extend ActiveSupport::Concern

  include ArrangementCommandSupport

  COMPONENT_FIELDS = SupplierCostDefinitionFingerprint::COMPONENT_FIELDS
  READINESS_FIELDS = {
    status: "working", forecast_ready_by_id: nil, forecast_ready_at: nil,
    readiness_provenance: nil, readiness_fingerprint: nil
  }.freeze

  private

  def cost_graph!(owner, extra_supplier_ids: [])
    arrangement_id = owner.is_a?(SupplierArrangement) ? owner.id : owner.supplier_arrangement_id
    arrangement = @agency.supplier_arrangements.find(arrangement_id)
    version = arrangement.versions.find_by!(status: "draft")
    supplier_ids = version.supplier_cost_sources.distinct.pluck(:charging_supplier_id) + Array(extra_supplier_ids)
    suppliers = lock_suppliers_in_uuid_order!(arrangement.contracting_supplier_id, supplier_ids).index_by(&:id)
    contractor = suppliers.fetch(arrangement.contracting_supplier_id)
    departure, arrangement, version = lock_departure_arrangement_version!(arrangement)
    [ departure, arrangement, version, contractor ]
  end

  def ensure_cost_ordinary_edit!(departure, arrangement, version, contractor, charging_supplier = nil)
    ensure_draft_graph!(arrangement, version)
    return if ordinary_planning_state?(departure, contractor) &&
      (charging_supplier.nil? || charging_supplier.active?)

    raise AgencyCommand::Error.new(recovery_message, code: :invalid_state)
  end

  def ensure_cost_cleanup_edit!(departure, arrangement, version)
    ensure_draft_graph!(arrangement, version)
    return if departure.draft? || departure.active? || departure.departed?

    raise AgencyCommand::Error.new("That departure cannot be edited.", code: :invalid_state)
  end

  def lock_source!(version, source)
    version.supplier_cost_sources.lock.find(source.is_a?(SupplierCostSource) ? source.id : source)
  end

  def lock_definition!(source, definition)
    source.supplier_cost_definitions.lock.find(definition.is_a?(SupplierCostDefinition) ? definition.id : definition)
  end

  def lock_component!(definition, component)
    definition.supplier_cost_components.lock.find(component.is_a?(SupplierCostComponent) ? component.id : component)
  end

  def lock_item_cost_context!(arrangement, version, item:, occurrence: nil, resource: nil)
    return [ nil, nil, nil ] if item.blank?

    item = arrangement.arrangement_items.lock.find(item.is_a?(ArrangementItem) ? item.id : item)
    version.arrangement_item_definitions.lock.find_by!(arrangement_item: item)
    occurrence = occurrence.presence
    resource = resource.presence
    occurrence = item.service_occurrences.lock.find(occurrence.is_a?(ServiceOccurrence) ? occurrence.id : occurrence) if occurrence
    resource = item.supplier_resources.lock.find(resource.is_a?(SupplierResource) ? resource.id : resource) if resource
    version.service_occurrence_definitions.lock.find_by!(arrangement_item: item, service_occurrence: occurrence) if occurrence
    version.supplier_resource_definitions.lock.find_by!(arrangement_item: item, supplier_resource: resource) if resource
    [ item, occurrence, resource ]
  end

  def eligible_charging_supplier_id(arrangement, version, item, occurrence)
    return arrangement.contracting_supplier_id unless item

    item_definition = version.arrangement_item_definitions.find_by!(arrangement_item: item)
    return item_definition.default_service_provider_id || arrangement.contracting_supplier_id unless occurrence

    occurrence_definition = version.service_occurrence_definitions.find_by!(
      arrangement_item: item, service_occurrence: occurrence
    )
    occurrence_definition.service_provider_id ||
      item_definition.default_service_provider_id ||
      arrangement.contracting_supplier_id
  end

  def ensure_eligible_charging_supplier!(arrangement, version, item, occurrence, supplier)
    eligible = [ arrangement.contracting_supplier_id ]
    if item
      item_definition = version.arrangement_item_definitions.find_by!(arrangement_item: item)
      eligible << item_definition.default_service_provider_id
      if occurrence
        eligible << version.service_occurrence_definitions.find_by!(
          arrangement_item: item, service_occurrence: occurrence
        ).service_provider_id
      end
    end
    unless eligible.compact.include?(supplier.id) && (item.present? || supplier.id == arrangement.contracting_supplier_id)
      raise AgencyCommand::Error.new("That supplier is not eligible to charge for this cost context.", code: :invalid)
    end
  end

  def source_context(source)
    {
      "arrangement_item_id" => source.arrangement_item_id,
      "service_occurrence_id" => source.service_occurrence_id,
      "supplier_resource_id" => source.supplier_resource_id
    }
  end

  def normalize_text(value, label, limit, required: true)
    text = value.to_s.strip.presence
    raise AgencyCommand::Error.new("Enter #{label.downcase}.", code: :invalid) if required && text.blank?
    raise AgencyCommand::Error.new("#{label} must be #{limit} characters or fewer.", code: :invalid) if text&.length.to_i > limit
    text
  end

  def normalize_currency(value, departure)
    currency = value.to_s.strip.upcase
    Money::Currency.find(currency)
    raise AgencyCommand::Error.new("Currency must equal the departure operating currency.", code: :invalid) unless currency == departure.operating_currency
    currency
  rescue Money::Currency::UnknownCurrency
    raise AgencyCommand::Error.new("Choose a supported currency.", code: :invalid)
  end

  def normalize_definition_attributes(attributes, departure)
    attrs = attributes.to_h.with_indifferent_access
    mode = attrs[:mode].to_s
    raise AgencyCommand::Error.new("Choose a valid cost mode.", code: :invalid) unless SupplierCostDefinition::MODES.include?(mode)
    rounding = (attrs[:rounding_mode].presence || "half_up").to_s
    raise AgencyCommand::Error.new("Choose a valid rounding mode.", code: :invalid) unless SupplierCostDefinition::ROUNDING_MODES.include?(rounding)
    {
      mode: mode,
      currency: normalize_currency(attrs[:currency] || departure.operating_currency, departure),
      rounding_mode: rounding,
      zero_cost_reason: normalize_text(
        attrs[:zero_cost_reason], "Zero-cost reason", SupplierCostDefinition::ZERO_COST_REASON_LIMIT,
        required: mode == "zero_cost"
      )
    }.tap { |result| result[:zero_cost_reason] = nil unless mode == "zero_cost" }
  end

  def integer_or_nil(value, label, minimum: 0)
    return nil if value.nil? || value == ""
    integer = Integer(value)
    raise AgencyCommand::Error.new("#{label} is invalid.", code: :invalid) if integer < minimum
    integer
  rescue ArgumentError, TypeError
    raise AgencyCommand::Error.new("#{label} is invalid.", code: :invalid)
  end

  def decimal_or_nil(value, label)
    return nil if value.nil? || value == ""
    BigDecimal(value.to_s).tap { |number| raise AgencyCommand::Error.new("#{label} is invalid.", code: :invalid) if number.negative? }
  rescue ArgumentError
    raise AgencyCommand::Error.new("#{label} is invalid.", code: :invalid)
  end

  def normalize_component_attributes(attributes, version:, item:, currency: nil)
    attrs = attributes.to_h.with_indifferent_access
    category_id = parse_optional_uuid(attrs[:participant_category_id], "Participant category")
    if category_id
      raise AgencyCommand::Error.new("Arrangement-wide costs cannot use participant categories.", code: :invalid) unless item
      version.supplier_cost_participant_categories.find_by!(id: category_id, arrangement_item_id: item.id)
    end
    kind = attrs[:calculation_kind].to_s
    unless SupplierCostComponent::CALCULATION_KINDS.include?(kind)
      raise AgencyCommand::Error.new("Calculation kind is invalid.", code: :invalid)
    end
    economic_role = attrs[:economic_role].to_s
    unless SupplierCostComponent::ECONOMIC_ROLES.include?(economic_role)
      raise AgencyCommand::Error.new("Economic role is invalid.", code: :invalid)
    end
    currency_code = currency.presence || version.departure.operating_currency
    normalized = apply_component_kind_shape({
      label: normalize_text(attrs[:label], "Label", SupplierCostComponent::LABEL_LIMIT),
      economic_role: economic_role,
      calculation_kind: kind,
      amount_minor_units: money_minor_or_nil(
        attrs.key?(:amount) ? attrs[:amount] : attrs[:amount_minor_units],
        currency_code, "Amount", major_units: attrs.key?(:amount)
      ),
      rate: normalize_component_rate(attrs),
      minimum_minor_units: money_minor_or_nil(
        attrs.key?(:minimum_amount) ? attrs[:minimum_amount] : attrs[:minimum_minor_units],
        currency_code, "Minimum amount", major_units: attrs.key?(:minimum_amount)
      ),
      minimum_quantity: integer_or_nil(attrs[:minimum_quantity], "Minimum quantity", minimum: 1),
      quantity_basis: attrs[:quantity_basis].presence&.to_s,
      participant_category_id: category_id,
      occupancy_position_from: integer_or_nil(attrs[:occupancy_position_from], "Starting occupancy position", minimum: 1),
      occupancy_position_to: integer_or_nil(attrs[:occupancy_position_to], "Ending occupancy position", minimum: 1),
      percentage_treatment: attrs[:percentage_treatment].presence&.to_s,
      pass_through: ActiveModel::Type::Boolean.new.cast(attrs[:pass_through])
    })
    if item.nil? && (normalized[:quantity_basis].present? || normalized[:participant_category_id].present? ||
        normalized[:occupancy_position_from].present? || normalized[:occupancy_position_to].present? ||
        normalized[:calculation_kind] == "minimum_quantity_shortfall")
      raise AgencyCommand::Error.new("Arrangement-wide costs cannot use quantity inputs.", code: :invalid)
    end
    normalized
  end

  def normalize_component_rate(attrs)
    if attrs.key?(:percentage)
      percent = decimal_or_nil(attrs[:percentage], "Percentage")
      return percent && (percent / 100)
    end

    decimal_or_nil(attrs[:rate], "Rate")
  end

  def money_minor_or_nil(value, currency_code, label, major_units: false)
    return nil if value.nil? || value == ""
    return integer_or_nil(value, label) unless major_units

    currency = Money::Currency.find(currency_code)
    raise AgencyCommand::Error.new("#{label} is invalid.", code: :invalid) unless currency

    Money.from_amount(BigDecimal(value.to_s), currency.iso_code).fractional.tap do |minor|
      raise AgencyCommand::Error.new("#{label} is invalid.", code: :invalid) if minor.negative?
    end
  rescue ArgumentError, TypeError, Money::Currency::UnknownCurrency
    raise AgencyCommand::Error.new("#{label} is invalid.", code: :invalid)
  end

  # Shared forms may post blank unused fields. Nonblank fields forbidden by the
  # selected calculation kind are rejected as invalid rather than silently cleared.
  def apply_component_kind_shape(attrs)
    kind = attrs[:calculation_kind]
    quantity_basis = attrs[:quantity_basis]
    if quantity_basis.present? && !SupplierCostComponent::QUANTITY_BASES.include?(quantity_basis)
      raise AgencyCommand::Error.new("Quantity basis is invalid.", code: :invalid)
    end
    treatment = attrs[:percentage_treatment]
    if treatment.present? && !SupplierCostComponent::PERCENTAGE_TREATMENTS.include?(treatment)
      raise AgencyCommand::Error.new("Percentage treatment is invalid.", code: :invalid)
    end

    allowed = case kind
    when "fixed"
      require_component_value!(attrs[:amount_minor_units], "Amount")
      reject_forbidden_component_fields!(attrs, %i[
        rate minimum_minor_units minimum_quantity quantity_basis participant_category_id
        occupancy_position_from occupancy_position_to percentage_treatment
      ])
      { amount_minor_units: attrs[:amount_minor_units] }
    when "unit_rate"
      require_component_value!(attrs[:amount_minor_units], "Amount")
      require_component_value!(quantity_basis, "Quantity basis")
      reject_forbidden_component_fields!(attrs, %i[rate minimum_minor_units minimum_quantity percentage_treatment])
      {
        amount_minor_units: attrs[:amount_minor_units], quantity_basis: quantity_basis,
        participant_category_id: attrs[:participant_category_id],
        occupancy_position_from: attrs[:occupancy_position_from],
        occupancy_position_to: attrs[:occupancy_position_to]
      }
    when "percentage"
      require_component_value!(attrs[:rate], "Rate")
      require_component_value!(treatment, "Percentage treatment")
      reject_forbidden_component_fields!(attrs, %i[
        amount_minor_units minimum_minor_units minimum_quantity quantity_basis
        participant_category_id occupancy_position_from occupancy_position_to
      ])
      { rate: attrs[:rate], percentage_treatment: treatment }
    when "minimum_amount_shortfall"
      require_component_value!(attrs[:minimum_minor_units], "Minimum amount")
      unless attrs[:economic_role] == "supplier_charge"
        raise AgencyCommand::Error.new("Minimum amount shortfalls must use the supplier charge role.", code: :invalid)
      end
      reject_forbidden_component_fields!(attrs, %i[
        amount_minor_units rate minimum_quantity quantity_basis participant_category_id
        occupancy_position_from occupancy_position_to percentage_treatment
      ])
      { minimum_minor_units: attrs[:minimum_minor_units] }
    when "minimum_quantity_shortfall"
      require_component_value!(attrs[:minimum_quantity], "Minimum quantity")
      require_component_value!(quantity_basis, "Quantity basis")
      unless attrs[:economic_role] == "supplier_charge"
        raise AgencyCommand::Error.new("Minimum quantity shortfalls must use the supplier charge role.", code: :invalid)
      end
      reject_forbidden_component_fields!(attrs, %i[
        amount_minor_units rate minimum_minor_units percentage_treatment
      ])
      {
        minimum_quantity: attrs[:minimum_quantity], quantity_basis: quantity_basis,
        participant_category_id: attrs[:participant_category_id],
        occupancy_position_from: attrs[:occupancy_position_from],
        occupancy_position_to: attrs[:occupancy_position_to]
      }
    else
      raise AgencyCommand::Error.new("Calculation kind is invalid.", code: :invalid)
    end

    attrs.merge(
      amount_minor_units: nil, rate: nil, minimum_minor_units: nil, minimum_quantity: nil,
      quantity_basis: nil, participant_category_id: nil, occupancy_position_from: nil,
      occupancy_position_to: nil, percentage_treatment: nil
    ).merge(allowed)
  end

  def reject_forbidden_component_fields!(attrs, fields)
    fields.each do |field|
      value = attrs[field]
      next if value.nil? || value == "" || value == false

      raise AgencyCommand::Error.new(
        "#{field.to_s.humanize} is not valid for this calculation.", code: :invalid
      )
    end
  end

  def require_component_value!(value, label)
    return if value.present? || value == 0 || value == 0.0

    raise AgencyCommand::Error.new("#{label} is required for this calculation.", code: :invalid)
  end

  def normalize_base_links(value)
    Array(value).map.with_index do |entry, index|
      attrs = entry.to_h.with_indifferent_access
      {
        base_component_id: required_uuid(attrs[:base_component_id], "Base component"),
        direction: (attrs[:direction].presence || "add").to_s,
        position: index + 1
      }
    end
  end

  def replace_base_links!(definition, component, links)
    ids = links.map { |entry| entry[:base_component_id] }
    raise AgencyCommand::Error.new("Submit each base component once.", code: :invalid) unless ids.uniq.size == ids.size
    bases = definition.supplier_cost_components.where(id: ids).index_by(&:id)
    unless bases.size == ids.size && bases.values.all? { |base| base.position < component.position }
      raise AgencyCommand::Error.new("Base components must be earlier components in the same definition.", code: :invalid)
    end
    component.supplier_cost_component_bases.order(:id).lock.each(&:destroy!)
    links.each do |entry|
      component.supplier_cost_component_bases.create!(
        entry.merge(owner_attributes_for(definition), supplier_cost_definition: definition)
      )
    end
  end

  def owner_attributes_for(owner)
    version_id = owner.is_a?(SupplierArrangementVersion) ? owner.id : owner.supplier_arrangement_version_id
    {
      agency: @agency,
      departure_id: owner.departure_id,
      supplier_arrangement_id: owner.supplier_arrangement_id,
      supplier_arrangement_version_id: version_id
    }
  end

  # Internal builders for a composite that already owns the complete cost graph
  # lock scope. Public commands remain responsible for locks, gates,
  # idempotency, optimistic locking, touches, and success audits.
  def build_supplier_cost_source_already_locked!(
    version:, arrangement:, attributes:, position:
  )
    version.supplier_cost_sources.create!(
      attributes.merge(
        owner_attributes_for(version),
        supplier_arrangement: arrangement,
        position: position
      )
    )
  end

  def build_supplier_cost_definition_already_locked!(
    source:, arrangement:, attributes:
  )
    source.supplier_cost_definitions.create!(
      attributes.merge(
        owner_attributes_for(source),
        supplier_arrangement: arrangement,
        status: "working"
      )
    )
  end

  def build_supplier_cost_component_already_locked!(
    definition:, attributes:, position:, base_links:
  )
    component = definition.supplier_cost_components.create!(
      attributes.merge(owner_attributes_for(definition), position: position)
    )
    replace_base_links!(definition, component, base_links)
    component
  end

  def build_supplier_cost_usage_assumption_already_locked!(version:, attributes:)
    version.supplier_cost_usage_assumptions.create!(
      attributes.merge(owner_attributes_for(version))
    )
  end

  def clear_readiness!(definition)
    return unless definition.forecast_ready?
    definition.update!(READINESS_FIELDS)
  end

  def touch_definition_after_change!(definition)
    definition.forecast_ready? ? definition.update!(READINESS_FIELDS) : definition.touch
  end

  def definition_fingerprint(definition)
    SupplierCostDefinitionFingerprint.call(definition)
  end

  def validate_ready!(definition)
    source = definition.supplier_cost_source
    departure = definition.departure
    normalize_currency(definition.currency, departure)
    supplier = @agency.suppliers.find(source.charging_supplier_id)
    raise AgencyCommand::Error.new("The charging supplier must be active.", code: :invalid_state) unless supplier.active?
    ensure_eligible_charging_supplier!(
      source.supplier_arrangement, source.supplier_arrangement_version,
      source.arrangement_item, source.service_occurrence, supplier
    )
    components = definition.supplier_cost_components.includes(:supplier_cost_component_bases).order(:position).to_a
    if definition.calculated?
      raise AgencyCommand::Error.new("Add at least one cost component.", code: :invalid) if components.empty?
      components.each do |component|
        component.validate!
        if %w[fixed unit_rate].include?(component.calculation_kind) && component.amount_minor_units.to_i <= 0
          raise AgencyCommand::Error.new("Ready amounts must be greater than zero.", code: :invalid)
        end
        if component.percentage? && component.rate.to_d <= 0
          raise AgencyCommand::Error.new("Ready rates must be greater than zero.", code: :invalid)
        end
        if component.minimum_amount_shortfall? && component.minimum_minor_units.to_i <= 0
          raise AgencyCommand::Error.new("Ready minimum amounts must be greater than zero.", code: :invalid)
        end
        if %w[percentage minimum_amount_shortfall].include?(component.calculation_kind) &&
            component.supplier_cost_component_bases.empty?
          raise AgencyCommand::Error.new("That component requires a base.", code: :invalid)
        end
        if component.minimum_quantity_shortfall?
          bases = component.supplier_cost_component_bases.to_a
          raise AgencyCommand::Error.new("A quantity minimum requires exactly one base.", code: :invalid) if bases.size != 1
          base_component = components.find { |entry| entry.id == bases.first.base_component_id }
          unless base_component&.unit_rate? &&
              bases.first.direction == "add" &&
              compatible_ready_quantity_formula?(component, base_component)
            raise AgencyCommand::Error.new(
              "A quantity minimum requires one compatible earlier unit-rate base.", code: :invalid
            )
          end
        end
      end
      validate_required_usage!(source, components)
      validate_ready_evaluation!(definition)
    elsif components.any?
      raise AgencyCommand::Error.new("Zero-cost definitions cannot contain components.", code: :invalid)
    end
  end

  def compatible_ready_quantity_formula?(component, base)
    component.quantity_basis == base.quantity_basis &&
      component.participant_category_id == base.participant_category_id &&
      component.occupancy_position_from == base.occupancy_position_from &&
      component.occupancy_position_to == base.occupancy_position_to
  end

  def validate_ready_evaluation!(definition)
    result = EvaluateSupplierCostForecast.new(
      agency: @agency,
      departure: definition.departure,
      arrangement: definition.supplier_arrangement,
      probe_definition: definition
    ).call(isolated: false)
    source_result = result.arrangements.flat_map(&:sources).find { |entry| entry.source_id == definition.supplier_cost_source_id }
    return unless source_result

    invalid = source_result.warnings.select do |warning|
      %w[
        invalid_percentage_base invalid_minimum_amount_base invalid_quantity_minimum_base
        unsupported_calculation_kind invalid_component_base
      ].include?(warning.code.to_s)
    end
    return if invalid.empty?

    raise AgencyCommand::Error.new(invalid.first.message, code: :invalid)
  end

  def validate_required_usage!(source, components)
    quantity_components = components.select { |component| component.quantity_basis.present? }
    return if quantity_components.empty?
    raise AgencyCommand::Error.new("Quantity formulas require an item-scoped source.", code: :invalid) unless source.arrangement_item_id

    assumption = source.supplier_arrangement_version.supplier_cost_usage_assumptions.find_by(
      arrangement_item_id: source.arrangement_item_id,
      service_occurrence_id: source.service_occurrence_id,
      supplier_resource_id: source.supplier_resource_id
    )
    raise AgencyCommand::Error.new("Add usage assumptions for this cost context.", code: :invalid) unless assumption

    profiles = assumption.supplier_cost_occupancy_profiles.includes(:supplier_cost_occupancy_profile_positions).to_a
    quantity_components.each do |component|
      basis = component.quantity_basis
      needs_units = %w[resource_units resource_nights].include?(basis)
      needs_persons = %w[persons person_nights].include?(basis)
      needs_nights = %w[nights resource_nights person_nights occupancy_position_nights single_occupancy_nights].include?(basis)
      needs_profiles = %w[occupancy_positions occupancy_position_nights single_occupancy_units single_occupancy_nights].include?(basis)
      if needs_units && assumption.expected_resource_units.nil? && profiles.empty?
        raise AgencyCommand::Error.new("Expected resource units are missing.", code: :invalid)
      end
      if needs_persons && assumption.expected_persons.nil? && profiles.empty?
        raise AgencyCommand::Error.new("Expected persons are missing.", code: :invalid)
      end
      if needs_nights && assumption.expected_billable_nights.nil?
        raise AgencyCommand::Error.new("Expected billable nights are missing.", code: :invalid)
      end
      if needs_profiles && profiles.empty?
        raise AgencyCommand::Error.new("Occupancy profiles are missing.", code: :invalid)
      end
    end
  end

  def destroy_definition_graph!(definition)
    definition.supplier_cost_components.order(position: :desc).each do |component|
      component.supplier_cost_component_bases.each(&:destroy!)
      component.dependent_base_links.each(&:destroy!)
      component.destroy!
    end
    definition.destroy!
  end

  def audit_cost!(action, arrangement, version, details)
    audit!(
      agency: @agency, action: action, subject: arrangement, actor: @actor,
      details: { "supplier_arrangement_id" => arrangement.id,
                 "supplier_arrangement_version_id" => version.id }.merge(details)
    )
  end

  def exact_permutation!(submitted, current, label)
    ids = Array(submitted).map { |id| required_uuid(id, label) }
    unless ids.size == current.size && ids.uniq.size == ids.size && ids.sort == current.sort
      raise AgencyCommand::Error.new("Submit every current #{label.downcase} exactly once.", code: :invalid)
    end
    ids
  end

  def required_uuid(value, label)
    parse_optional_uuid(value, label) ||
      raise(AgencyCommand::Error.new("#{label} is required.", code: :invalid))
  end

  def safely_command
    yield
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  rescue ActiveRecord::RecordNotUnique
    raise AgencyCommand::Error.new("That change conflicts with another update.", code: :conflict)
  rescue ActiveRecord::DeleteRestrictionError
    raise AgencyCommand::Error.new("Remove dependent cost planning first.", code: :dependency_exists)
  rescue ActiveRecord::StatementInvalid => error
    raise unless error.cause.is_a?(PG::CheckViolation)

    raise AgencyCommand::Error.new("That cost component shape is invalid.", code: :invalid)
  end
end
