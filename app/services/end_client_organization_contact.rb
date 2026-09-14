class EndClientOrganizationContact < ClientOrganizationContactCommand
  def initialize(agency:, actor:, client_organization_contact:, lock_version:, replacement_primary_contact: nil)
    @agency = agency
    @actor = actor
    @client_organization_contact = client_organization_contact
    @lock_version = lock_version
    @replacement_primary_contact = replacement_primary_contact
  end

  def call
    ensure_assignment_actor!

    ActiveRecord::Base.transaction do
      @agency.lock!
      assignment = @agency.client_organization_contacts.lock.find(@client_organization_contact.id)
      lock_current_assignments!(assignment.client_organization)

      if assignment.ends_on.present?
        raise ActiveRecord::StaleObjectError.new(assignment, "lock_version") unless assignment.lock_version == @lock_version.to_i

        return Result.new(status: :noop, record: assignment)
      end

      assignment.lock_version = @lock_version
      replacement = locked_replacement!(assignment)
      today = agency_today
      raise Error.new("This contact starts in the future and cannot be ended today.", code: :invalid_state) if assignment.starts_on > today

      assignment.update!(ends_on: today, primary: false)
      replacement&.update!(primary: true)
      audit!(
        agency: @agency,
        action: "client_organization.contact_ended",
        subject: assignment.client_organization,
        actor: @actor,
        details: {
          "client_organization_id" => assignment.client_organization_id,
          "client_person_id" => assignment.client_person_id,
          "client_organization_contact_id" => assignment.id,
          "replacement_primary_contact_id" => replacement&.id
        }.compact
      )
      Result.new(status: :updated, record: assignment)
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This record changed. Reload it and try again.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => error
    assignment_conflict!(error)
  end

  private

  def locked_replacement!(assignment)
    return if @replacement_primary_contact.blank?

    replacement = assignment.client_organization.organization_contacts.current.order(:id).lock.find { |row| row.id == @replacement_primary_contact.id }
    raise Error.new("Choose a current contact for the replacement primary.", code: :invalid) unless replacement
    raise Error.new("Choose a different contact for the replacement primary.", code: :invalid) if replacement.id == assignment.id

    replacement
  end
end
