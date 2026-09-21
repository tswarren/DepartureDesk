# frozen_string_literal: true

module PriceCommandSupport
  extend ActiveSupport::Concern

  include OfferCommandSupport

  SIMPLE_PATTERNS = {
    "fixed_per_service" => { calculation_kind: "fixed", quantity_basis: "service_instances", label: "Fixed per service" },
    "per_person" => { calculation_kind: "unit_rate", quantity_basis: "persons", label: "Per person" },
    "per_resource" => { calculation_kind: "unit_rate", quantity_basis: "resource_units", label: "Per resource" },
    "per_night" => { calculation_kind: "unit_rate", quantity_basis: "nights", label: "Per night" },
    "per_resource_night" => { calculation_kind: "unit_rate", quantity_basis: "resource_nights", label: "Per resource-night" },
    "occupancy_positions" => { calculation_kind: "unit_rate", quantity_basis: "occupancy_positions", label: "Occupancy positions" }
  }.freeze

  private

  def lock_price_definition!(version, definition = nil)
    scope = version.association(:price_definition).scope.lock
    if definition
      scope.find(definition.is_a?(ServiceOfferPriceDefinition) ? definition.id : definition)
    else
      scope.first
    end
  end

  def destroy_price_graph!(definition)
    ServiceOfferPriceComponentBase.where(service_offer_price_definition_id: definition.id).delete_all
    ServiceOfferPriceComponent.where(service_offer_price_definition_id: definition.id).delete_all
    definition.delete
  end

  def replace_price_components!(definition, version, offer, departure, component_attrs)
    raise AgencyCommand::Error.new("A zero price cannot contain components.", code: :invalid) if definition.zero_price?
    if component_attrs.blank?
      raise AgencyCommand::Error.new("A calculated price needs at least one component.", code: :invalid)
    end

    created = []
    component_attrs.each_with_index do |raw, index|
      attrs = normalize_price_component_attributes(raw, currency: definition.currency, position: index + 1)
      created << definition.service_offer_price_components.create!(
        agency: @agency,
        departure: departure,
        service_offer: offer,
        service_offer_version: version,
        **attrs.except(:bases)
      )
    end

    created.each_with_index do |component, index|
      bases = Array(component_attrs[index][:bases] || component_attrs[index]["bases"])
      next if bases.blank?
      unless component.percentage?
        raise AgencyCommand::Error.new("Only percentage components accept bases.", code: :invalid)
      end

      bases.each_with_index do |base_raw, base_index|
        base_attrs = base_raw.to_h.with_indifferent_access
        base = resolve_base_component!(created, component, base_attrs)
        component.service_offer_price_component_bases.create!(
          agency: @agency,
          departure: departure,
          service_offer: offer,
          service_offer_version: version,
          service_offer_price_definition: definition,
          base_component: base,
          direction: normalize_base_direction(base_attrs[:direction]),
          position: base_index + 1
        )
      end
    end

    created.each do |component|
      next unless component.percentage?
      if component.service_offer_price_component_bases.empty?
        raise AgencyCommand::Error.new("A percentage component must name at least one earlier base.", code: :invalid)
      end
    end

    if definition.reload.overlapping_base_prices?
      raise AgencyCommand::Error.new("A generic base price cannot overlap a more specific base price.", code: :invalid)
    end

    created
  end

  def resolve_base_component!(created, component, base_attrs)
    identifier = base_attrs[:base_component_id].presence || base_attrs[:base_position]
    base = if identifier.present? && created.any? { |row| row.id.to_s == identifier.to_s }
      created.find { |row| row.id.to_s == identifier.to_s }
    elsif identifier.present?
      created.find { |row| row.position == identifier.to_i }
    end
    raise AgencyCommand::Error.new("A percentage base was not found.", code: :invalid) if base.nil?
    if base.position >= component.position
      raise AgencyCommand::Error.new("A percentage base must be an earlier component.", code: :invalid)
    end
    if base.included_tax_allocation?
      raise AgencyCommand::Error.new("An included-tax allocation cannot be a later percentage base.", code: :invalid)
    end

    base
  end

  def normalize_base_direction(value)
    direction = value.to_s.presence || "add"
    unless ServiceOfferPriceComponentBase::DIRECTIONS.include?(direction)
      raise AgencyCommand::Error.new("Percentage base direction is invalid.", code: :invalid)
    end

    direction
  end

  def components_from_pattern(attributes, currency:)
    pattern = SIMPLE_PATTERNS[attributes[:pattern].to_s]
    raise AgencyCommand::Error.new("Choose a price pattern.", code: :invalid) if pattern.nil?

    amount = money_minor_or_nil(
      attributes.key?(:amount) ? attributes[:amount] : attributes[:amount_minor_units],
      currency,
      "Amount",
      major_units: attributes.key?(:amount)
    )
    raise AgencyCommand::Error.new("Enter an amount.", code: :invalid) if amount.nil?

    [
      {
        label: attributes[:label].presence || pattern[:label],
        client_role: "base_price",
        calculation_kind: pattern[:calculation_kind],
        amount_minor_units: amount,
        quantity_basis: pattern[:quantity_basis],
        client_rate_category_key: attributes[:client_rate_category_key],
        occupancy_position_key: attributes[:occupancy_position_key],
        bases: []
      }
    ]
  end

  def normalize_price_component_attributes(raw, currency:, position:)
    attrs = raw.to_h.with_indifferent_access
    kind = attrs[:calculation_kind].to_s
    unless ServiceOfferPriceComponent::CALCULATION_KINDS.include?(kind)
      raise AgencyCommand::Error.new("Calculation kind is invalid.", code: :invalid)
    end
    role = attrs[:client_role].to_s.presence || "base_price"
    unless ServiceOfferPriceComponent::CLIENT_ROLES.include?(role)
      raise AgencyCommand::Error.new("Client role is invalid.", code: :invalid)
    end
    treatment = attrs[:percentage_treatment].to_s.presence
    if treatment && !ServiceOfferPriceComponent::PERCENTAGE_TREATMENTS.include?(treatment)
      raise AgencyCommand::Error.new("Percentage treatment is invalid.", code: :invalid)
    end
    quantity_basis = attrs[:quantity_basis].to_s.presence
    if kind == "fixed"
      quantity_basis = "service_instances"
    end
    if quantity_basis && !ServiceOfferPriceComponent::QUANTITY_BASES.include?(quantity_basis)
      raise AgencyCommand::Error.new("Quantity basis is invalid.", code: :invalid)
    end

    amount = money_minor_or_nil(
      attrs.key?(:amount) ? attrs[:amount] : attrs[:amount_minor_units],
      currency,
      "Amount",
      major_units: attrs.key?(:amount)
    )
    rate = normalize_price_rate(attrs)

    shaped = case kind
    when "fixed"
      require_price_value!(amount, "Amount")
      reject_price_fields!(attrs, %i[rate percentage_treatment], kind)
      { amount_minor_units: amount, quantity_basis: "service_instances", rate: nil, percentage_treatment: nil }
    when "unit_rate"
      require_price_value!(amount, "Amount")
      require_price_value!(quantity_basis, "Quantity basis")
      reject_price_fields!(attrs, %i[rate percentage_treatment], kind)
      { amount_minor_units: amount, quantity_basis: quantity_basis, rate: nil, percentage_treatment: nil }
    when "percentage"
      require_price_value!(rate, "Rate")
      require_price_value!(treatment, "Percentage treatment")
      if amount.present?
        raise AgencyCommand::Error.new("A percentage component cannot have an amount.", code: :invalid)
      end
      if quantity_basis.present?
        raise AgencyCommand::Error.new("A percentage component cannot have a quantity basis.", code: :invalid)
      end
      { amount_minor_units: nil, quantity_basis: nil, rate: rate, percentage_treatment: treatment }
    end

    if treatment == "included" && role != "tax_fee"
      raise AgencyCommand::Error.new("Included treatment is only valid for a tax or fee.", code: :invalid)
    end

    {
      label: normalize_price_text(attrs[:label], "Label", ServiceOfferPriceComponent::LABEL_LIMIT),
      client_role: role,
      calculation_kind: kind,
      client_rate_category_key: normalize_optional_key(
        attrs[:client_rate_category_key], "Client rate category", ServiceOfferPriceComponent::RATE_CATEGORY_LIMIT
      ),
      occupancy_position_key: normalize_optional_key(
        attrs[:occupancy_position_key], "Occupancy position", ServiceOfferPriceComponent::OCCUPANCY_POSITION_LIMIT
      ),
      position: position,
      **shaped
    }
  end

  def normalize_price_rate(attrs)
    if attrs.key?(:percentage) && attrs[:percentage].present?
      (BigDecimal(attrs[:percentage].to_s) / BigDecimal("100")).tap do |rate|
        raise AgencyCommand::Error.new("Rate is invalid.", code: :invalid) if rate.negative?
      end
    elsif attrs[:rate].present?
      BigDecimal(attrs[:rate].to_s).tap do |rate|
        raise AgencyCommand::Error.new("Rate is invalid.", code: :invalid) if rate.negative?
      end
    end
  rescue ArgumentError
    raise AgencyCommand::Error.new("Rate is invalid.", code: :invalid)
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

  def integer_or_nil(value, label, minimum: 0)
    return nil if value.nil? || value == ""

    integer = Integer(value)
    raise AgencyCommand::Error.new("#{label} is invalid.", code: :invalid) if integer < minimum
    integer
  rescue ArgumentError, TypeError
    raise AgencyCommand::Error.new("#{label} is invalid.", code: :invalid)
  end

  def normalize_price_text(value, label, limit, required: true)
    text = value.to_s.strip
    raise AgencyCommand::Error.new("Enter a #{label.downcase}.", code: :invalid) if required && text.blank?
    if text.length > limit
      raise AgencyCommand::Error.new("#{label} must be #{limit} characters or fewer.", code: :invalid)
    end

    text.presence
  end

  def normalize_optional_key(value, label, limit)
    key = value.to_s.strip.presence
    return if key.blank?
    if key.length > limit
      raise AgencyCommand::Error.new("#{label} must be #{limit} characters or fewer.", code: :invalid)
    end

    key
  end

  def require_price_value!(value, label)
    raise AgencyCommand::Error.new("Enter a #{label.downcase}.", code: :invalid) if value.nil? || value == ""
  end

  def reject_price_fields!(attrs, fields, kind)
    fields.each do |field|
      next if attrs[field].blank?

      raise AgencyCommand::Error.new("#{field.to_s.humanize} is not valid for #{kind.humanize.downcase}.", code: :invalid)
    end
  end

  def normalize_price_mode(attributes)
    mode = attributes[:mode].to_s.presence || "calculated"
    unless ServiceOfferPriceDefinition::MODES.include?(mode)
      raise AgencyCommand::Error.new("Price mode is invalid.", code: :invalid)
    end

    reason = normalize_price_text(
      attributes[:zero_price_reason], "Zero-price reason", ServiceOfferPriceDefinition::ZERO_PRICE_REASON_LIMIT,
      required: mode == "zero_price"
    )
    { mode: mode, zero_price_reason: mode == "zero_price" ? reason : nil }
  end

  def require_operating_currency!(departure)
    currency = departure.operating_currency
    if currency.blank?
      raise AgencyCommand::Error.new("Set the departure operating currency before pricing.", code: :invalid_state)
    end

    currency
  end

  def price_audit_details(offer, version, definition, component_count:)
    {
      "service_offer_id" => offer.id,
      "service_offer_version_id" => version.id,
      "service_offer_price_definition_id" => definition.id,
      "mode" => definition.mode,
      "component_count" => component_count
    }
  end
end
