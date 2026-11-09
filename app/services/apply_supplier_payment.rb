# Applies a supplier's unapplied payments to its open amounts due on the
# Departure (SMN-19, SMN-22), oldest payment first, as staff confirm.
# Financial records only.
class ApplySupplierPayment < AgencyCommand
  include SupplierPaymentSupport

  def initialize(agency:, actor:, departure:, supplier:, applications:)
    @agency = agency
    @actor = actor
    @departure = departure
    @supplier = supplier
    @applications = applications
  end

  def call
    ensure_supplier_payment_actor!

    ActiveRecord::Base.transaction do
      departure, arrangements = lock_supplier_context!(@departure, @supplier)
      currency = arrangements.first.currency
      applications = supplier_applications_from(@applications, open_amounts(arrangements), currency)
      raise Error.new("Enter an amount to apply.", code: :invalid) if applications.empty?

      payments = departure.supplier_payments.where(supplier: @supplier).includes(:applications, :reversal).to_a.select { |payment| payment.unapplied_minor_units.positive? }
      available = payments.sum(&:unapplied_minor_units)
      if applications.sum(&:last) > available
        raise Error.new("#{@supplier.display_name_for_directory} has #{Money.new(available, currency).format} unapplied; apply no more than that.", code: :invalid)
      end

      created = applications.flat_map do |due, amount|
        payments.each_with_object([]) do |payment, rows|
          take = [ amount, payment.unapplied_minor_units ].min
          next if take.zero?

          rows << payment.applications.create!(agency: @agency, amount_due: due, amount_minor_units: take, recorded_by: @actor, created_at: Clock.current.now)
          amount -= take
          break rows if amount.zero?
        end
      end
      settle_tasks!(departure, applications.map(&:first))
      created.group_by(&:supplier_payment).each do |payment, rows|
        audit!(agency: @agency, action: "supplier_payment.applied", subject: payment, actor: @actor,
          details: { "supplier_payment_id" => payment.id, "application_ids" => rows.map(&:id), "applied_minor_units" => rows.sum(&:amount_minor_units) })
      end
      Result.new(status: :updated, record: created)
    end
  end
end
