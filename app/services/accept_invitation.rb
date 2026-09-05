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

    after_locate(membership)

    result = ActivateMembership.new(
      agency: membership.agency,
      membership: membership,
      mode: :accept,
      invitation_token: @token,
      password: @password,
      password_confirmation: @password_confirmation
    ).call

    membership.user.sessions.delete_all
    result
  end

  private

  def locate_membership
    AgencyMembership.find_by_token_for(:invitation, @token)
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  def after_locate(_membership)
  end
end
