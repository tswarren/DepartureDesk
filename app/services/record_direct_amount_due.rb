# Records a straightforward supplier obligation directly as an amount due,
# without a cost line or schedule (SMN-05), with its payment task (SMN-17).
class RecordDirectAmountDue < AgencyCommand
  include ArrangementCommandSupport
  include SupplierMoneyCommandSupport
  include TaskCommandSupport

  def initialize(agency:, actor:, departure:, arrangement:, attributes:)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @attributes = attributes.to_h.stringify_keys.slice("description", "amount", "due_on").transform_values { |value| value.is_a?(String) ? value.strip.presence : value }
  end

  def call
    ensure_departure_actor!(:record_amounts_due)

    ActiveRecord::Base.transaction do
      lock_authorized_agency!(:record_amounts_due)
      departure = @agency.departures.lock.find(@departure.id)
      arrangement = departure.supplier_arrangements.lock.find(@arrangement.id)
      raise Error.new("Amounts due are recorded once the arrangement is confirmed.", code: :invalid_state) unless arrangement.confirmed?

      due_on = parse_date(@attributes["due_on"], "Due date") or raise Error.new("Due date is required.", code: :invalid)
      amount = arrangement.amounts_due.create!(
        agency: @agency, description: @attributes["description"].to_s, due_on:, currency: arrangement.currency,
        amount_minor_units: parse_money!("amount", "Amount", arrangement.currency, required: true),
        posted_at: Clock.current.now, posted_by: @actor
      )
      create_payment_task!(departure, action: "#{arrangement.supplier.display_name}: #{amount.description}", due_on:,
        source: "amount_due", amount_due: amount)
      audit!(agency: @agency, action: "supplier_arrangement.amount_due_recorded", subject: arrangement, actor: @actor,
        details: { "amount_due_id" => amount.id, "amount_minor_units" => amount.amount_minor_units, "currency" => amount.currency, "due_on" => due_on.iso8601 })
      Result.new(status: :created, record: amount)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
