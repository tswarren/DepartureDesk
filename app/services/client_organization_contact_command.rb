class ClientOrganizationContactCommand < AgencyCommand
  include AgencyLocalDate

  private

  def ensure_assignment_actor!
    ensure_directory_actor!(@actor, @agency, :manage_client_directory)
    ensure_active_agency!(@agency)
  end

  def normalize_date(value)
    ActiveModel::Type::Date.new.cast(value)
  rescue ArgumentError
    nil
  end

  def assignment_conflict!(error)
    raise error unless assignment_conflict?(error)

    raise Error.new("That organization contact assignment conflicts with an existing assignment. Reload and try again.", code: :conflict)
  end

  def assignment_conflict?(error)
    cause = error.respond_to?(:cause) ? error.cause : nil
    error.is_a?(ActiveRecord::RecordNotUnique) ||
      cause.is_a?(PG::UniqueViolation) ||
      cause.is_a?(PG::ExclusionViolation) ||
      error.message.include?("client_org_contacts")
  end

  def lock_current_assignments!(organization)
    organization.organization_contacts.current.order(:id).lock.to_a
  end

  def audit_contact_added!(organization, assignment)
    audit!(
      agency: @agency,
      action: "client_organization.contact_added",
      subject: organization,
      actor: @actor,
      details: {
        "client_organization_id" => organization.id,
        "client_person_id" => assignment.client_person_id,
        "client_organization_contact_id" => assignment.id
      }
    )
  end
end
