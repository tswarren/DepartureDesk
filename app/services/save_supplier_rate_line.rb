# Adds or edits one row of a Draft arrangement's supplier rate table
# (SUP-35). Amounts arrive as typed and are parsed strictly in the
# arrangement currency (ADR 0001). Once the arrangement leaves Draft the
# table is frozen (ADR 0018).
class SaveSupplierRateLine < AgencyCommand
  include ArrangementCommandSupport

  AMOUNTS = {
    "base_fare" => "base_fare_minor_units",
    "non_commissionable_fees" => "non_commissionable_fees_minor_units",
    "taxes" => "taxes_minor_units",
    "discount" => "discount_minor_units",
    "commission_amount" => "commission_minor_units"
  }.freeze
  AMOUNT_LABELS = {
    "base_fare" => "Base fare", "non_commissionable_fees" => "Non-commissionable fees", "taxes" => "Taxes",
    "discount" => "Discount", "commission_amount" => "Commission amount"
  }.freeze
  FIELDS = %w[inventory_group_id occupancy_position traveler_type_id commission_rate commission_base].concat(AMOUNTS.keys).freeze
  RATE_FORMAT = /\A\d{1,3}(?:\.\d{1,3})?\z/

  def initialize(agency:, actor:, departure:, arrangement:, attributes:, rate_line: nil, lock_version: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @rate_line = rate_line
    @attributes = attributes.to_h.stringify_keys.slice(*FIELDS).transform_values { |value| value.is_a?(String) ? value.strip.presence : value }
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:manage_arrangements)

    ActiveRecord::Base.transaction do
      departure = lock_arrangement_context!
      arrangement = lock_arrangement!(departure)
      raise Error.new("The rate table can change only while the arrangement is a draft.", code: :invalid_state) unless arrangement.draft?

      line = @rate_line ? locked_line(arrangement) : arrangement.rate_lines.new(agency: @agency, currency: arrangement.currency)
      creating = line.new_record?
      line.assign_attributes(line_attributes(arrangement, line))
      changed = line.changed - %w[lock_version updated_at]
      return Result.new(status: :noop, record: line) if !creating && changed.empty?

      line.save!
      audit!(
        agency: @agency, action: creating ? "supplier_arrangement.rate_line_added" : "supplier_arrangement.rate_line_updated",
        subject: arrangement, actor: @actor,
        details: { "supplier_rate_line_id" => line.id, "inventory_group_id" => line.inventory_group_id,
                   "occupancy_position" => line.occupancy_position, "traveler_type_id" => line.traveler_type_id, "changed" => changed.sort }
      )
      Result.new(status: creating ? :created : :updated, record: line)
    end
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("This group already has a rate for that occupancy position and traveler type.", code: :invalid)
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def locked_line(arrangement)
    arrangement.rate_lines.lock.find(@rate_line.id).tap do |line|
      raise Error.new(STALE_MESSAGE, code: :conflict) if @lock_version.blank? || line.lock_version != @lock_version.to_i
    end
  end

  def line_attributes(arrangement, line)
    group = if line.new_record?
      arrangement.inventory_groups.find_by(id: parse_optional_uuid(@attributes["inventory_group_id"], "Inventory group"))
    elsif @attributes["inventory_group_id"].nil? || @attributes["inventory_group_id"] == line.inventory_group_id
      line.inventory_group
    else
      raise Error.new("A rate stays in its inventory group; remove it and add one to the other group.", code: :invalid)
    end
    raise Error.new("Choose one of this arrangement's inventory groups.", code: :invalid) if group.nil?

    position = @attributes["occupancy_position"]
    raise Error.new("Choose an occupancy position.", code: :invalid) unless SupplierRateLine::OCCUPANCY_POSITIONS.include?(position)

    traveler_type = nil
    if @attributes["traveler_type_id"]
      traveler_type = @agency.traveler_types.find_by(id: parse_optional_uuid(@attributes["traveler_type_id"], "Traveler type"))
      raise Error.new("Choose one of the agency's traveler types.", code: :invalid) if traveler_type.nil?
    end

    amounts = AMOUNTS.to_h { |field, column| [ column, parse_amount(field, arrangement.currency) ] }
    raise Error.new("Base fare is required; enter 0 if the supplier charges none.", code: :invalid) if amounts["base_fare_minor_units"].nil?

    %w[non_commissionable_fees_minor_units taxes_minor_units discount_minor_units].each { |column| amounts[column] ||= 0 }
    attrs = { "occupancy_position" => position, "traveler_type" => traveler_type, "commission_rate" => parse_rate,
              "commission_base" => parse_commission_base(line) }.merge(amounts)
    line.new_record? ? attrs.merge("inventory_group" => group) : attrs
  end

  def parse_amount(field, currency)
    MoneyInput.minor_units(@attributes[field], currency)
  rescue MoneyInput::Invalid
    raise Error.new("#{AMOUNT_LABELS.fetch(field)} must be an amount in #{currency}, such as 1234.50.", code: :invalid)
  end

  def parse_commission_base(line)
    base = @attributes["commission_base"] || line.commission_base || "base_fare"
    raise Error.new("Choose what the commission rate applies to.", code: :invalid) unless SupplierRateLine::COMMISSION_BASES.include?(base)

    base
  end

  def parse_rate
    value = @attributes["commission_rate"]
    return nil if value.nil?

    rate = value.to_s.delete_suffix("%").strip
    unless rate.match?(RATE_FORMAT) && BigDecimal(rate) <= 100
      raise Error.new("Commission rate must be a percentage from 0 to 100, with up to three decimal places.", code: :invalid)
    end
    BigDecimal(rate)
  end
end
