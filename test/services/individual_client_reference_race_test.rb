require "test_helper"

class IndividualClientReferenceRaceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @agency = ProvisionAgency.new(
      name: "Reference Race #{SecureRandom.hex(3)}",
      workspace_code: "ref#{SecureRandom.hex(3)}",
      country_code: "US",
      default_currency: "USD",
      default_timezone: "UTC",
      office_name: "Race Office",
      office_code: "RACE",
      office_timezone: "UTC",
      administrator_email: "ref@example.com",
      administrator_first_name: "Ref",
      administrator_last_name: "Admin",
      administrator_password: "race-password1",
      actor_identifier: "test:reference-race"
    ).call.record
    @actor = @agency.agency_users.sole
  end

  teardown do
    return unless @agency

    Agency.transaction do
      ActiveRecord::Base.connection.execute("SET LOCAL session_replication_role = replica")
      agency_id = @agency.id
      user_ids = AgencyUser.where(agency_id: agency_id).pluck(:id)
      ClientPersonEmailAddress.where(agency_id: agency_id).delete_all
      ClientPersonPhoneNumber.where(agency_id: agency_id).delete_all
      ClientPersonPostalAddress.where(agency_id: agency_id).delete_all
      Client.where(agency_id: agency_id).delete_all
      ClientPerson.where(agency_id: agency_id).delete_all
      ReferenceSequence.where(agency_id: agency_id).delete_all
      AuditEvent.where(agency_id: agency_id).delete_all
      Session.where(agency_user_id: user_ids).delete_all
      AgencyUser.where(id: user_ids).delete_all
      Office.where(agency_id: agency_id).delete_all
      Agency.where(id: agency_id).delete_all
    end
  end

  test "parallel client creation issues distinct references" do
    started = Queue.new
    results = 2.times.map do |index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          started.pop
          CreateIndividualClient.new(
            agency: Agency.find(@agency.id),
            actor: AgencyUser.find(@actor.id),
            names: { first_name: "Racer", last_name: index.to_s }
          ).call
        end
      end
    end
    2.times { started << true }
    created = results.map { |thread| thread.value }

    references = created.map { |result| result.record.client_reference }
    assert_equal references.uniq.size, references.size
    assert_equal 2, @agency.clients.count
  end
end
