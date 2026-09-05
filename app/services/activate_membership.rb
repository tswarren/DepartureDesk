class ActivateMembership < MembershipCommand
  def initialize(agency:, membership:, mode:, actor: nil, actor_identifier: nil, privileged: false,
    password: nil, password_confirmation: nil, invitation_token: nil)
    @agency = agency
    @membership = membership
    @user = membership.user
    @mode = mode.to_sym
    @password = password
    @password_confirmation = password_confirmation
    @invitation_token = invitation_token
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction { perform }
    CommandResult.new(status: :accepted, membership: @membership.reload)
  rescue ActiveRecord::RecordNotUnique
    raise unique_conflict_error
  end

  private

  def perform
    ensure_actor_shape! unless accept?

    @user.with_lock do
      @agency.lock!
      @membership.lock!
      @user.reload
      @agency.reload
      @membership.reload

      ensure_membership_belongs_to_agency!(@agency, @membership)
      ensure_tenant_actor!(@agency) unless accept?

      if accept?
        accept_locked!
      else
        reactivate_locked!
      end
    end
  end

  def accept_locked!
    revalidate_invitation_token!
    unless @membership.invitation_open? && @agency.active?
      raise Error.new(AcceptInvitation::GENERIC_FAILURE, code: :invalid_token)
    end
    ensure_no_other_active_membership!(generic: true)

    @user.update!(
      password: @password,
      password_confirmation: @password_confirmation
    )
    @membership.update!(
      status: "active",
      invitation_version: @membership.invitation_version + 1
    )
    audit!(
      agency: @agency,
      action: "team.invitation_accepted",
      actor: @user,
      subject: @membership,
      details: {
        "membership_id" => @membership.id,
        "user_id" => @membership.user_id
      }
    )
  end

  def reactivate_locked!
    unless @membership.suspended?
      raise Error.new("Only a suspended membership can be reactivated.", code: :invalid_state)
    end
    unless @agency.active?
      raise Error.new("This person cannot be reactivated while the agency is not active.", code: :invalid_state)
    end
    ensure_no_other_active_membership!(generic: false)

    @membership.update!(status: "active")
    audit!(
      agency: @agency,
      action: "team.membership_reactivated",
      subject: @membership,
      details: {
        "membership_id" => @membership.id,
        "user_id" => @membership.user_id,
        "previous_status" => "suspended",
        "status" => "active"
      },
      **actor_audit_args
    )
  end

  def revalidate_invitation_token!
    resolved = AgencyMembership.find_by_token_for(:invitation, @invitation_token)
    return if resolved&.id == @membership.id &&
      resolved.invitation_open? &&
      resolved.invitation_version == @membership.invitation_version

    raise Error.new(AcceptInvitation::GENERIC_FAILURE, code: :invalid_token)
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageEncryptor::InvalidMessage
    raise Error.new(AcceptInvitation::GENERIC_FAILURE, code: :invalid_token)
  end

  def ensure_no_other_active_membership!(generic:)
    return unless @user.active_agency_memberships.where.not(id: @membership.id).exists?

    raise unique_conflict_error(generic:)
  end

  def unique_conflict_error(generic: accept?)
    if generic
      Error.new(AcceptInvitation::GENERIC_FAILURE, code: :invalid_token)
    else
      Error.new("This person cannot be reactivated while they have another active membership.", code: :conflict)
    end
  end

  def accept?
    @mode == :accept
  end
end
