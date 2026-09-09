class CreateSupplierArrangement < DepartureCommand
  def initialize(agency:, departure:, supplier_party:, name:, service_provider_party: nil, parent_arrangement: nil, description: nil, client_facing_description: nil, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @departure = departure
    @supplier_party = supplier_party
    @service_provider_party = service_provider_party
    @parent_arrangement = parent_arrangement
    @name = name
    @description = description
    @client_facing_description = client_facing_description
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction do
      with_departure_locks(
        @agency,
        offices: [ @departure.office ],
        departure: @departure,
        supplier_arrangements: [ @parent_arrangement ],
        parties: [ @supplier_party, @service_provider_party ]
      ) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This departure was updated by someone else.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  rescue ActiveRecord::InvalidForeignKey, ActiveRecord::StatementInvalid
    raise Error.new("That supplier arrangement could not be saved.", code: :invalid)
  end

  private

  def perform
    actor = actor_membership(@agency)
    ensure_fresh_lock!(@departure, @lock_version)
    ensure_office_access!(actor, @departure.office)
    ensure_departure_can_receive_supplier_planning!(@departure)
    ensure_active_supplier_party!(@supplier_party)
    ensure_active_same_agency_party!(@service_provider_party) if @service_provider_party
    ensure_parent!

    arrangement = @departure.supplier_arrangements.create!(
      agency: @agency,
      office: @departure.office,
      parent_arrangement: @parent_arrangement,
      supplier_party: @supplier_party,
      service_provider_party: @service_provider_party,
      name: @name,
      description: @description,
      client_facing_description: @client_facing_description,
      status: "draft",
      supplier_display_name_snapshot: @supplier_party.display_name,
      service_provider_display_name_snapshot: @service_provider_party&.display_name,
      created_by_membership: actor,
      status_changed_at: Time.current,
      status_changed_by_membership: actor
    )
    audit!(agency: @agency, action: "supplier_arrangement.created", subject: arrangement, details: details_for(arrangement), **actor_audit_args)
    CommandResult.new(status: :created, departure: @departure, supplier_arrangement: arrangement)
  end

  def ensure_parent!
    return if @parent_arrangement.blank?
    return if @parent_arrangement.departure_id == @departure.id && @parent_arrangement.nonterminal?

    raise Error.new("Choose a nonterminal parent arrangement on this departure.", code: :invalid)
  end

  def details_for(arrangement)
    {
      "departure_id" => @departure.id,
      "supplier_arrangement_id" => arrangement.id,
      "parent_arrangement_id" => arrangement.parent_arrangement_id,
      "supplier_party_id" => arrangement.supplier_party_id,
      "service_provider_party_id" => arrangement.service_provider_party_id
    }
  end
end
