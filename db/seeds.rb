require_relative "seeds/alpha_fixture"

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
      administrator_email: "email@example.com",
      administrator_first_name: "Alex",
      administrator_last_name: "Mariner",
      administrator_password: seed_password,
      actor_identifier: "seed:development"
    ).call.record
  end

  administrator = agency.agency_users.find_by!(email_address: "email@example.com")

  puts "Seed agency ready:"
  puts "  Name: #{agency.name}"
  puts "  Workspace code: #{agency.workspace_code}"
  puts "  ID: #{agency.id}"
  puts "Seed administrator ready:"
  puts "  Email: #{administrator.email_address}"
  puts "  ID: #{administrator.id}"

  alpha = AlphaFixture.load!(agency:, actor: administrator, bookings: :confirmed)
  puts "Alpha fixture ready:"
  alpha.suppliers.each_value { |supplier| puts "  Supplier: #{supplier.display_name} (#{supplier.supplier_reference})" }
  puts "  Departure: #{alpha.departure.name} #{alpha.departure.departure_reference} (#{alpha.departure.summary_label_text})"
  alpha.arrangements.each_value { |arrangement| puts "  Arrangement: #{arrangement.arrangement_reference} #{arrangement.supplier.display_name} (#{arrangement.status})" }
  alpha.trips.each { |label, trip| puts "  Trip: #{trip.trip_reference} #{trip.client.source.display_name} (roster #{label})" }
  alpha.bookings.each { |label, booking| puts "  Booking: #{booking.booking_reference} (roster #{label}, #{booking.status})" }
end
