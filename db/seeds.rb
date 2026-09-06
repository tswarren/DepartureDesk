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

    LinkMembershipPerson.new(
      agency: seed_agency,
      membership: membership,
      person: membership.person_party,
      source: "seed",
      audit_link: membership.saved_change_to_person_party_id?,
      actor_identifier: "seed:development",
      privileged: true
    ).call

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
end
