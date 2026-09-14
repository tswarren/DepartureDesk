class ChangeClientOrganizationPrimaryContact < ClientOrganizationContactCommand
  def initialize(agency:, actor:, client_organization_contact:, lock_version:)
    @agency = agency
    @actor = actor
    @client_organization_contact = client_organization_contact
    @lock_version = lock_version
  end

  def call
    ensure_assignment_actor!

    ActiveRecord::Base.transaction do
      @agency.lock!
      assignment = @agency.client_organization_contacts.lock.find(@client_organization_contact.id)
      lock_current_assignments!(assignment.client_organization)
      raise Error.new("Only a current contact can be primary.", code: :invalid_state) unless assignment.current?

      if assignment.primary?
        raise ActiveRecord::StaleObjectError.new(assignment, "lock_version") unless assignment.lock_version == @lock_version.to_i

        return Result.new(status: :noop, record: assignment)
      end

      assignment.lock_version = @lock_version
      assignment.client_organization.organization_contacts.current.where(primary: true).order(:id).lock.each do |current_primary|
        current_primary.update!(primary: false)
      end
      assignment.update!(primary: true)
      audit!(
        agency: @agency,
        action: "client_organization.primary_contact_changed",
        subject: assignment.client_organization,
        actor: @actor,
        details: {
          "client_organization_id" => assignment.client_organization_id,
          "client_person_id" => assignment.client_person_id,
          "client_organization_contact_id" => assignment.id
        }
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
end
