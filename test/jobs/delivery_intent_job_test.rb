require "test_helper"

class DeliveryIntentJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @membership = agency_memberships(:one)
    @membership.update!(status: "invited", invitation_version: @membership.invitation_version + 1)
    @intent = DeliveryIntent.create!(
      agency: @membership.agency,
      subject: @membership,
      purpose: "team_invitation",
      subject_version: @membership.invitation_version,
      idempotency_key: "test:#{SecureRandom.uuid}:invitation"
    )
  end

  test "records terminal success and duplicate execution does not deliver again" do
    assert_emails 1 do
      DeliveryIntentJob.new.perform(@intent.id)
      DeliveryIntentJob.new.perform(@intent.id)
    end

    assert_predicate @intent.reload, :succeeded?
    assert_equal 1, @intent.attempt_count
    assert_not_nil @intent.delivered_at
  end

  test "failed delivery is released for an intentional retry" do
    error = assert_raises(RuntimeError) do
      with_raising_mail_delivery do
        DeliveryIntentJob.new.perform(@intent.id)
      end
    end

    assert_equal "provider unavailable", error.message
    assert_predicate @intent.reload, :pending?
    assert_equal 1, @intent.attempt_count
    assert_match "provider unavailable", @intent.last_error

    @intent.update!(available_at: 1.minute.ago)
    DeliveryIntentJob.new.perform(@intent.id)
    assert_predicate @intent.reload, :succeeded?
    assert_equal 2, @intent.attempt_count
  end

  test "an obsolete replacement invitation is discarded without delivery" do
    @membership.increment!(:invitation_version)

    assert_no_emails { DeliveryIntentJob.new.perform(@intent.id) }

    assert_predicate @intent.reload, :discarded?
    assert_match "version", @intent.last_error
  end

  private

  def with_raising_mail_delivery
    ActionMailer::Base.add_delivery_method :raising, RaisingDelivery
    previous = ActionMailer::Base.delivery_method
    ActionMailer::Base.delivery_method = :raising
    yield
  ensure
    ActionMailer::Base.delivery_method = previous
  end

  class RaisingDelivery
    def initialize(*)
    end

    def deliver!(*)
      raise RuntimeError, "provider unavailable"
    end
  end
end
