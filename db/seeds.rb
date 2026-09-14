if Rails.env.development?
  # Development-only credential. Never print this value.
  seed_password = "ChangeMe123!"
  agency = Agency.find_by(workspace_code: "harbor")

  unless agency
    agency = ProvisionAgency.new(
      name: "Harbor Travel",
      workspace_code: "harbor",
      country_code: "US",
      default_currency: "USD",
      default_timezone: "America/New_York",
      office_name: "Harbor Travel",
      office_code: "MAIN",
      office_timezone: "America/New_York",
      administrator_email: "email@example.com",
      administrator_first_name: "Alex",
      administrator_last_name: "Mariner",
      administrator_password: seed_password,
      actor_identifier: "seed:development"
    ).call.record
  end

  office = agency.offices.find_by!(code: "MAIN")
  administrator = agency.agency_users.find_by!(email_address: "email@example.com")

  puts "Seed agency ready:"
  puts "  Name: #{agency.name}"
  puts "  Workspace code: #{agency.workspace_code}"
  puts "  ID: #{agency.id}"
  puts "Seed office ready:"
  puts "  Code: #{office.code}"
  puts "  ID: #{office.id}"
  puts "Seed administrator ready:"
  puts "  Email: #{administrator.email_address}"
  puts "  ID: #{administrator.id}"
end
