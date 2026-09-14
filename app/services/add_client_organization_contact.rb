class AddClientOrganizationContact < ClientOrganizationContactCommand
  def initialize(agency:, actor:, client_organization:, client_person:, attributes:)
    @agency = agency
    @actor = actor
    @client_organization = client_organization
    @client_person = client_person
    @attributes = attributes.to_h.symbolize_keys
  end

  def call
    ensure_assignment_actor!
    raise Error.new("That organization could not be found.", code: :invalid) unless @client_organization&.agency_id == @agency.id
    raise Error.new("That person could not be found.", code: :invalid) unless @client_person&.agency_id == @agency.id

    starts_on = normalize_date(@attributes[:starts_on])
    ends_on = normalize_date(@attributes[:ends_on])
    raise Error.new("Choose a start date.", code: :invalid) unless starts_on
    reject_future_date!(starts_on, field: :starts_on)
    reject_future_date!(ends_on, field: :ends_on)
    raise Error.new("End date cannot be before start date.", code: :invalid) if ends_on && ends_on < starts_on

    primary = ActiveModel::Type::Boolean.new.cast(@attributes[:primary]) || false
    raise Error.new("Historical contacts cannot be primary.", code: :invalid_state) if primary && ends_on.present?

    ActiveRecord::Base.transaction do
      @agency.lock!
      organization = @agency.client_organizations.lock.find(@client_organization.id)
      person = @agency.client_people.lock.find(@client_person.id)
      raise Error.new("That organization is not active.", code: :invalid_state) unless organization.active?
      raise Error.new("That person is not active.", code: :invalid_state) unless person.active?

      lock_current_assignments!(organization)
      clear_current_primary!(organization) if primary
      assignment = organization.organization_contacts.create!(
        agency: @agency,
        client_person: person,
        starts_on: starts_on,
        ends_on: ends_on,
        title: @attributes[:title],
        role_label: @attributes[:role_label],
        primary: primary
      )
      audit_contact_added!(organization, assignment)
      Result.new(status: :created, record: assignment)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => error
    assignment_conflict!(error)
  end

  private

  def clear_current_primary!(organization)
    organization.organization_contacts.current.where(primary: true).order(:id).lock.each do |assignment|
      assignment.update!(primary: false)
    end
  end
end
