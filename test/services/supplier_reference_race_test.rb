require "test_helper"

class SupplierReferenceRaceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @agency = ProvisionAgency.new(
      name: "Supplier Race #{SecureRandom.hex(3)}",
      workspace_code: "sup#{SecureRandom.hex(3)}",
      country_code: "US",
      default_currency: "USD",
      default_timezone: "UTC",
      office_name: "Race Office",
      office_code: "RACE",
      office_timezone: "UTC",
      administrator_email: "supplier-race@example.com",
      administrator_first_name: "Sup",
      administrator_last_name: "Admin",
      administrator_password: "race-password1",
      actor_identifier: "test:supplier-reference-race"
    ).call.record
    @actor = @agency.agency_users.sole
  end

  teardown do
    return unless @agency

    Agency.transaction do
      ActiveRecord::Base.connection.execute("SET LOCAL session_replication_role = replica")
      agency_id = @agency.id
      user_ids = AgencyUser.where(agency_id: agency_id).pluck(:id)
      SupplierWebsite.where(agency_id: agency_id).delete_all
      SupplierPostalAddress.where(agency_id: agency_id).delete_all
      SupplierPhoneNumber.where(agency_id: agency_id).delete_all
      SupplierEmailAddress.where(agency_id: agency_id).delete_all
      SupplierCategoryAssignment.where(agency_id: agency_id).delete_all
      Supplier.where(agency_id: agency_id).delete_all
      ReferenceSequence.where(agency_id: agency_id).delete_all
      AuditEvent.where(agency_id: agency_id).delete_all
      Session.where(agency_user_id: user_ids).delete_all
      AgencyUser.where(id: user_ids).delete_all
      Office.where(agency_id: agency_id).delete_all
      Agency.where(id: agency_id).delete_all
    end
  end

  test "parallel supplier creation issues distinct references" do
    started = Queue.new
    results = 2.times.map do |index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          started.pop
          CreateSupplier.new(
            agency: Agency.find(@agency.id),
            actor: AgencyUser.find(@actor.id),
            kind: "organization",
            names: { display_name: "Racer #{index}" },
            categories: [ "air" ]
          ).call
        end
      end
    end
    2.times { started << true }
    created = results.map(&:value)

    references = created.map { |result| result.record.supplier_reference }
    assert_equal references.uniq.size, references.size
    assert_equal 2, @agency.suppliers.count
  end

  test "parallel duplicate-token replay creates one supplier reference and audit set" do
    CreateSupplier.new(
      agency: @agency,
      actor: @actor,
      kind: "organization",
      names: { display_name: "Parallel Cruise" },
      categories: [ "cruise_line" ]
    ).call

    error = assert_raises(AgencyCommand::DuplicateReviewRequired) do
      CreateSupplier.new(
        agency: @agency,
        actor: @actor,
        kind: "organization",
        names: { display_name: "Parallel Cruise" },
        categories: [ "cruise_line" ]
      ).call
    end

    started = Queue.new
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          started.pop
          CreateSupplier.new(
            agency: Agency.find(@agency.id),
            actor: AgencyUser.find(@actor.id),
            kind: "organization",
            names: { display_name: "Parallel Cruise" },
            categories: [ "cruise_line" ],
            acknowledgement_token: error.token,
            acknowledgement_reason: "confirmed_distinct"
          ).call
        end
      end
    end
    2.times { started << true }
    outcomes = threads.map(&:value)

    statuses = outcomes.map(&:status).sort
    assert_equal %i[created replayed], statuses
    assert_equal 1, outcomes.map { |result| result.record.id }.uniq.size
    assert_equal 2, @agency.suppliers.count
    assert_equal 1, AuditEvent.where(agency_id: @agency.id, action: "supplier.created", subject_id: outcomes.first.record.id).count
    assert_equal 1, AuditEvent.where(agency_id: @agency.id, action: "supplier.duplicate_override", subject_id: outcomes.first.record.id).count
  end
end
