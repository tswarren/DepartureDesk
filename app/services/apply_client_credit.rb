# Applies a Client Trip's credit to its installments (CMN-23, CMN-24; step
# 8 plan, question 4): from its payments' unapplied amounts, oldest payment
# first, as staff confirm. Financial records only.
class ApplyClientCredit < AgencyCommand
  include ClientMoneySupport

  def initialize(agency:, actor:, trip:, applications:)
    @agency = agency
    @actor = actor
    @trip = trip
    @applications = applications
  end

  def call
    ensure_money_actor!

    ActiveRecord::Base.transaction do
      trip = lock_trip!(@trip)
      currency = @departure.operating_currency
      applications = applications_from(@applications, trip_installments(trip), currency)
      raise Error.new("Enter an amount to apply.", code: :invalid) if applications.empty?

      payments = trip.client_payments.includes(:applications, :reversal).to_a.select { |payment| payment.credit_minor_units.positive? }
      credit = payments.sum(&:credit_minor_units)
      if applications.sum(&:last) > credit
        raise Error.new("The trip has #{Money.new(credit, currency).format} of credit; apply no more than that.", code: :invalid)
      end

      created = applications.flat_map do |installment, amount|
        payments.each_with_object([]) do |payment, rows|
          take = [ amount, payment.credit_minor_units ].min
          next if take.zero?

          rows << payment.applications.create!(agency: @agency, installment:, amount_minor_units: take, recorded_by: @actor, created_at: Clock.current.now)
          amount -= take
          break rows if amount.zero?
        end
      end
      created.group_by(&:client_payment).each do |payment, rows|
        audit!(agency: @agency, action: "client_payment.applied", subject: payment, actor: @actor,
          details: { "client_payment_id" => payment.id, "application_ids" => rows.map(&:id), "applied_minor_units" => rows.sum(&:amount_minor_units) })
      end
      Result.new(status: :updated, record: created)
    end
  end
end
