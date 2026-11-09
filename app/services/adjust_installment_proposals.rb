# Adjusts a draft booking's proposed installments before acceptance (CMN-09;
# step 8 plan, question 1): their amounts and due dates, which must still
# total the booking's price. The acceptance fingerprint covers them, so an
# adjustment makes an earlier acceptance stale (BKG-39).
class AdjustInstallmentProposals < AgencyCommand
  include BookingCommandSupport

  def initialize(agency:, actor:, booking:, rows:)
    @agency = agency
    @actor = actor
    @booking = booking
    @rows = Array(rows).map { |row| row.to_h.stringify_keys }
  end

  def call
    ensure_actor!

    ActiveRecord::Base.transaction do
      booking = lock_booking!
      ensure_draft!(booking)
      proposals = booking.installment_proposals.to_a
      raise Error.new("This booking has no proposed installments yet.", code: :invalid_state) if proposals.empty?

      changes = proposals.map { |proposal| [ proposal, values_for(proposal, booking.currency) ] }
      total = booking.price_lines.sum(&:amount_minor_units)
      planned = changes.sum { |_, values| values[:amount_minor_units] }
      if planned != total
        raise Error.new("The installments total #{Money.new(planned, booking.currency).format}; they must total the price, #{Money.new(total, booking.currency).format}.", code: :invalid)
      end

      changed = changes.select { |proposal, values| proposal.assign_attributes(values.merge(adjusted: true)) && (proposal.changed - %w[adjusted]).any? }
      return Result.new(status: :noop, record: booking) if changed.empty?

      changes.each { |proposal, _| proposal.save! }
      audit_booking!(booking, "client_booking.installments_adjusted", "installment_proposal_ids" => changed.map { |proposal, _| proposal.id })
      Result.new(status: :updated, record: booking)
    end
  end

  private

  def values_for(proposal, currency)
    row = @rows.find { |candidate| candidate["id"] == proposal.id } || {}
    amount = begin
      MoneyInput.minor_units(row.fetch("amount", MoneyInput.display(proposal.amount_minor_units, currency)), currency)
    rescue MoneyInput::Invalid
      raise Error.new("#{proposal.description}: amount must be an amount in #{currency}.", code: :invalid)
    end
    raise Error.new("#{proposal.description}: amount is required; enter 0 for none.", code: :invalid) if amount.nil?

    if row["due"] == "at_confirmation"
      { amount_minor_units: amount, due_kind: "at_confirmation", due_on: nil }
    else
      due_on = row.key?("due_on") ? parse_due(row["due_on"], proposal) : proposal.due_on
      due_on ? { amount_minor_units: amount, due_kind: "on_date", due_on: } : { amount_minor_units: amount, due_kind: "at_confirmation", due_on: nil }
    end
  end

  def parse_due(value, proposal)
    return nil if value.blank?

    Date.iso8601(value.to_s)
  rescue Date::Error
    raise Error.new("#{proposal.description}: due date must be a date, such as 2027-07-09.", code: :invalid)
  end
end
