require "test_helper"

class MarkEligibleDeparturesDepartedJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @office = offices(:harbor_main)
  end

  test "sweep enqueues child jobs and does not call the command" do
    departure = eligible_active("Sweep One")
    assert_no_difference -> { AuditEvent.where(action: "departure.departed").count } do
      assert_enqueued_with job: MarkDepartureDepartedJob, args: [ { agency_id: @agency.id, departure_id: departure.id } ] do
        MarkEligibleDeparturesDepartedJob.perform_now
      end
    end
    assert_equal "active", departure.reload.status
  end

  test "sweep skips suspended agencies and does not load inactive candidates" do
    departure = eligible_active("Suspended Sweep")
    @agency.update!(status: "suspended")
    begin
      assert_no_enqueued_jobs only: MarkDepartureDepartedJob do
        MarkEligibleDeparturesDepartedJob.perform_now
      end
      assert_equal "active", departure.reload.status
    ensure
      @agency.update!(status: "active")
    end
  end

  test "sweep pages with a keyset of at most 100 then enqueues" do
    assert_equal 100, MarkEligibleDeparturesDepartedJob::BATCH_SIZE
    source = File.read(Rails.root.join("app/jobs/mark_eligible_departures_departed_job.rb"))
    assert_no_match(/transaction/, source)
    stub_const(MarkEligibleDeparturesDepartedJob, :BATCH_SIZE, 1) do
      3.times { |index| eligible_active("Batch #{index}") }
      assert_enqueued_jobs 3, only: MarkDepartureDepartedJob do
        MarkEligibleDeparturesDepartedJob.perform_now
      end
    end
  end

  test "recurring configuration and worker recognize the departures queue" do
    recurring = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true)
    %w[development production].each do |env|
      task = recurring.fetch(env).fetch("mark_eligible_departures_departed")
      assert_equal "MarkEligibleDeparturesDepartedJob", task.fetch("class")
      assert_equal "departures", task.fetch("queue")
      assert_equal "every hour", task.fetch("schedule")
    end
    queues = YAML.load_file(Rails.root.join("config/queue.yml"), aliases: true)
    assert_equal "*", queues.fetch("development").fetch("workers").first.fetch("queues")
    assert_path_exists Rails.root.join("bin/jobs")
    assert_match(/SolidQueue::Cli/, File.read(Rails.root.join("bin/jobs")))
    configuration = SolidQueue::Configuration.new
    worker = configuration.configured_processes.find { |process| process.kind == :worker }
    assert_not_nil worker
    assert_equal "*", Array(worker.attributes[:queues]).flatten.first.to_s
    assert_equal :departures, MarkEligibleDeparturesDepartedJob.new.queue_name.to_sym
    assert_equal :departures, MarkDepartureDepartedJob.new.queue_name.to_sym
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
