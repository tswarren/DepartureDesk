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
      membership.save!
    end

    puts "Seed agency ready:"
    puts "  Name: #{seed_agency.name}"
    puts "  ID: #{seed_agency.id}"
    puts "Seed user ready:"
    puts "  Email: #{seed_user.email_address}"
    puts "  ID: #{seed_user.id}"
    puts "Seed membership ready:"
    puts "  ID: #{membership.id}"
    puts "  Role: #{membership.role}"
    puts "  Status: #{membership.status}"
end
