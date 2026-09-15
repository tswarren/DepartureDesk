class CreateSupplierLocation < AgencyCommand
  COMMAND = "CreateSupplierLocation"
  ADDRESS_ATTRIBUTES = %i[
    address_line_1 address_line_2 address_locality address_region address_postal_code address_country_code
  ].freeze

  def initialize(agency:, actor:, supplier:, attributes:, acknowledgement_token: nil, acknowledgement_reason: nil)
    @agency = agency
    @actor = actor
    @supplier = supplier
    @attributes = attributes.to_h.symbolize_keys
    @acknowledgement_token = acknowledgement_token
    @acknowledgement_reason = acknowledgement_reason
  end

  def call
    ensure_directory_actor!(@actor, @agency, :manage_supplier_directory)
    ensure_active_agency!(@agency)
    raise ActiveRecord::RecordNotFound if @supplier.blank?

    ActiveRecord::Base.transaction do
      location_id = SecureRandom.uuid_v7
      @agency.lock!
      supplier = @agency.suppliers.lock.find(@supplier.id)
      raise Error.new("That supplier is not active.", code: :invalid_state) unless supplier.active?

      attrs = normalized_attributes
      decision = acknowledge!(supplier, location_id, attrs)
      return decision if decision.is_a?(Result)

      location = supplier.locations.create!(
        id: decision&.dig("supplier_location_id") || location_id,
        agency: @agency,
        **attrs,
        status: "active"
      )
      audit!(
        agency: @agency,
        action: "supplier_location.created",
        subject: location,
        actor: @actor,
        details: { "supplier_location_id" => location.id, "supplier_id" => supplier.id }
      )
      audit_override!(location, decision) if decision
      Result.new(status: :created, record: location)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  rescue ArgumentError => error
    raise Error.new(error.message, code: :invalid)
  end

  private

  def acknowledge!(supplier, location_id, attrs)
    DirectoryDuplicateGate.new(
      agency: @agency,
      actor: @actor,
      command: COMMAND,
      token: @acknowledgement_token,
      reason: @acknowledgement_reason,
      fingerprint: fingerprint(attrs),
      proposed_ids: { "supplier_location_id" => location_id, "supplier_id" => supplier.id }
    ).call { candidates(supplier, attrs) }
  end

  def candidates(supplier, attrs)
    FindSupplierLocationDuplicates.call(
      agency: @agency,
      actor: @actor,
      supplier: supplier,
      name: attrs[:name],
      address: attrs.slice(*ADDRESS_ATTRIBUTES)
    )
  end

  def normalized_attributes
    attrs = {
      name: @attributes[:name].to_s.strip.presence,
      timezone: @attributes[:timezone].to_s.strip.presence,
      address_line_1: @attributes[:address_line_1].to_s.strip.presence,
      address_line_2: @attributes[:address_line_2].to_s.strip.presence,
      address_locality: @attributes[:address_locality].to_s.strip.presence,
      address_region: @attributes[:address_region].to_s.strip.presence,
      address_postal_code: @attributes[:address_postal_code].to_s.strip.presence,
      address_country_code: @attributes[:address_country_code].to_s.strip.upcase.presence
    }
    reject_unit_separator!(attrs)
    attrs.merge(normalized_phone)
  end

  def normalized_phone
    number = @attributes[:phone_number].presence || @attributes[:number].presence
    extension = @attributes[:phone_extension].presence || @attributes[:extension]
    country = @attributes[:phone_country_code].presence || @attributes[:country_code]
    return { phone_number: nil, phone_normalized_number: nil, phone_extension: nil, phone_country_code: nil } if number.blank? && extension.blank? && country.blank?

    phone = PhoneNumberNormalizer.call(number: number, extension: extension, country_code: country)
    {
      phone_number: phone.number,
      phone_normalized_number: phone.normalized_number,
      phone_extension: phone.extension,
      phone_country_code: phone.country_code
    }
  end

  def reject_unit_separator!(attrs)
    ADDRESS_ATTRIBUTES.each do |attribute|
      value = attrs[attribute]
      next if value.blank? || !value.include?(SupplierLocation::UNIT_SEPARATOR)

      raise Error.new("#{attribute.to_s.humanize} contains an invalid control character", code: :invalid)
    end
  end

  def fingerprint(attrs)
    DuplicateAcknowledgement.fingerprint(
      "name" => SearchNormalizer.normalize(attrs[:name]),
      "address_line_1" => SearchNormalizer.normalize(attrs[:address_line_1]),
      "address_line_2" => SearchNormalizer.normalize(attrs[:address_line_2]),
      "address_locality" => SearchNormalizer.normalize(attrs[:address_locality]),
      "address_region" => SearchNormalizer.normalize(attrs[:address_region]),
      "address_postal_code" => SearchNormalizer.normalize(attrs[:address_postal_code]),
      "address_country_code" => attrs[:address_country_code].to_s
    )
  end

  def audit_override!(location, decision)
    audit!(
      agency: @agency,
      action: "supplier_location.duplicate_override",
      subject: location,
      actor: @actor,
      details: duplicate_override_details(decision, reason: @acknowledgement_reason)
    )
  end
end
