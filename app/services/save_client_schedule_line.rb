# Adds or edits a line of a Departure's client payment schedule template
# (CMN-09, D-76, D-77): basis, amount or percentage, due rule, and whether
# it is the designated payment that counts as acceptance (BKG-41).
class SaveClientScheduleLine < AgencyCommand
  include ClientTermsCommandSupport

  FIELDS = %w[description basis service_category amount percentage due_rule days_before_departure due_on counts_as_acceptance].freeze

  def initialize(agency:, actor:, departure:, terms_version:, attributes:, line: nil, lock_version: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @terms_version = terms_version
    @line = line
    @attributes = clean(attributes, FIELDS)
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:manage_departures)

    ActiveRecord::Base.transaction do
      departure = lock_offering_context!
      version = lock_terms_version!(departure)
      line = if @line
        version.schedule_lines.lock.find(@line.id).tap { |record| ensure_version!(record) }
      else
        version.schedule_lines.new(agency: @agency, currency: departure.operating_currency, position: version.schedule_lines.maximum(:position).to_i + 1)
      end
      creating = line.new_record?
      assign!(line, departure.operating_currency)
      changed = line.changed - %w[lock_version updated_at position]
      return Result.new(status: :noop, record: line) if !creating && changed.empty?

      line.save!
      audit_departure!(departure, "departure.client_schedule_line_saved",
        "client_terms_version_id" => version.id, "client_payment_schedule_line_id" => line.id, "created" => creating, "changed" => changed.sort)
      Result.new(status: creating ? :created : :updated, record: line)
    end
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("The schedule already has a balance line or a payment that counts as acceptance.", code: :invalid)
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def assign!(line, currency)
    basis = @attributes["basis"]
    raise Error.new("Choose how the amount is worked out.", code: :invalid) unless ClientPaymentScheduleLine::BASES.include?(basis)

    rule = @attributes["due_rule"]
    raise Error.new("Choose when it falls due.", code: :invalid) unless ClientPaymentScheduleLine::DUE_RULES.include?(rule)

    line.assign_attributes(
      description: @attributes["description"], basis:, due_rule: rule,
      service_category: basis == "per_unit" ? @attributes["service_category"] : nil,
      amount_minor_units: basis.in?(%w[per_traveler per_unit per_booking]) ? parse_amount(@attributes["amount"], currency) : nil,
      percentage: basis == "percentage" ? parse_percentage(@attributes["percentage"]) : nil,
      days_before_departure: rule == "days_before_departure" ? days! : nil,
      due_on: rule == "fixed_date" ? (parse_date(@attributes["due_on"], "Due date") or raise Error.new("Due date is required.", code: :invalid)) : nil,
      counts_as_acceptance: ActiveModel::Type::Boolean.new.cast(@attributes["counts_as_acceptance"]) || false
    )
    if line.basis_per_unit? && !InventoryGroup::SERVICE_CATEGORIES.include?(line.service_category)
      raise Error.new("Choose the service category whose units it counts.", code: :invalid)
    end
  end

  def days!
    days = Integer(@attributes["days_before_departure"].to_s, exception: false)
    raise Error.new("Days before departure must be a whole number of 0 or more.", code: :invalid) if days.nil? || days.negative?

    days
  end
end
