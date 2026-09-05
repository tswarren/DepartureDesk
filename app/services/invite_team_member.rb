class InviteTeamMember < MembershipCommand
  def initialize(agency:, email:, role:, first_name:, last_name:, preferred_name: nil, actor: nil, actor_identifier: nil)
    @agency = agency
    @actor = actor
    @actor_identifier = actor_identifier
    @email = email.to_s.strip.downcase
    @role = role
    @first_name = first_name
    @last_name = last_name
    @preferred_name = preferred_name
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
    membership.update!(
      role: @role,
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

  def create_membership_for(user)
    membership = @agency.agency_memberships.create!(
      user: user,
      role: @role,
      status: "invited",
      invitation_sent_at: Time.current
    )
    record_created(membership)
  end

  def create_user_and_membership
    generated_password = SecureRandom.hex(32)
    user = User.create!(
      email_address: @email,
      first_name: @first_name,
      last_name: @last_name,
      preferred_name: @preferred_name,
      password: generated_password,
      password_confirmation: generated_password
    )
    create_membership_for(user)
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
