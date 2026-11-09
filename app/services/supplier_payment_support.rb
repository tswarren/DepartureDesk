# Shared steps for supplier payment commands (SMN-17 to SMN-19, SMN-22,
# SMN-23). They need Financial records and lock agency, Departure, then each
# arrangement the payment touches, in id order, so posting and paying one
# arrangement are ordered.
module SupplierPaymentSupport
  include ReferenceIssuance

  SETTLE_IDENTIFIER = "supplier_money.settle"

  private

  def ensure_supplier_payment_actor!
    ensure_directory_actor!(@actor, @agency, :manage_supplier_payments)
    ensure_active_agency!(@agency)
  end

  def lock_supplier_context!(departure, supplier)
    @agency.lock!
    locked = @agency.departures.lock.find(departure.id)
    arrangements = locked.supplier_arrangements.where(supplier:).order(:id).lock.to_a
    raise AgencyCommand::Error.new("This supplier has no arrangement on this Departure.", code: :invalid) if arrangements.empty?

    [ locked, arrangements ]
  end

  # The supplier's open amounts due on the Departure, oldest due first.
  def open_amounts(arrangements)
    AmountDue.where(supplier_arrangement: arrangements).includes(:payment_applications, :schedule_line, :task).by_due.to_a.select { |amount| amount.open_minor_units.positive? }
  end

  def supplier_applications_from(rows, amounts, currency)
    by_id = amounts.index_by(&:id)
    Array(rows).filter_map do |row|
      row = row.to_h.stringify_keys
      amount = supplier_money!(row["amount"], currency, "Amount applied") or next
      next if amount.zero?

      due = by_id[row["amount_due_id"]] or raise AgencyCommand::Error.new("Each amount due must be this supplier's, on this Departure, and still open.", code: :invalid)
      if amount > due.open_minor_units
        raise AgencyCommand::Error.new("#{due.description} has #{Money.new(due.open_minor_units, currency).format} open; apply no more than that.", code: :invalid)
      end
      [ due, amount ]
    end
  end

  def supplier_money!(value, currency, label)
    MoneyInput.minor_units(value, currency)
  rescue MoneyInput::Invalid
    raise AgencyCommand::Error.new("#{label} must be an amount in #{currency}, such as 2950.00.", code: :invalid)
  end

  def supplier_date!(value, label)
    return Clock.current.today_in(@agency.default_timezone) if value.blank?

    date = Date.iso8601(value.to_s)
    raise AgencyCommand::Error.new("#{label} can't be in the future.", code: :invalid) if date > Clock.current.today_in(@agency.default_timezone)

    date
  rescue Date::Error
    raise AgencyCommand::Error.new("#{label} must be a date, such as 2027-02-03.", code: :invalid)
  end

  # SMN-17: a payment task completes, as the system, once everything its
  # schedule line has posted is settled and the line can post no more; a
  # direct amount's task, once that amount is settled.
  def settle_tasks!(departure, amounts)
    amounts.group_by(&:schedule_line).each do |line, rows|
      if line.nil?
        rows.each { |amount| complete_settled!(amount.task) if amount.reload.paid_status == "paid" }
        next
      end
      line_amounts = line.amounts_due.reload.includes(:payment_applications)
      next unless line_amounts.all? { |amount| amount.paid_status == "paid" } && exhausted?(line)

      complete_settled!(line.task || line.supplier_deadline&.task)
    end
  end

  def exhausted?(line)
    return line.amounts_due.any? unless line.per_shell?
    return false unless line.due_rule.in?(%w[fixed_date earlier_of]) && line.due_on <= Clock.current.today_in(@agency.default_timezone)

    taken = line.amounts_due.map(&:unit_shell_id)
    UnitShell.joins(:inventory_group).where(inventory_groups: { supplier_arrangement_id: line.supplier_arrangement_id })
      .then { |shells| line.inventory_group_id ? shells.where(inventory_group_id: line.inventory_group_id) : shells }
      .includes(:capacity_events).reject(&:returned_to_supplier?).all? { |shell| taken.include?(shell.id) }
  end

  # Completed as the system, so the audit names supplier_money.settle, not the payer.
  def complete_settled!(task)
    return unless task&.active?

    task.update!(status: "completed", completion_note: "Settled by supplier payment.", completed_at: Clock.current.now)
    audit!(agency: @agency, action: "departure.task_completed", subject: task.departure, actor_identifier: SETTLE_IDENTIFIER,
      details: { "task_id" => task.id, "schedule_line_id" => task.schedule_line_id, "supplier_deadline_id" => task.supplier_deadline_id,
                 "amount_due_id" => task.amount_due_id, "note" => task.completion_note }.compact)
  end
end
