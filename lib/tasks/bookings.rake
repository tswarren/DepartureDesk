# D-94 (2), step 8 plan question 2: installments for bookings confirmed
# before build step 8. Idempotent; prints counts only.
namespace :bookings do
  desc "Create installments for confirmed bookings that have none"
  task create_missing_installments: :environment do
    created = 0
    ClientBooking.where(status: "confirmed").includes(:agency, client_charge: :installments).find_each do |booking|
      next if booking.client_charge.nil? || booking.client_charge.installments.any?

      result = CreateBookingInstallments.new(agency: booking.agency, booking:).call
      created += 1 if result.status == :created
    end
    puts "Created installments for #{created} confirmed #{created == 1 ? "booking" : "bookings"}."
  end
end
