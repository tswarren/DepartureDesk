require "test_helper"

class ResetPasswordTest < ActiveSupport::TestCase
  setup do
    @user = agency_users(:harbor_staff)
    @token = @user.issue_password_reset_token
    @user.save!
    @digest = @user.password_reset_token_digest
  end

  test "a token issued before agency suspension cannot change the password" do
    ChangeAgencyStatus.new(agency: agencies(:harbor), status: "suspended", actor_identifier: "test:ops").call

    assert_reset_rejected
  end

  test "a token issued before agency closure cannot change the password" do
    ChangeAgencyStatus.new(agency: agencies(:harbor), status: "closed", actor_identifier: "test:ops").call

    assert_reset_rejected
  end

  private

  def assert_reset_rejected
    assert_no_difference -> { AuditEvent.where(action: "agency_user.password_reset").count } do
      error = assert_raises(AgencyCommand::Error) do
        ResetPassword.new(token: @token, password: "replacement123", password_confirmation: "replacement123").call
      end
      assert_equal :invalid, error.code
    end

    @user.reload
    assert_equal @digest, @user.password_reset_token_digest
    assert @user.authenticate(ActiveSupport::TestCase::TEST_PASSWORD)
    assert_not @user.authenticate("replacement123")
  end
end
