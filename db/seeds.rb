if Rails.env.development?
    seed_user = User.find_or_initialize_by(
      email_address: "email@example.com"
    )

    seed_user.assign_attributes(
      first_name: "Alex",
      last_name: "Mariner",
      password: "ChangeMe123!",
      password_confirmation: "ChangeMe123!"
    )

    seed_user.save!

    membership = seed_user.active_agency_memberships.includes(:agency).first

    if membership
      seed_agency = membership.agency
    else
      seed_agency = Agency.find_or_initialize_by(name: "Harbor Travel")
      seed_agency.assign_attributes(
        default_timezone: "UTC",
        default_currency: "USD",
        country_code: "US",
        status: "active"
      )
      seed_agency.save!

      membership = AgencyMembership.find_or_initialize_by(
        user: seed_user,
        agency: seed_agency
      )
      membership.assign_attributes(
        role: "administrator",
        status: "active"
      )
    end

    if membership.person_party_id.blank?
      person = LinkMembershipPerson.allocate_person(
        agency: seed_agency,
        given_name: seed_user.first_name,
        family_name: seed_user.last_name,
        actor_identifier: "seed:development",
        privileged: true
      )
      membership.person_party = person
    end

    membership.save!

    if membership.saved_change_to_person_party_id?
      LinkMembershipPerson.record_locked!(
        agency: seed_agency,
        membership: membership,
        person: membership.person_party,
        source: "seed",
        actor_identifier: "seed:development",
        privileged: true
      )
    end

    puts "Seed agency ready:"
    puts "  Name: #{seed_agency.name}"
    puts "  ID: #{seed_agency.id}"
    puts "Seed user ready:"
    puts "  Email: #{seed_user.email_address}"
    puts "  ID: #{seed_user.id}"
    office = seed_agency.offices.find_or_initialize_by(code: "MAIN")
    office.assign_attributes(
      name: seed_agency.name,
      status: "active",
      default_timezone: seed_agency.default_timezone
    )
    office.save!

    assignment = OfficeAssignment.find_or_initialize_by(
      agency: seed_agency,
      agency_membership: membership,
      office: office
    )
    assignment.assign_attributes(
      status: "active",
      is_default: true,
      granted_at: assignment.granted_at || Time.current,
      revoked_at: nil
    )
    assignment.save!

    puts "Seed membership ready:"
    puts "  ID: #{membership.id}"
    puts "  Role: #{membership.role}"
    puts "  Status: #{membership.status}"
    puts "Seed office ready:"
    puts "  Code: #{office.code}"
    puts "  ID: #{office.id}"

    demo_person = seed_agency.parties.find_by(display_name: "Alex Morgan")
    unless demo_person
      demo_person = CreateParty.new(
        agency: seed_agency,
        party_kind: "person",
        attributes: { given_name: "Alex", family_name: "Morgan" },
        actor_identifier: "seed:development",
        privileged: true
      ).call.party
    end
    demo_household = seed_agency.parties.find_by(display_name: "Morgan Household")
    unless demo_household
      demo_household = CreateParty.new(
        agency: seed_agency,
        party_kind: "household",
        attributes: { name: "Morgan Household" },
        actor_identifier: "seed:development",
        privileged: true
      ).call.party
    end
    unless demo_person.contact_points.email.any?
      CreatePartyContactPoint.new(
        agency: seed_agency,
        party: demo_person,
        contact_kind: "email",
        attributes: { display_address: "alex.directory@example.test", email_type: "personal" },
        actor_identifier: "seed:development",
        privileged: true
      ).call
    end
    unless PartyRelationship.involving(demo_person).exists?(relationship_kind: "household_member")
      CreatePartyRelationship.new(
        agency: seed_agency,
        origin_party: demo_person,
        related_party: demo_household,
        relationship_kind: "household_member",
        actor_identifier: "seed:development",
        privileged: true
      ).call
    end
    unless demo_person.notes.exists?
      CreatePartyNote.new(
        agency: seed_agency,
        party: demo_person,
        body: "Prefers morning calls for trip updates.",
        visibility: "standard",
        actor_identifier: "seed:development",
        privileged: true
      ).call
    end
    puts "Seed directory demo ready:"
    puts "  Person: #{demo_person.display_name} (#{demo_person.id})"
    puts "  Household: #{demo_household.display_name} (#{demo_household.id})"
end
