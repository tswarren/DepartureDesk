# Adds or edits a choice in an offering (BKG-14 to BKG-16): its role,
# scope and pattern. Optional multiple applies only to add-ons.
class SaveOfferingChoice < AgencyCommand
  include OfferingCommandSupport

  FIELDS = %w[name role scope pattern].freeze

  def initialize(agency:, actor:, departure:, offering:, attributes:, choice: nil, lock_version: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @offering = offering
    @choice = choice
    @attributes = clean(attributes, FIELDS)
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:manage_departures)

    ActiveRecord::Base.transaction do
      departure = lock_offering_context!
      offering = lock_offering!(departure)
      choice = if @choice
        offering.choices.lock.find(@choice.id).tap { |record| ensure_version!(record) }
      else
        offering.choices.new(agency: @agency, position: offering.choices.maximum(:position).to_i + 1)
      end
      creating = choice.new_record?
      choice.assign_attributes(@attributes)
      changed = choice.changed - %w[lock_version updated_at position]
      return Result.new(status: :noop, record: choice) if !creating && changed.empty?

      choice.save!
      audit_departure!(departure, creating ? "departure.offering_choice_added" : "departure.offering_choice_updated",
        "offering_id" => offering.id, "offering_choice_id" => choice.id, "name" => choice.name, "changed" => changed.sort)
      Result.new(status: creating ? :created : :updated, record: choice)
    end
  rescue ArgumentError => error
    raise Error.new(error.message, code: :invalid)
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
