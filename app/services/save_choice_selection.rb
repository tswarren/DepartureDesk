# Chooses an option on a draft booking (BKG-14 to BKG-16), with its
# occupants for a per-unit choice or its participants for a per-traveler
# one (step 6 plan, question 19). Re-proposes prices and re-holds what
# changed (questions 14 and 15).
class SaveChoiceSelection < AgencyCommand
  include BookingCommandSupport

  def initialize(agency:, actor:, booking:, attributes:, selection: nil, lock_version: nil)
    @agency = agency
    @actor = actor
    @booking = booking
    @selection = selection
    @option_id = attributes.to_h.stringify_keys["offering_option_id"].presence
    @occupant_ids = Array(attributes.to_h.stringify_keys["occupant_ids"]).compact_blank
    @lock_version = lock_version
  end

  def call
    ensure_actor!

    ActiveRecord::Base.transaction do
      booking = lock_booking!
      ensure_draft!(booking)
      selection = if @selection
        booking.choice_selections.find(@selection.id).tap { |row| ensure_version!(row) }
      else
        option = booking.offering.choices.flat_map(&:options).find { |candidate| candidate.id == @option_id } ||
          raise(Error.new("Option must be one of this package's.", code: :invalid))
        booking.choice_selections.new(agency: @agency, option:, unit_number: option.choice.made_per_unit? ? next_unit(booking, option) : nil)
      end
      creating = selection.new_record?
      travelers = booking.booking_travelers.select { |traveler| @occupant_ids.include?(traveler.id) }
      raise Error.new("Travelers must be on this booking.", code: :invalid) if travelers.size != @occupant_ids.uniq.size

      check_pattern!(booking, selection, travelers)
      selection.save! if creating
      position_occupants!(selection, travelers)
      check_positions!(selection)
      selection.touch unless creating
      after_contents_change!(booking)
      audit_booking!(booking, creating ? "client_booking.selection_added" : "client_booking.selection_updated",
        "choice_selection_id" => selection.id, "offering_option_id" => selection.offering_option_id, "unit_number" => selection.unit_number,
        "booking_traveler_ids" => travelers.map(&:id))
      Result.new(status: creating ? :created : :updated, record: selection)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  # Units count within the choice, or within the option under optional
  # multiple, such as each extension night's rooms.
  def next_unit(booking, option)
    siblings = booking.choice_selections.select { |selection| selection.choice.id == option.choice.id }
    siblings = siblings.select { |selection| selection.offering_option_id == option.id } if option.choice.optional_multiple?
    siblings.map(&:unit_number).compact.max.to_i + 1
  end

  # A traveler takes one option of a single-pattern choice, and one unit of
  # a per-unit choice; under optional multiple, one unit of each option,
  # such as each extension night (BKG-14, question 19).
  def check_pattern!(booking, selection, travelers)
    choice = selection.choice
    siblings = booking.choice_selections.reject { |other| other.id == selection.id }.select { |other| other.choice.id == choice.id }
    if choice.made_per_trip? && !choice.optional_multiple? && siblings.any?
      raise Error.new("#{choice.name} takes one option per trip.", code: :invalid)
    end
    scope = choice.optional_multiple? ? siblings.select { |other| other.option.id == selection.option.id } : siblings
    clash = travelers.find { |traveler| scope.any? { |other| other.occupants.any? { |occupant| occupant.booking_traveler_id == traveler.id } } }
    return unless clash

    raise Error.new("#{clash.display_name} is already in another #{choice.made_per_unit? ? "unit" : "option"} of #{choice.name}.", code: :invalid)
  end

  # INV-09: never more travelers using positions than the unit holds.
  def check_positions!(selection)
    group = selection.inventory_group
    return unless selection.per_unit? && group.positions_per_unit

    counted = selection.occupants.reload.count(&:position)
    return if counted <= group.positions_per_unit

    raise Error.new("#{selection.label} holds #{group.positions_per_unit}; #{counted} travelers would use positions in it.", code: :invalid)
  end
end
