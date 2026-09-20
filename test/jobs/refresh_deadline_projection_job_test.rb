# frozen_string_literal: true

require "test_helper"

class RefreshDeadlineProjectionJobTest < ActiveSupport::TestCase
  test "retries deadlock-class errors five times and does not discard them" do
    assert_equal :deadlines, RefreshDeadlineProjectionJob.new.queue_name.to_sym
    retryable = [
      ActiveRecord::Deadlocked,
      ActiveRecord::SerializationFailure,
      ActiveRecord::LockWaitTimeout
    ].map(&:name)
    handlers = RefreshDeadlineProjectionJob.rescue_handlers.map { |handler| handler.first.to_s }
    retryable.each { |name| assert_includes handlers, name }
  end
end
