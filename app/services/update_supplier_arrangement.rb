class UpdateSupplierArrangement < DepartureCommand
  EDITABLE = %w[name description client_facing_description service_provider_party_id].freeze

  def initialize(agency:, arrangement:, name:, description: nil, client_facing_description: nil, service_provider_party: nil, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @arrangement = arrangement
    @departure = arrangement.departure
    @service_provider_party = service_provider_party
    @name = name
    @description = description
    @client_facing_description = client_facing_description
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction do
      with_departure_locks(@agency, offices: [ @arrangement.office ], departure: @departure, supplier_arrangements: [ @arrangement ], parties: [ @service_provider_party ]) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This supplier arrangement was updated by someone else.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def perform
    actor = actor_membership(@agency)
    ensure_office_access!(actor, @arrangement.office)
    ensure_departure_can_receive_supplier_planning!(@departure)
    ensure_fresh_lock!(@arrangement, @lock_version)
    raise Error.new("Only draft supplier arrangements can be updated in this slice.", code: :invalid_state) unless @arrangement.draft?
    ensure_active_same_agency_party!(@service_provider_party) if @service_provider_party

    before = snapshot
    @arrangement.assign_attributes(
      name: @name,
      description: @description,
      client_facing_description: @client_facing_description,
      service_provider_party: @service_provider_party,
      service_provider_display_name_snapshot: @service_provider_party&.display_name
    )
    return CommandResult.new(status: :accepted, departure: @departure, supplier_arrangement: @arrangement) unless @arrangement.changed?

    @arrangement.save!
    after = snapshot
    changed = EDITABLE.select { |field| before[field] != after[field] }
    audit!(agency: @agency, action: "supplier_arrangement.updated", subject: @arrangement, details: { "supplier_arrangement_id" => @arrangement.id, "changed_fields" => changed, "before" => before.slice(*changed), "after" => after.slice(*changed) }, **actor_audit_args)
    CommandResult.new(status: :accepted, departure: @departure, supplier_arrangement: @arrangement)
  end

  def snapshot
    {
      "name" => @arrangement.name,
      "description" => @arrangement.description,
      "client_facing_description" => @arrangement.client_facing_description,
      "service_provider_party_id" => @arrangement.service_provider_party_id
    }
  end
end
