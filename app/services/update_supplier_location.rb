class UpdateSupplierLocation < AgencyCommand
  COMMAND = "UpdateSupplierLocation"
  ADDRESS_ATTRIBUTES = %i[
    address_line_1 address_line_2 address_locality address_region address_postal_code address_country_code
  ].freeze
  DUPLICATE_FIELDS = (%i[name] + ADDRESS_ATTRIBUTES).freeze

  def initialize(agency:, actor:, supplier:, supplier_location:, attributes:, lock_version:, acknowledgement_token: nil, acknowledgement_reason: nil)
    @agency = agency
    @actor = actor
    @supplier = supplier
    @supplier_location = supplier_location
    @attributes = attributes.to_h.symbolize_keys
    @lock_version = lock_version
    @acknowledgement_token = acknowledgement_token
    @acknowledgement_reason = acknowledgement_reason
  end

  def call
    ensure_directory_actor!(@actor, @agency, :manage_supplier_directory)
    ensure_active_agency!(@agency)
    raise ActiveRecord::RecordNotFound if @supplier.blank? || @supplier_location.blank?

    ActiveRecord::Base.transaction do
      @agency.lock!
      supplier = @agency.suppliers.lock.find(@supplier.id)
      location = supplier.locations.lock.find(@supplier_location.id)
      raise ActiveRecord::StaleObjectError.new(location, "lock_version") if @lock_version.nil?
      raise ActiveRecord::StaleObjectError.new(location, "lock_version") if location.lock_version != @lock_version.to_i
      location.lock_version = @lock_version

      attrs = normalized_attributes
      return Result.new(status: :noop, record: location) if unchanged?(location, attrs)

      decision = nil
      if duplicate_fields_changed?(location, attrs)
        decision = acknowledge!(supplier, location, attrs)
        return decision if decision.is_a?(Result)
      end

      location.update!(attrs)
      audit!(
        agency: @agency,
        action: "supplier_location.updated",
        subject: location,
        actor: @actor,
        details: {
          "supplier_location_id" => location.id,
          "supplier_id" => supplier.id,
          "changed_fields" => changed_fields(location, attrs)
        }
      )
      audit_override!(location, decision) if decision
      Result.new(status: :updated, record: location)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  rescue ArgumentError => error
    raise Error.new(error.message, code: :invalid)
  end

  private

  def acknowledge!(supplier, location, attrs)
    DirectoryDuplicateGate.new(
      agency: @agency,
      actor: @actor,
      command: COMMAND,
      token: @acknowledgement_token,
      reason: @acknowledgement_reason,
      fingerprint: fingerprint(attrs),
      target: location,
      current_fingerprint: -> { stored_fingerprint(location) }
    ).call do
      FindSupplierLocationDuplicates.call(
        agency: @agency,
        actor: @actor,
        supplier: supplier,
        name: attrs[:name],
        address: attrs.slice(*ADDRESS_ATTRIBUTES),
        exclude_location_id: location.id
      )
    end
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

  def unchanged?(location, attrs)
    attrs.all? { |key, value| comparable(location.public_send(key)) == comparable(value) }
  end

  def duplicate_fields_changed?(location, attrs)
    DUPLICATE_FIELDS.any? { |key| comparable(location.public_send(key)) != comparable(attrs[key]) }
  end

  def changed_fields(location, attrs)
    attrs.keys.select { |key| location.saved_change_to_attribute?(key) }.map(&:to_s)
  end

  def comparable(value)
    value.presence
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

  def stored_fingerprint(location)
    fingerprint(DUPLICATE_FIELDS.index_with { |key| location.public_send(key) })
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
