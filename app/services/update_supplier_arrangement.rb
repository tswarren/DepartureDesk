class UpdateSupplierArrangement < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, arrangement:, attributes:, lock_version:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @attributes = attributes.to_h.with_indifferent_access
    @lock_version = lock_version
  end

  def call
    ensure_arrangement_actor!
    name = normalize_arrangement_name(@attributes[:name])

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      contractor = locked_supplier!(@arrangement.contracting_supplier_id)
      departure, arrangement, version = lock_departure_arrangement_version!(@arrangement)
      ensure_not_abandoned!(arrangement, version)
      ensure_current_lock_version!(arrangement)

      contact = resolve_contact_for_update!(contractor, departure, arrangement)
      attrs = { name: name, supplier_contact_id: contact&.id }
      ensure_update_allowed!(departure, arrangement, version, contractor, attrs)
      return Result.new(status: :noop, record: arrangement) if same_values?(arrangement, attrs)

      arrangement.update!(attrs)
      audit!(
        agency: @agency,
        action: "supplier_arrangement.updated",
        subject: arrangement,
        actor: @actor,
        details: {
          "supplier_arrangement_id" => arrangement.id,
          "supplier_arrangement_version_id" => version.id,
          "changed_fields" => changed_fields(arrangement, attrs),
          "name" => arrangement.name,
          "supplier_contact_id" => arrangement.supplier_contact_id
        }
      )
      Result.new(status: :updated, record: arrangement)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def resolve_contact_for_update!(contractor, departure, arrangement)
    uuid = parse_optional_uuid(@attributes[:supplier_contact_id], "Supplier contact")
    if uuid.blank?
      return nil
    end

    if ordinary_planning_state?(departure, contractor)
      return resolve_optional_contact!(contractor, uuid)
    end

    # Recovery may only clear a contact, never assign or retain a different one.
    raise Error.new(recovery_message, code: :invalid_state) unless uuid == arrangement.supplier_contact_id

    contractor.contacts.lock.find(uuid)
  end

  def ensure_update_allowed!(departure, arrangement, version, contractor, attrs)
    ensure_draft_graph!(arrangement, version)
    return if ordinary_planning_state?(departure, contractor)

    unless recovery_clear_contact?(departure, arrangement, contractor, attrs)
      raise Error.new(recovery_message, code: :invalid_state)
    end
  end

  def recovery_clear_contact?(departure, arrangement, contractor, attrs)
    return false unless attrs[:name] == arrangement.name
    return false unless attrs[:supplier_contact_id].nil?
    return false if arrangement.supplier_contact_id.nil?

    contact = arrangement.supplier_contact
    return true if contractor.inactive? && (departure.draft? || departure.active? || departure.departed?)
    return true if departure.departed? && contact&.inactive?

    false
  end
end
