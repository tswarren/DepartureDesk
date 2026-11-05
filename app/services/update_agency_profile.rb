# Saves the agency profile, defaults and document inclusion flags (SET-04 to
# SET-07, SET-13, ACC-33). Only an Agency Admin may call it. Keys left out of
# attributes or inclusions keep their values. One save writes one audit event
# naming the fields it changed.
class UpdateAgencyProfile < AgencyCommand
  ATTRIBUTES = %w[
    name legal_name country_code default_currency default_timezone
    contact_email agency_contact_name
    address_line_1 address_line_2 address_locality address_region address_postal_code address_country_code
    seller_of_travel_disclosure confirmation_footer financial_document_footer
    hold_duration_days installment_buffer_days
  ].freeze
  PHONE_ATTRIBUTES = %w[phone_number phone_extension phone_country_code].freeze

  def initialize(agency:, actor:, attributes:, inclusions: {}, lock_version: nil)
    @agency = agency
    @actor = actor
    @attributes = attributes.to_h.stringify_keys
    @inclusions = inclusions.to_h.stringify_keys
    @lock_version = lock_version
  end

  def call
    ActiveRecord::Base.transaction do
      @agency.with_lock do
        @agency.reload
        ensure_permitted!(@actor, :manage_agency_profile)
        ensure_fresh_lock!
        ensure_active_agency!(@agency)

        @agency.assign_attributes(@attributes.slice(*ATTRIBUTES))
        assign_phone! if @attributes.keys.intersect?(PHONE_ATTRIBUTES)
        changed = @agency.changed - %w[lock_version updated_at]
        @agency.save!
        changed += update_inclusions!
        next if changed.empty?

        audit!(
          agency: @agency,
          action: "agency.profile_updated",
          subject: @agency,
          actor: @actor,
          details: { "agency_id" => @agency.id, "changed" => changed.sort }
        )
      end
    end
    Result.new(status: :accepted, record: @agency)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def ensure_fresh_lock!
    return if @lock_version.nil?
    return if @agency.lock_version == @lock_version.to_i

    raise Error.new("This agency was updated by someone else.", code: :conflict)
  end

  def assign_phone!
    if @attributes["phone_number"].blank?
      @agency.assign_attributes(phone_number: nil, phone_normalized_number: nil, phone_extension: nil, phone_country_code: nil)
      return
    end

    phone = PhoneNumberNormalizer.call(
      number: @attributes["phone_number"],
      extension: @attributes["phone_extension"],
      country_code: @attributes["phone_country_code"].presence || @agency.country_code
    )
    @agency.assign_attributes(
      phone_number: phone.number,
      phone_normalized_number: phone.normalized_number,
      phone_extension: phone.extension,
      phone_country_code: phone.country_code
    )
  end

  def update_inclusions!
    unknown = @inclusions.keys - AgencyDocumentInclusion::FAMILIES
    raise Error.new("That document type is not available.", code: :invalid) if unknown.any?

    @inclusions.flat_map do |family, flags|
      flags = flags.to_h.stringify_keys
      unknown_fields = flags.keys - AgencyDocumentInclusion::FIELDS
      raise Error.new("That profile field is not available.", code: :invalid) if unknown_fields.any?

      row = @agency.document_inclusions.lock.find_by!(document_family: family)
      row.assign_attributes(flags.transform_keys { |field| "include_#{field}" }.transform_values { |value| ActiveModel::Type::Boolean.new.cast(value) || false })
      changed = row.changed.grep(/\Ainclude_/).map { |column| "inclusions.#{family}.#{column.delete_prefix("include_")}" }
      row.save!
      changed
    end
  end
end
