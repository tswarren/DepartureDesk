require "test_helper"

# SMN-05: the hourly sweep posts what has fallen due, as the system, once.
class PostDueSupplierAmountsJobTest < ActiveJob::TestCase
  setup do
    set_clock Time.utc(2026, 10, 15, 14)
    @alpha = AlphaFixture.load!(agency: agencies(:harbor), actor: agency_users(:harbor_admin))
  end

  test "the sweep enqueues one job per confirmed arrangement with schedule lines, on the supplier_money queue" do
    assert_enqueued_jobs 3, only: PostArrangementAmountsDueJob, queue: "supplier_money" do
      PostDueSupplierAmountsJob.perform_now
    end
  end

  test "posting runs as the system and is idempotent" do
    set_clock Time.utc(2026, 11, 1, 14)
    perform_enqueued_jobs { PostDueSupplierAmountsJob.perform_now }
    perform_enqueued_jobs { PostDueSupplierAmountsJob.perform_now }
    amount = AmountDue.where(supplier_arrangement: @alpha.arrangements.values).sole
    assert_equal [ 160_000, 32, SupplierAmountPosting::SYSTEM_ACTOR_IDENTIFIER ], amount.values_at(:amount_minor_units, :quantity, :posted_by_identifier)
  end

  test "the Service date event is recorded once the first service date arrives" do
    set_clock Time.utc(2027, 11, 5, 14)
    perform_enqueued_jobs { PostDueSupplierAmountsJob.perform_now }
    hotel = @alpha.arrangements.fetch(:hotel)
    assert_equal [ Date.new(2027, 11, 1) ], hotel.trigger_events.where(event_type: "service_date").pluck(:occurred_on)
  end
end
