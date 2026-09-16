require "test_helper"

class M3AArrangementConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    suffix = SecureRandom.hex(4)
    @agency = ProvisionAgency.new(
      name: "M3A Race #{suffix}",
      workspace_code: "m#{suffix}",
      country_code: "US",
      default_currency: "USD",
      default_timezone: "UTC",
      office_name: "Race Office",
      office_code: "RACE",
      office_timezone: "UTC",
      administrator_email: "admin-#{suffix}@example.test",
      administrator_first_name: "Race",
      administrator_last_name: "Admin",
      administrator_password: TEST_PASSWORD,
      actor_identifier: "test:m3a-#{suffix}"
    ).call.record
    @actor = @agency.agency_users.sole
    @office = @agency.offices.sole
    ensure_supplier_sequence!(@agency)
    @contractor = create_supplier("Race Contractor").record
    @provider = create_supplier("Race Provider").record
    @departure = create_complete_draft("M3A Draft")
    @arrangement = create_arrangement(name: "Race Arrangement").record
  end

  teardown do
    cleanup_m3a_agency!
    M1DirectoryScenario.cleanup!(@agency) if @agency&.persisted?
  end

  test "supplier inactivation versus arrangement creation serializes dependencies" do
    contractor = create_supplier("Inactivation Contractor").record
    departure = create_complete_draft("Inactivation Race")

    outcomes = race(2, allowed_error_codes: %i[dependency_exists invalid_state]) do |index|
      if index.zero?
        ChangeSupplierStatus.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          supplier: Supplier.find(contractor.id),
          status: "inactive",
          lock_version: contractor.lock_version
        ).call
      else
        CreateSupplierArrangement.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          departure: Departure.find(departure.id),
          idempotency_key: "supplier-status-race",
          attributes: { name: "Late Arrangement", contracting_supplier_id: contractor.id }
        ).call
      end
    end

    contractor.reload
    arrangements = SupplierArrangement.where(contracting_supplier_id: contractor.id)
    if contractor.inactive?
      assert_equal 0, arrangements.count
      assert_includes outcomes.grep(AgencyCommand::Error).map(&:code), :invalid_state
    else
      assert_equal 1, arrangements.count
      assert_includes outcomes.grep(AgencyCommand::Error).map(&:code), :dependency_exists
    end
  end

  test "departure departed transition versus arrangement creation serializes lifecycle" do
    departure = active_eligible_departure("Departed Create Race")

    outcomes = race(2, allowed_error_codes: %i[invalid_state]) do |index|
      if index.zero?
        MarkDepartureDeparted.new(
          agency: Agency.find(@agency.id),
          departure: Departure.find(departure.id),
          actor_kind: :agency_user,
          actor: AgencyUser.find(@actor.id),
          lock_version: departure.lock_version
        ).call
      else
        CreateSupplierArrangement.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          departure: Departure.find(departure.id),
          idempotency_key: "departed-create-race",
          attributes: { name: "Departed Block", contracting_supplier_id: @contractor.id }
        ).call
      end
    end

    departure.reload
    assert_equal "departed", departure.status
    created_count = SupplierArrangement.where(departure_id: departure.id, name: "Departed Block").count
    assert_includes [ 0, 1 ], created_count
    assert_includes outcomes.grep(AgencyCommand::Error).map(&:code), :invalid_state if created_count.zero?
  end

  test "parallel item creation from the same version serializes positions" do
    version = @arrangement.versions.first

    outcomes = race(2, allowed_error_codes: %i[conflict]) do |index|
      CreateArrangementItem.new(
        agency: Agency.find(@agency.id),
        actor: AgencyUser.find(@actor.id),
        arrangement: SupplierArrangement.find(@arrangement.id),
        version_lock_version: version.lock_version,
        idempotency_key: "item-position-race-#{index}",
        attributes: { name: "Race Item #{index}", category: "lodging" }
      ).call
    end

    definitions = @arrangement.versions.first.arrangement_item_definitions.order(:position)
    created = outcomes.grep(AgencyCommand::Result)
    assert_includes [ 1, 2 ], created.size
    assert_equal created.size, definitions.count
    assert_equal definitions.count, definitions.pluck(:position).uniq.size
    assert_equal created.size, AuditEvent.where(agency_id: @agency.id, action: "supplier_arrangement.item_created", subject_id: @arrangement.id).count
  end

  test "abandon arrangement versus item creation leaves one coherent winner" do
    version = @arrangement.versions.first

    outcomes = race(2, allowed_error_codes: %i[conflict invalid_state]) do |index|
      if index.zero?
        AbandonSupplierArrangement.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          arrangement: SupplierArrangement.find(@arrangement.id),
          reason: "Supplier withdrew",
          arrangement_lock_version: @arrangement.lock_version,
          version_lock_version: version.lock_version
        ).call
      else
        CreateArrangementItem.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          arrangement: SupplierArrangement.find(@arrangement.id),
          version_lock_version: version.lock_version,
          idempotency_key: "abandon-item-race",
          attributes: { name: "Last Item", category: "lodging" }
        ).call
      end
    end

    @arrangement.reload
    version.reload
    item_count = ArrangementItem.where(supplier_arrangement_id: @arrangement.id).count
    if @arrangement.abandoned?
      assert_equal "abandoned", version.status
      assert_equal 0, item_count
      assert_equal 1, AuditEvent.where(agency_id: @agency.id, action: "supplier_arrangement.abandoned", subject_id: @arrangement.id).count
    else
      assert_equal "draft", version.status
      assert_equal 1, item_count
      assert_includes outcomes.grep(AgencyCommand::Error).map(&:code), :conflict
    end
  end

  test "parallel same idempotency key arrangement creation replays one result" do
    key = "same-arrangement-key"
    departure = create_complete_draft("Same Key Race")

    outcomes = race(2) do
      CreateSupplierArrangement.new(
        agency: Agency.find(@agency.id),
        actor: AgencyUser.find(@actor.id),
        departure: Departure.find(departure.id),
        idempotency_key: key,
        attributes: { name: "Same Key Arrangement", contracting_supplier_id: @contractor.id }
      ).call
    end

    results = outcomes.grep(AgencyCommand::Result)
    assert_equal %i[created replayed], results.map(&:status).sort
    assert_equal 1, results.map { |result| result.record.id }.uniq.size
    arrangement = results.first.record
    assert_equal 1, SupplierArrangement.where(departure_id: departure.id, name: "Same Key Arrangement").count
    assert_equal 1, AgencyCommandIdempotencyKey.where(agency_id: @agency.id, command_name: "CreateSupplierArrangement", idempotency_key: key).count
    assert_equal 1, AuditEvent.where(agency_id: @agency.id, action: "supplier_arrangement.created", subject_id: arrangement.id).count
  end

  test "parallel reorders from the same version lock conflict cleanly" do
    first = create_item("First Reorder Item").record
    second = create_item("Second Reorder Item").record
    version = @arrangement.versions.first.reload

    outcomes = race(2, allowed_error_codes: %i[conflict]) do |index|
      order = index.zero? ? [ second.id, first.id ] : [ first.id, second.id ]
      ReorderArrangementItems.new(
        agency: Agency.find(@agency.id),
        actor: AgencyUser.find(@actor.id),
        arrangement: SupplierArrangement.find(@arrangement.id),
        version_lock_version: version.lock_version,
        arrangement_item_ids: order
      ).call
    end

    assert_equal 1, outcomes.grep(AgencyCommand::Result).size
    assert_equal [ :conflict ], outcomes.grep(AgencyCommand::Error).map(&:code)
    assert_equal 2, @arrangement.versions.first.arrangement_item_definitions.count
    assert_equal 1, AuditEvent.where(agency_id: @agency.id, action: "supplier_arrangement.items_reordered", subject_id: @arrangement.id).count
  end

  private

  def create_arrangement(name:, idempotency_key: SecureRandom.uuid, departure: @departure, contractor: @contractor)
    CreateSupplierArrangement.new(
      agency: @agency,
      actor: @actor,
      departure: departure,
      idempotency_key: idempotency_key,
      attributes: { name: name, contracting_supplier_id: contractor.id }
    ).call
  end

  def create_item(name)
    version = @arrangement.versions.first.reload
    CreateArrangementItem.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: { name: name, category: "lodging", default_service_provider_id: @provider.id }
    ).call
  end

  def create_supplier(display_name)
    CreateSupplier.new(
      agency: @agency,
      actor: @actor,
      kind: "organization",
      names: { display_name: display_name },
      categories: [ "lodging" ]
    ).call
  end

  def create_complete_draft(name, starts_on: Date.new(2026, 10, 1), ends_on: Date.new(2026, 10, 8))
    CreateDeparture.new(
      agency: @agency,
      actor: @actor,
      attributes: {
        name: name,
        starts_on: starts_on,
        ends_on: ends_on,
        time_zone: "UTC",
        operating_currency: "USD",
        responsible_office_id: @office.id,
        responsible_agency_user_id: @actor.id
      },
      current_office: @office
    ).call.record
  end

  def active_eligible_departure(name)
    departure = create_complete_draft(name, starts_on: Date.current - 7.days, ends_on: Date.current + 7.days)
    ActivateDeparture.new(agency: @agency, actor: @actor, departure: departure, lock_version: departure.lock_version).call.record
  end

  def ensure_supplier_sequence!(agency)
    agency.reference_sequences.find_or_create_by!(namespace: ReferenceSequence::SUPPLIER_NAMESPACE) do |sequence|
      sequence.next_value = 1
    end
  end

  def race(count, allowed_error_codes: [])
    ready = Queue.new
    release = Queue.new
    threads = count.times.map do |index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          release.pop
          yield index
        end
      rescue StandardError => error
        error
      end
    end
    count.times { ready.pop }
    count.times { release << true }
    outcomes = threads.map(&:value)
    outcomes.each { |outcome| assert_expected_race_outcome!(outcome, allowed_error_codes:) }
    outcomes
  end

  def assert_expected_race_outcome!(outcome, allowed_error_codes:)
    return if outcome.is_a?(AgencyCommand::Result)
    return if outcome.is_a?(AgencyCommand::Error) && allowed_error_codes.include?(outcome.code)

    raise outcome if outcome.is_a?(Exception)

    flunk "unexpected race outcome: #{outcome.inspect}"
  end

  def cleanup_m3a_agency!
    return unless @agency&.id

    agency_id = @agency.id
    SupplierResourceDefinition.where(agency_id: agency_id).delete_all
    ServiceOccurrenceDefinition.where(agency_id: agency_id).delete_all
    ArrangementItemDefinition.where(agency_id: agency_id).delete_all
    SupplierResource.where(agency_id: agency_id).delete_all
    ServiceOccurrence.where(agency_id: agency_id).delete_all
    ArrangementItem.where(agency_id: agency_id).delete_all
    SupplierArrangementVersion.where(agency_id: agency_id).delete_all
    SupplierArrangement.where(agency_id: agency_id).delete_all
    AgencyCommandIdempotencyKey.where(agency_id: agency_id).delete_all
  end
end
