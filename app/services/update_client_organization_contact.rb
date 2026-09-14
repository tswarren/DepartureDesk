class UpdateClientOrganizationContact < ClientOrganizationContactCommand
  def initialize(agency:, actor:, client_organization_contact:, attributes:, lock_version:)
    @agency = agency
    @actor = actor
    @client_organization_contact = client_organization_contact
    @attributes = attributes.to_h.symbolize_keys
    @lock_version = lock_version
  end

  def call
    ensure_assignment_actor!

    starts_on = normalize_date(@attributes[:starts_on])
    raise Error.new("Choose a start date.", code: :invalid) unless starts_on
    reject_future_date!(starts_on, field: :starts_on)

    ActiveRecord::Base.transaction do
      @agency.lock!
      assignment = @agency.client_organization_contacts.lock.find(@client_organization_contact.id)
      if assignment.ends_on && starts_on > assignment.ends_on
        raise Error.new("Start date cannot be after end date.", code: :invalid)
      end
      assignment.lock_version = @lock_version
      return Result.new(status: :noop, record: assignment) if unchanged?(assignment, starts_on)

      assignment.update!(starts_on: starts_on, title: @attributes[:title], role_label: @attributes[:role_label])
      audit!(
        agency: @agency,
        action: "client_organization.contact_updated",
        subject: assignment.client_organization,
        actor: @actor,
        details: {
          "client_organization_id" => assignment.client_organization_id,
          "client_person_id" => assignment.client_person_id,
          "client_organization_contact_id" => assignment.id,
          "changed_fields" => %w[starts_on title role_label]
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

  private

  def unchanged?(assignment, starts_on)
    assignment.starts_on == starts_on &&
      assignment.title == @attributes[:title].presence &&
      assignment.role_label == @attributes[:role_label].presence
  end
end
