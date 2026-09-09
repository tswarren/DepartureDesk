class RecordSupplierConfirmation < DepartureCommand
  def initialize(agency:, issuer_party:, identifier_type:, context:, raw_value:, arrangement: nil, reservation: nil, issued_on: nil, received_on: nil, source_channel: nil, document_reference: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @arrangement = arrangement
    @reservation = reservation
    @issuer_party = issuer_party
    @identifier_type = identifier_type
    @context = context
    @raw_value = raw_value
    @issued_on = issued_on
    @received_on = received_on
    @source_channel = source_channel
    @document_reference = document_reference
    @departure = (@arrangement || @reservation)&.departure
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    raise Error.new("Choose exactly one confirmation owner.", code: :invalid) if @arrangement.present? == @reservation.present?
    ActiveRecord::Base.transaction do
      with_departure_locks(@agency, offices: [ owner.office ], departure: @departure, supplier_arrangements: [ @arrangement, @reservation&.arrangement ], supplier_reservations: [ @reservation ], parties: [ @issuer_party ]) { perform }
    end
  rescue ActiveRecord::RecordInvalid => error
    if error.record.is_a?(SupplierConfirmation) && error.record.errors.added?(:normalized_value, :taken)
      raise Error.new("That confirmation identifier already exists for this issuer and context.", code: :conflict)
    end
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("That confirmation identifier already exists for this issuer and context.", code: :conflict)
  end

  private

  def perform
    actor = actor_membership(@agency)
    ensure_office_access!(actor, owner.office)
    ensure_departure_can_receive_supplier_planning!(@departure)
    ensure_active_same_agency_party!(@issuer_party)

    confirmation = SupplierConfirmation.create!(
      agency: @agency,
      office: owner.office,
      departure: @departure,
      arrangement: @arrangement,
      reservation: @reservation,
      issuer_party: @issuer_party,
      issuer_display_name_snapshot: @issuer_party.display_name,
      identifier_type: @identifier_type,
      context: @context,
      raw_value: @raw_value,
      normalized_value: normalize_value(@raw_value),
      issued_on: @issued_on,
      received_on: @received_on,
      source_channel: @source_channel,
      document_reference: @document_reference,
      status: "effective",
      entered_by_membership: actor
    )
    audit!(agency: @agency, action: "supplier_confirmation.created", subject: confirmation, details: { "supplier_confirmation_id" => confirmation.id, "arrangement_id" => confirmation.arrangement_id, "reservation_id" => confirmation.reservation_id, "issuer_party_id" => confirmation.issuer_party_id, "identifier_type" => confirmation.identifier_type, "context" => confirmation.context }, **actor_audit_args)
    CommandResult.new(status: :created, departure: @departure, supplier_confirmation: confirmation)
  end

  def owner
    @arrangement || @reservation
  end

  def normalize_value(value)
    value.to_s.strip.upcase.gsub(/\s+/, " ")
  end
end
