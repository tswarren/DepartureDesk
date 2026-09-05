require "test_helper"
require "rake"

class DeliveryIntentsTaskTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("delivery_intents:reconcile")
    @task = Rake::Task["delivery_intents:reconcile"]
    @task.reenable
  end

  test "reconciliation recovers a stale claim and enqueues it" do
    membership = agency_memberships(:one)
    membership.update!(status: "invited")
    intent = DeliveryIntent.create!(
      agency: membership.agency,
      subject: membership,
      purpose: "team_invitation",
      subject_version: membership.invitation_version,
      idempotency_key: "reconcile:#{SecureRandom.uuid}",
      status: "processing",
      claimed_at: 30.minutes.ago
    )

    assert_enqueued_with(job: DeliveryIntentJob, args: [ intent.id ]) { @task.invoke }
    assert_predicate intent.reload, :pending?
    assert_nil intent.claimed_at
  end
end
