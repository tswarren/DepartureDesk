class InviteTeamMember < MembershipCommand
  def initialize(agency:, email:, role:, first_name:, last_name:, preferred_name: nil,
    person_party_id: nil, office_ids: [], default_office_id: nil, actor: nil,
    actor_identifier: nil, privileged: false)
    @agency = agency
    @email = email.to_s.strip.downcase
    @role = role
    @first_name = first_name
    @last_name = last_name
    @preferred_name = preferred_name
    @person_party_id = person_party_id.presence
    @office_ids = Array(office_ids).compact_blank.uniq
    @default_office_id = default_office_id
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    result = nil

    ActiveRecord::Base.transaction do
      result = with_agency_membership_lock(@agency) { perform }
      record_delivery_intent(result)
    end

    result
  end

  private

  def record_delivery_intent(result)
    return unless result&.enqueue_mail?

    DeliveryIntent.record!(
      agency: @agency,
      subject: result.membership,
      purpose: "team_invitation",
      version: result.membership.invitation_version
    )
  end

  def perform
    existing_user = User.find_by(email_address: @email)

    if existing_user && user_has_foreign_active_membership?(existing_user, @agency)
      return CommandResult.new(status: :silent, message: ELIGIBLE_INVITE_NOTICE)
    end

    if existing_user
      membership = @agency.agency_memberships.find_by(user: existing_user)
      return handle_existing_membership(membership) if membership
      return create_membership_for(existing_user)
    end

    create_user_and_membership
  end

  def handle_existing_membership(membership)
    membership.lock!

    if @person_party_id.present? && membership.person_party_id != @person_party_id
      raise Error.new("That email already belongs to a different person in this agency.", code: :conflict)
    end

    if membership.active? || membership.suspended?
      return CommandResult.new(
        status: :already_member,
        membership: membership,
        message: "That person is already on the team."
      )
    end

    replace_invitation(membership)
  end

  def replace_invitation(membership)
    membership.update!(role: @role)
    assign_offices!(membership)
    membership.update!(
      status: "invited",
      invitation_version: membership.invitation_version + 1,
      invitation_sent_at: Time.current
    )
    audit!(
      agency: @agency,
      action: "team.invitation_replaced",
      subject: membership,
      details: { "membership_id" => membership.id, "user_id" => membership.user_id, "role" => membership.role },
      **actor_audit_args
    )
    CommandResult.new(status: :replaced, membership: membership, message: ELIGIBLE_INVITE_NOTICE)
  end

  def create_membership_for(user, person = nil)
    person ||= resolve_person!
    membership = @agency.agency_memberships.create!(
      user: user,
      role: @role,
      status: "invited",
      invitation_sent_at: Time.current,
      person_party: person
    )
    LinkMembershipPerson.new(
      agency: @agency,
      membership: membership,
      person: person,
      source: "invitation",
      audit_link: true,
      actor: @actor,
      actor_identifier: @actor_identifier,
      privileged: @privileged
    ).call
    assign_offices!(membership)
    record_created(membership)
  end

  def resolve_person!
    if @person_party_id.present?
      person = @agency.people.find_by(party_id: @person_party_id)
      raise Error.new("That person is not part of this agency.", code: :not_found) unless person

      linked = @agency.agency_memberships.find_by(person_party_id: person.party_id)
      raise Error.new("That person is already linked to a membership.", code: :conflict) if linked

      return person
    end

    LinkMembershipPerson.allocate_person(
      agency: @agency,
      given_name: @first_name,
      family_name: @last_name,
      preferred_name: @preferred_name,
      actor: @actor,
      actor_identifier: @actor_identifier,
      privileged: @privileged
    )
  end

  def assign_offices!(membership)
    active_offices = @agency.offices.active
    intended_ids = @office_ids.map(&:to_s)
    intended_ids |= [ @default_office_id.to_s ] if @default_office_id.present?

    if active_offices.exists?
      if membership.staff? && (intended_ids.empty? || @default_office_id.blank?)
        raise Error.new("Choose at least one office and a default.", code: :invalid)
      end
      if membership.administrator? && @default_office_id.blank?
        raise Error.new("Choose a default office.", code: :invalid)
      end
    elsif membership.staff?
      raise Error.new("Staff cannot be invited until an office exists.", code: :invalid)
    else
      return
    end

    intended_offices = intended_ids.map do |office_id|
      office = active_offices.find_by(id: office_id)
      raise Error.new("That office is not part of this agency.", code: :invalid) unless office

      office
    end

    intended_offices.each do |office|
      GrantOfficeAccess.new(
        agency: @agency,
        membership: membership,
        office: office,
        make_default: office.id.to_s == @default_office_id.to_s,
        actor: @actor,
        actor_identifier: @actor_identifier,
        privileged: @privileged
      ).call
    end

    membership.office_assignments.active.where.not(office_id: intended_ids).order(:id).find_each do |assignment|
      RevokeOfficeAccess.new(
        agency: @agency,
        membership: membership,
        office: assignment.office,
        replacement_office: intended_offices.find { |office| office.id.to_s == @default_office_id.to_s },
        actor: @actor,
        actor_identifier: @actor_identifier,
        privileged: @privileged
      ).call
    end
  end

  def create_user_and_membership
    person = resolve_person!
    generated_password = SecureRandom.hex(32)
    user = User.create!(
      email_address: @email,
      first_name: @first_name.presence || person.given_name,
      last_name: @last_name.presence || person.family_name,
      preferred_name: @preferred_name.presence || person.preferred_name,
      password: generated_password,
      password_confirmation: generated_password
    )
    create_membership_for(user, person)
  end

  def record_created(membership)
    audit!(
      agency: @agency,
      action: "team.invitation_created",
      subject: membership,
      details: { "membership_id" => membership.id, "user_id" => membership.user_id, "role" => membership.role },
      **actor_audit_args
    )
    CommandResult.new(status: :created, membership: membership, message: ELIGIBLE_INVITE_NOTICE)
  end
end
