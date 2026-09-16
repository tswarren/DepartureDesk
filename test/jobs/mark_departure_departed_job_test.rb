require "test_helper"

class MarkDepartureDepartedJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @office = offices(:harbor_main)
  end

  test "job reloads through the agency and marks departed as system" do
    departure = eligible_active("Job Path")
    MarkDepartureDepartedJob.perform_now(agency_id: @agency.id, departure_id: departure.id)
    departure.reload
    assert_equal "departed", departure.status
    event = AuditEvent.find_by!(action: "departure.departed", subject_id: departure.id)
    assert_equal "system", event.actor_kind
    assert_equal "departures.mark_departed", event.actor_identifier
  end

  test "missing or inactive agencies complete without a domain audit" do
    departure = eligible_active("Gone Agency")
    assert_no_difference -> { AuditEvent.where(action: "departure.departed").count } do
      MarkDepartureDepartedJob.perform_now(agency_id: SecureRandom.uuid, departure_id: departure.id)
      MarkDepartureDepartedJob.perform_now(agency_id: @agency.id, departure_id: SecureRandom.uuid)
      @agency.update!(status: "suspended")
      begin
        MarkDepartureDepartedJob.perform_now(agency_id: @agency.id, departure_id: departure.id)
      ensure
        @agency.update!(status: "active")
      end
    end
    assert_equal "active", departure.reload.status
  end

  test "unexpected invalid errors are logged with identifiers and are not audited" do
    departure = eligible_active("Logged Invalid")
    io = StringIO.new
    previous_logger = Rails.logger
    Rails.logger = ActiveSupport::BroadcastLogger.new(Logger.new(io))
    fake_command = Class.new(MarkDepartureDeparted) do
      def initialize(**); end
      def call
        raise AgencyCommand::Error.new("bad invocation", code: :invalid)
      end
    end
    begin
      stub_const(Object, :MarkDepartureDeparted, fake_command) do
        MarkDepartureDepartedJob.perform_now(agency_id: @agency.id, departure_id: departure.id)
      end
    ensure
      Rails.logger = previous_logger
    end
    assert_match @agency.id, io.string
    assert_match departure.id, io.string
    assert_match "invalid", io.string
    assert_equal 0, AuditEvent.where(action: "departure.departed", subject_id: departure.id).count
  end

  test "retries deadlock-class errors five times and does not discard them" do
    assert_equal :departures, MarkDepartureDepartedJob.new.queue_name.to_sym
    retryable = [ ActiveRecord::Deadlocked, ActiveRecord::SerializationFailure, ActiveRecord::LockWaitTimeout ].map(&:name)
    handlers = MarkDepartureDepartedJob.rescue_handlers.map { |handler| handler.first.to_s }
    retryable.each { |name| assert_includes handlers, name }
  end

  private

  def eligible_active(name)
    departure = CreateDeparture.new(
      agency: @agency,
      actor: @admin,
      attributes: {
        name:,
        starts_on: Date.new(2026, 6, 1),
        ends_on: Date.new(2026, 6, 8),
        time_zone: "UTC",
        operating_currency: "USD",
        responsible_office_id: @office.id,
        responsible_agency_user_id: @admin.id
      }
    ).call.record
    ActivateDeparture.new(agency: @agency, actor: @admin, departure:, lock_version: departure.lock_version).call.record
  end
end
