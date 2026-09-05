class AcceptInvitation < MembershipCommand
  GENERIC_FAILURE = "This invitation is invalid or has expired."

  def initialize(token:, password:, password_confirmation:)
    @token = token
    @password = password
    @password_confirmation = password_confirmation
  end

  def call
    membership = locate_membership
    raise Error.new(GENERIC_FAILURE, code: :invalid_token) unless membership

    ActiveRecord::Base.transaction do
      with_agency_membership_lock(membership.agency, membership) do
        accept!(membership)
      end
    end

    membership.user.sessions.delete_all
    CommandResult.new(status: :accepted, membership: membership.reload)
  end

  private

  def locate_membership
    AgencyMembership.find_by_token_for(:invitation, @token)
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  def accept!(membership)
    unless membership.invitation_open? && membership.agency.active?
      raise Error.new(GENERIC_FAILURE, code: :invalid_token)
    end

    if membership.user.active_agency_memberships.where.not(id: membership.id).exists?
      raise Error.new(GENERIC_FAILURE, code: :invalid_token)
    end

    membership.user.update!(
      password: @password,
      password_confirmation: @password_confirmation
    )
    membership.update!(
      status: "active",
      invitation_version: membership.invitation_version + 1
    )
    audit!(
      agency: membership.agency,
      action: "team.invitation_accepted",
      actor: membership.user,
      subject: membership,
      details: {
        "membership_id" => membership.id,
        "user_id" => membership.user_id
      }
    )
  end
end
