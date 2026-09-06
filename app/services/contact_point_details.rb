class ContactPointDetails
  def self.build(contact_kind:, attributes:, agency:)
    attributes = attributes.to_h.with_indifferent_access
    case contact_kind.to_s
    when "email"
      parsed = EmailAddressNormalizer.normalize(attributes[:display_address])
      parsed.merge(
        normalized_value: parsed[:normalized_address],
        email_type: attributes[:email_type].presence || "personal",
        normalization_version: EmailAddressNormalizer::VERSION
      )
    when "phone"
      default_country = attributes[:parsed_country_code].presence || agency.country_code
      parsed = PhoneNumberNormalizer.normalize(attributes[:display_number], default_country:)
      {
        display_number: parsed.display_number,
        normalized_digits: parsed.normalized_digits,
        e164_number: parsed.e164_number,
        extension: attributes[:extension].presence,
        phone_type: attributes[:phone_type].presence || "other",
        parsed_country_code: parsed.parsed_country_code,
        parse_status: parsed.parse_status,
        normalization_version: PhoneNumberNormalizer::VERSION,
        normalized_value: parsed.normalized_digits
      }
    when "postal_address"
      country = attributes[:country_code].to_s.strip.upcase
      unless CountryReference.valid_code?(country)
        raise MembershipCommand::Error.new("Choose a recognized country.", code: :invalid)
      end
      unless attributes[:address_line_1].to_s.strip.present?
        raise MembershipCommand::Error.new("Enter the first address line.", code: :invalid)
      end
      formatted = PostalAddressFormatter.format(
        attention: attributes[:attention],
        address_line_1: attributes[:address_line_1],
        address_line_2: attributes[:address_line_2],
        address_line_3: attributes[:address_line_3],
        locality: attributes[:locality],
        administrative_region: attributes[:administrative_region],
        postal_code: attributes[:postal_code],
        country_code: country
      )
      {
        attention: attributes[:attention],
        address_line_1: attributes[:address_line_1],
        address_line_2: attributes[:address_line_2],
        address_line_3: attributes[:address_line_3],
        locality: attributes[:locality],
        administrative_region: attributes[:administrative_region],
        postal_code: attributes[:postal_code],
        country_code: country,
        formatted_address: formatted,
        normalized_address: PostalAddressFormatter.normalize(formatted),
        normalization_version: 1,
        normalized_value: PostalAddressFormatter.normalize(formatted)
      }
    else
      raise MembershipCommand::Error.new("Choose an email, phone, or postal address.", code: :invalid)
    end
  end

  def self.write!(contact_point, detail)
    record = case contact_point.contact_kind
    when "email" then contact_point.email_address || contact_point.build_email_address
    when "phone" then contact_point.phone_number || contact_point.build_phone_number
    when "postal_address" then contact_point.postal_address || contact_point.build_postal_address
    end
    attrs = detail.except(:normalized_value)
    if record.new_record?
      attrs = attrs.merge(
        agency_id: contact_point.agency_id,
        contact_kind: contact_point.contact_kind
      )
    end
    record.assign_attributes(attrs)
    record.save!
    record
  end
end
