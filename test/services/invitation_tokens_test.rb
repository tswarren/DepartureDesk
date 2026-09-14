require "test_helper"

class InvitationTokensTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  test "a replaced invitation token cannot activate the user" do
    user = agency_users(:harbor_invited)
    previous = "invite-token-harbor"
    replacement = nil

    assert_emails 1 do
      result = ReplaceAgencyUserInvitation.new(agency_user: user, actor: agency_users(:harbor_admin)).call
      replacement = mail_token(ActionMailer::Base.deliveries.last)
      assert_equal :accepted, result.status
    end

    assert_raises(AgencyCommand::Error) do
      AcceptAgencyUserInvitation.new(token: previous, password: "accepted-pass1", password_confirmation: "accepted-pass1").call
    end
    assert user.reload.invited?

    AcceptAgencyUserInvitation.new(token: replacement, password: "accepted-pass1", password_confirmation: "accepted-pass1").call
    assert user.reload.active?
    assert_nil user.invitation_token_digest
    assert user.authenticate("accepted-pass1")
  end

  test "a revoked invitation closes the user and rejects the token" do
    user = agency_users(:harbor_invited)
    RevokeAgencyUserInvitation.new(agency_user: user, actor: agency_users(:harbor_admin)).call

    assert user.reload.closed?
    assert_nil user.invitation_token_digest
    error = assert_raises(AgencyCommand::Error) do
      AcceptAgencyUserInvitation.new(token: "invite-token-harbor", password: "accepted-pass1", password_confirmation: "accepted-pass1").call
    end
    assert_equal :invalid, error.code
  end

  test "a duplicate email is a same-agency conflict and does not mention another agency" do
    error = assert_raises(AgencyCommand::Error) do
      InviteAgencyUser.new(
        agency: agencies(:harbor),
        actor: agency_users(:harbor_admin),
        email_address: "Alex@Example.com",
        first_name: "Alex",
        last_name: "Again",
        access_role: "staff"
      ).call
    end

    assert_equal "That email address is already used in this agency.", error.message
    assert_no_match(/cove/i, error.message)
  end

  private

  def mail_token(mail)
    body = mail.text_part&.body&.to_s || mail.body.to_s
    body[/invitation_acceptances\/([^\/\s]+)/, 1]
  end
end
