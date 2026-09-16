require "test_helper"

class M1DirectoryScenarioTest < ActiveSupport::TestCase
  test "celebrity and vineyard datasets keep named directory shape without trip records" do
    celebrity = M1DirectoryScenario.celebrity
    vineyard = M1DirectoryScenario.vineyard

    assert_equal "Martha Smith", celebrity.martha.display_name
    assert_equal celebrity.martha.id, celebrity.martha_client.client_person_id
    assert_nil celebrity.daniel.client
    assert_nil celebrity.emily.client
    assert_not_equal celebrity.actor.id, celebrity.agency_user_person.id
    assert_equal celebrity.actor.first_name, celebrity.agency_user_person.first_name
    assert_equal "cruise_line", celebrity.celebrity.category_assignments.sole.category_code
    assert_equal 2, celebrity.celebrity.locations.count
    assert celebrity.preferred_contact.reload.preferred?
    assert_equal celebrity.martha_email.address, celebrity.shared_email_contact.email_addresses.sole.address

    client_dupes = FindClientPersonDuplicates.call(
      agency: celebrity.agency,
      actor: celebrity.actor,
      names: { first_name: "Jordan", last_name: "Hotel" },
      emails: [ celebrity.martha_email.address ]
    )
    assert_equal [ celebrity.martha.id ], client_dupes.map(&:id)

    contact_dupes = FindSupplierContactDuplicates.call(
      agency: celebrity.agency,
      actor: celebrity.actor,
      supplier: celebrity.celebrity,
      first_name: "Martha",
      last_name: "Smith",
      emails: [ celebrity.martha_email.address ]
    )
    assert_equal [ celebrity.shared_email_contact.id ], contact_dupes.map(&:id)

    assert_equal "Olivia Brown", vineyard.olivia.display_name
    assert_equal vineyard.westlake.id, vineyard.westlake_client.client_organization_id
    assert vineyard.current_westlake_contact.current?
    assert vineyard.current_westlake_contact.primary?
    assert_not vineyard.historical_westlake_contact.current?
    assert_equal vineyard.noah.id, vineyard.historical_westlake_contact.client_person_id
    assert_equal "tour_operator_dmc", vineyard.vineyard_dmc.category_assignments.sole.category_code
    assert_equal "ground_transportation", vineyard.motorcoach.category_assignments.sole.category_code
    assert_not_equal vineyard.vineyard_dmc.id, vineyard.motorcoach.id

    assert_not Object.const_defined?(:Traveler)
    assert_not vineyard.agency.respond_to?(:departures)
  end

  test "isolation companion shares email and names without leakage or side effects" do
    celebrity = M1DirectoryScenario.celebrity
    companion = M1DirectoryScenario.isolation_companion(celebrity)

    assert_equal celebrity.martha_email.address, companion.martha_email.address
    assert_equal "Martha Smith", companion.martha.display_name
    assert_not_equal celebrity.agency.id, companion.agency.id

    home = SearchClientDirectory.call(
      agency: celebrity.agency, actor: celebrity.actor, query: celebrity.martha_email.address
    )
    away = SearchClientDirectory.call(
      agency: companion.agency, actor: companion.actor, query: celebrity.martha_email.address
    )
    assert_equal [ celebrity.martha.id ], home.records.map(&:id)
    assert_equal [ companion.martha.id ], away.records.map(&:id)

    leaked = FindClientPersonDuplicates.call(
      agency: celebrity.agency,
      actor: celebrity.actor,
      names: { first_name: "Martha", last_name: "Smith" },
      emails: [ celebrity.martha_email.address ]
    )
    assert_equal [ celebrity.martha.id ], leaked.map(&:id)

    audits = AuditEvent.where(agency_id: celebrity.agency.id).count
    assert_raises(ActiveRecord::RecordNotFound) do
      UpdateClientPerson.new(
        agency: celebrity.agency,
        actor: celebrity.actor,
        client_person: companion.martha,
        names: { first_name: "Forged", last_name: "Name" },
        lock_version: companion.martha.lock_version
      ).call
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      ChangeSupplierStatus.new(
        agency: celebrity.agency,
        actor: celebrity.actor,
        supplier: companion.celebrity,
        status: "inactive",
        lock_version: companion.celebrity.lock_version
      ).call
    end
    assert_equal audits, AuditEvent.where(agency_id: celebrity.agency.id).count
    assert_equal "Martha", companion.martha.reload.first_name
    assert_equal "active", companion.celebrity.reload.status
  end
end
