# Records or changes a cost line (SMN-02, SUP-13). A commitment for unsold
# space is a committed line naming its shells (D-75); confirmation never
# infers one. A line is fixed once an amount due posts against it, and a
# percentage line follows its base line until then.
class SaveCostLine < AgencyCommand
  include ArrangementCommandSupport
  include SupplierMoneyCommandSupport

  FIELDS = %w[scope inventory_group_id unit_shell_ids description basis rate quantity percentage base_cost_line_id stage].freeze

  def initialize(agency:, actor:, departure:, arrangement:, attributes:, cost_line: nil, lock_version: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @cost_line = cost_line
    @attributes = attributes.to_h.stringify_keys.slice(*FIELDS).transform_values { |value| value.is_a?(String) ? value.strip.presence : value }
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:manage_arrangements)

    ActiveRecord::Base.transaction do
      departure = lock_arrangement_context!
      arrangement = lock_arrangement!(departure)
      ensure_open_arrangement!(arrangement)

      line = @cost_line ? locked_line(arrangement) : arrangement.cost_lines.new(agency: @agency, currency: arrangement.currency)
      creating = line.new_record?
      raise Error.new("An amount due has posted against this cost line, so it can't change.", code: :invalid_state) if !creating && line.posted?
      if line.scoped_to_client_booking?
        raise Error.new("This cost line came from booking #{line.client_booking.booking_reference}'s confirmation; change it from the booking.", code: :invalid_state)
      end

      shells = assign!(arrangement, line)
      changed = line.changed - %w[lock_version updated_at]
      shells_changed = shells && shells.map(&:id).sort != line.unit_shell_ids.sort
      return Result.new(status: :noop, record: line) if !creating && changed.empty? && !shells_changed

      line.save!
      if shells
        line.cost_line_shells.where.not(unit_shell_id: shells.map(&:id)).delete_all
        (shells.map(&:id) - line.cost_line_shells.pluck(:unit_shell_id)).each { |id| line.cost_line_shells.create!(agency: @agency, unit_shell_id: id) }
        line.cost_line_shells.reset
        line.unit_shells.reset
      end
      refresh_dependents!(line)
      audit!(
        agency: @agency, action: creating ? "supplier_arrangement.cost_line_added" : "supplier_arrangement.cost_line_updated",
        subject: arrangement, actor: @actor,
        details: { "cost_line_id" => line.id, "stage" => line.stage, "amount_minor_units" => line.amount_minor_units,
                   "currency" => line.currency, "unit_shell_ids" => shells&.map(&:id), "changed" => changed.sort }.compact
      )
      Result.new(status: creating ? :created : :updated, record: line)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def locked_line(arrangement)
    arrangement.cost_lines.lock.find(@cost_line.id).tap do |line|
      raise Error.new(STALE_MESSAGE, code: :conflict) if @lock_version.blank? || line.lock_version != @lock_version.to_i
    end
  end

  # Assigns everything but the shells, which it returns for a unit_shells line.
  def assign!(arrangement, line)
    scope = @attributes["scope"] || line.scope
    raise Error.new("Choose what the cost line covers.", code: :invalid) unless CostLine::SCOPES.include?(scope)

    basis = @attributes["basis"] || line.basis
    raise Error.new("Choose the cost line's basis.", code: :invalid) unless CostLine::BASES.include?(basis)

    stage = @attributes["stage"] || line.stage
    raise Error.new("Choose estimated or committed.", code: :invalid) unless CostLine::STAGES.include?(stage)

    group = scope == "inventory_group" ? find_in!(arrangement.inventory_groups, "inventory_group_id", "Inventory group") : nil
    raise Error.new("Choose the inventory group the cost line covers.", code: :invalid) if scope == "inventory_group" && group.nil?

    shells = scope == "unit_shells" ? selected_shells(arrangement) : nil
    line.assign_attributes(scope:, basis:, stage:, inventory_group: group, description: @attributes.fetch("description", line.description))
    assign_amount!(arrangement, line, basis, shells)
    shells
  end

  def selected_shells(arrangement)
    ids = Array(@attributes["unit_shell_ids"]).compact_blank
    raise Error.new("Choose the shells the cost line covers.", code: :invalid) if ids.empty?

    ids.each { |id| parse_optional_uuid(id, "Unit shell") }
    shells = UnitShell.joins(:inventory_group).where(inventory_groups: { supplier_arrangement_id: arrangement.id }, id: ids).to_a
    raise Error.new("Choose shells from this arrangement.", code: :invalid) if shells.size != ids.uniq.size

    shells
  end

  def assign_amount!(arrangement, line, basis, shells)
    currency = arrangement.currency
    case basis
    when "fixed"
      rate = parse_money!("rate", "Amount", currency, required: true)
      line.assign_attributes(rate_minor_units: rate, quantity: nil, percentage: nil, base_cost_line: nil, amount_minor_units: rate)
    when *CostLine::QUANTITY_BASES
      rate = parse_money!("rate", "Rate", currency, required: true)
      quantity = @attributes["quantity"].blank? && shells ? shells.size : parse_count!("quantity", "Quantity")
      line.assign_attributes(rate_minor_units: rate, quantity:, percentage: nil, base_cost_line: nil, amount_minor_units: rate * quantity)
    when "percentage"
      base = find_in!(arrangement.cost_lines.where.not(id: line.id), "base_cost_line_id", "Cost line")
      raise Error.new("Choose the cost line the percentage applies to.", code: :invalid) if base.nil?
      raise Error.new("A percentage can't be based on another percentage line.", code: :invalid) if base.basis_percentage?

      percentage = parse_percentage!("percentage")
      line.assign_attributes(rate_minor_units: nil, quantity: nil, percentage:, base_cost_line: base,
        amount_minor_units: percentage_of(base.amount_minor_units, percentage))
    end
  end

  # Rounding (ADR 0001): exact decimal arithmetic, half up to the minor unit.
  def percentage_of(base, percentage)
    (BigDecimal(base) * percentage / 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
  end

  def refresh_dependents!(line)
    line.dependent_cost_lines.lock.each do |dependent|
      next if dependent.posted?

      dependent.update!(amount_minor_units: percentage_of(line.amount_minor_units, dependent.percentage))
    end
  end
end
