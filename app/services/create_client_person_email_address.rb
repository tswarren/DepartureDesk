class CreateClientPersonEmailAddress < ClientPersonContactPointCommand
  COMMAND = "CreateClientPersonEmailAddress"

  def call
    prepare!
    ActiveRecord::Base.transaction do
      @agency.lock!
      person = locked_person
      raise Error.new("That person is not active.", code: :invalid_state) unless person.active?

      address = @attributes[:address].to_s.strip
      fingerprint = DuplicateAcknowledgement.fingerprint("address" => address.downcase)
      point_id = SecureRandom.uuid_v7
      decision = DirectoryDuplicateGate.new(
        agency: @agency, actor: @actor, command: COMMAND, token: @acknowledgement_token,
        reason: @acknowledgement_reason, fingerprint: fingerprint,
        proposed_ids: { "person_id" => person.id, "contact_point_id" => point_id, "contact_class" => "ClientPersonEmailAddress" }
      ).call { FindClientPersonDuplicates.call(agency: @agency, actor: @actor, names: {}, emails: [ address ]) }
      return decision if decision.is_a?(Result)

      point = person.email_addresses.create!(
        id: decision&.dig("contact_point_id") || point_id,
        agency: @agency,
        address: address,
        label: @attributes[:label],
        preferred: false,
        status: "active"
      )
      prefer!(person, point) if ActiveModel::Type::Boolean.new.cast(@attributes[:preferred])
      audit_contact!(person, changed_fields: [ "email_address" ])
      audit_override!(person) if decision
      Result.new(status: :created, record: point)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def prefer!(person, point)
    person.email_addresses.where.not(id: point.id).update_all(preferred: false, updated_at: Time.current)
    point.update!(preferred: true)
  end
end
