class CreateClientPersonPostalAddress < ClientPersonContactPointCommand
  COMMAND = "CreateClientPersonPostalAddress"

  def call
    prepare!
    ActiveRecord::Base.transaction do
      @agency.lock!
      person = locked_person
      raise Error.new("That person is not active.", code: :invalid_state) unless person.active?
      raise Error.new("Enter an accepted country.", code: :invalid) unless CountryCode.accepted?(@attributes[:country_code])

      postal_code = @attributes[:postal_code]
      fingerprint = DuplicateAcknowledgement.fingerprint(
        "line_1" => SearchNormalizer.normalize(@attributes[:line_1]),
        "postal_code" => SearchNormalizer.normalize(postal_code),
        "country_code" => @attributes[:country_code].to_s.upcase
      )
      point_id = SecureRandom.uuid_v7
      decision = DirectoryDuplicateGate.new(
        agency: @agency, actor: @actor, command: COMMAND, token: @acknowledgement_token,
        reason: @acknowledgement_reason, fingerprint: fingerprint,
        proposed_ids: { "person_id" => person.id, "contact_point_id" => point_id, "contact_class" => "ClientPersonPostalAddress" }
      ).call do
        FindClientPersonDuplicates.call(
          agency: @agency, actor: @actor,
          names: person.slice(:first_name, :middle_name, :last_name, :suffix),
          postal_codes: [ postal_code ],
          exclude_person_id: person.id
        )
      end
      return decision if decision.is_a?(Result)

      point = person.postal_addresses.create!(
        id: decision&.dig("contact_point_id") || point_id,
        agency: @agency,
        line_1: @attributes[:line_1],
        line_2: @attributes[:line_2],
        locality: @attributes[:locality],
        region: @attributes[:region],
        postal_code: postal_code,
        country_code: @attributes[:country_code],
        label: @attributes[:label],
        preferred: false,
        status: "active"
      )
      prefer!(person, point) if ActiveModel::Type::Boolean.new.cast(@attributes[:preferred])
      audit_contact!(person, changed_fields: [ "postal_address" ])
      audit_override!(person) if decision
      Result.new(status: :created, record: point)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def prefer!(person, point)
    person.postal_addresses.where.not(id: point.id).update_all(preferred: false, updated_at: Time.current)
    point.update!(preferred: true)
  end
end
