require "test_helper"

class DeliveryIntentTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "domain rollback also rolls back its delivery intent" do
    assert_no_difference %w[AgencyMembership.count DeliveryIntent.count] do
      AgencyMembership.transaction do
        InviteTeamMember.new(
          agency: agencies(:one), actor: users(:one), email: "rollback@example.com",
          role: "staff", first_name: "Roll", last_name: "Back", **invite_offices
        ).call
        raise ActiveRecord::Rollback
      end
    end
  end

  test "enqueue failure leaves the committed intent pending for reconciliation" do
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = RaisingEnqueueAdapter.new

    assert_difference("DeliveryIntent.pending.count", 1) do
      InviteTeamMember.new(
        agency: agencies(:one), actor: users(:one), email: "recover@example.com",
        role: "staff", first_name: "Process", last_name: "Recovery", **invite_offices
      ).call
    end
  ensure
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  test "replacement invitation versions have distinct idempotency keys" do
    membership = InviteTeamMember.new(
      agency: agencies(:one), actor: users(:one), email: "versions@example.com",
      role: "staff", first_name: "Version", last_name: "Test", **invite_offices
    ).call.membership
    first = DeliveryIntent.find_by!(subject: membership)

    ReplaceInvitation.new(agency: agencies(:one), actor: users(:one), membership: membership).call
    intents = DeliveryIntent.where(subject: membership).order(:subject_version)

    assert_equal [ 0, 1 ], intents.pluck(:subject_version)
    assert_not_equal first.idempotency_key, intents.last.idempotency_key
  end

  test "password reset issuance and intent commit together and rotate the token version" do
    user = users(:one)
    old_version = user.password_reset_version

    assert_difference("DeliveryIntent.password_reset.count", 1) do
      IssuePasswordReset.new(user: user).call
    end

    assert_equal old_version + 1, user.reload.password_reset_version
    assert_equal user.password_reset_version, DeliveryIntent.password_reset.last.subject_version
  end

  class RaisingEnqueueAdapter
    def enqueue(*)
      raise ActiveJob::EnqueueError, "queue unavailable"
    end

    def enqueue_at(*)
      raise ActiveJob::EnqueueError, "queue unavailable"
    end
  end
end
