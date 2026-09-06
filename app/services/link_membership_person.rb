class LinkMembershipPerson < MembershipCommand
  def initialize(agency:, membership:, person: nil, given_name: nil, family_name: nil,
    preferred_name: nil, middle_name: nil, source:, audit_link: false,
    actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @membership = membership
    @person = person
    @given_name = given_name
    @family_name = family_name
    @preferred_name = preferred_name
    @middle_name = middle_name
    @source = source
    @audit_link = audit_link
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def self.allocate_person(agency:, given_name:, family_name:, preferred_name: nil, middle_name: nil,
    actor: nil, actor_identifier: nil, privileged: false)
    new(
      agency: agency,
      membership: agency.agency_memberships.new,
      given_name: given_name,
      family_name: family_name,
      preferred_name: preferred_name,
      middle_name: middle_name,
      source: "allocate",
      actor: actor,
      actor_identifier: actor_identifier,
      privileged: privileged
    ).allocate_person
  end

  def self.record_locked!(agency:, membership:, person:, source:, actor: nil, actor_identifier: nil,
    privileged: false)
    new(
      agency: agency,
      membership: membership,
      person: person,
      source: source,
      audit_link: true,
      actor: actor,
      actor_identifier: actor_identifier,
      privileged: privileged
    ).record_locked!
  end

  def allocate_person
    ensure_actor_shape!
    raise Error.new("A first and last name are required.", code: :invalid) if @given_name.blank? || @family_name.blank?

    person = Person.new(
      agency: @agency,
      party_kind: "person",
      given_name: @given_name,
      family_name: @family_name,
      preferred_name: @preferred_name,
      middle_name: @middle_name
    )
    party = @agency.parties.new(party_kind: "person", status: "active")
    party.apply_derived_names!(person)
    party.save!
    person.party = party
    person.party_id = party.id
    person.save!
    audit!(
      agency: @agency,
      action: "directory.party_created",
      subject: party,
      details: {
        "party_id" => party.id,
        "party_kind" => "person",
        "source" => @source.to_s
      },
      **actor_audit_args
    )
    person
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  def record_locked!
    ensure_actor_shape!
    raise Error.new("A person is required.", code: :invalid) if @person.blank?

    ensure_membership_belongs_to_agency!(@agency, @membership)
    ensure_person_usable!(@person)
    assign_or_confirm!(@person, audit: true)
  end

  def call
    ActiveRecord::Base.transaction do
      ensure_actor_shape!
      perform_locked
    end
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("That person is already linked to a membership.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def perform_locked
    user = @membership.user
    if user&.persisted?
      user.with_lock { lock_agency_and_link }
    else
      lock_agency_and_link
    end
  end

  def lock_agency_and_link
    @agency.lock!
    @agency.reload
    if @membership.persisted?
      @membership.lock!
      @membership.reload
    end
    @membership.user&.reload
    @person.lock! if @person&.persisted?
    @person&.reload

    ensure_membership_belongs_to_agency!(@agency, @membership)
    person = resolve_person
    assign_or_confirm!(person, audit: @audit_link || @membership.person_party_id.blank?)
  end

  def resolve_person
    if @person
      ensure_person_usable!(@person)
      return @person
    end

    allocate_person
  end

  def ensure_person_usable!(person)
    unless person.agency_id == @agency.id
      raise Error.new("That person is not part of this agency.", code: :not_found)
    end

    linked = AgencyMembership.find_by(agency_id: @agency.id, person_party_id: person.party_id)
    return if linked.nil? || linked.id == @membership.id

    raise Error.new("That person is already linked to a membership.", code: :conflict)
  end

  def assign_or_confirm!(person, audit:)
    current_id = @membership.person_party_id
    if current_id.present?
      if current_id == person.party_id
        record_link_audit!(person) if audit
        return CommandResult.new(status: :accepted, membership: @membership, party: person.party)
      end

      raise Error.new("This membership is already linked to a different person.", code: :conflict)
    end

    @membership.person_party = person
    @membership.save!
    record_link_audit!(person)
    CommandResult.new(status: :accepted, membership: @membership, party: person.party)
  end

  def record_link_audit!(person)
    audit!(
      agency: @agency,
      action: "team.person_linked",
      subject: @membership,
      details: {
        "membership_id" => @membership.id,
        "party_id" => person.party_id,
        "source" => @source.to_s
      },
      **actor_audit_args
    )
  end
end
