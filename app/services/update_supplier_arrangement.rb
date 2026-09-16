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
      arrangement = lock_arrangement_for!(@arrangement)
      contractor = @agency.suppliers.lock.find(arrangement.contracting_supplier_id)
      departure = lock_departure_for!(arrangement.departure)
      version = lock_initial_version_for!(arrangement)
      ensure_not_abandoned!(arrangement, version)
      ensure_current_lock_version!(arrangement)

      contact = resolve_optional_contact!(contractor, @attributes[:supplier_contact_id])
      attrs = { name: name, supplier_contact_id: contact&.id }
      ensure_update_allowed!(departure, arrangement, version, attrs)
      return Result.new(status: :noop, record: arrangement) if same_values?(arrangement, attrs)

      arrangement.update!(attrs)
      audit!(
        agency: @agency,
        action: "supplier_arrangement.updated",
        subject: arrangement,
        actor: @actor,
        details: {
          "supplier_arrangement_id" => arrangement.id,
          "changed_fields" => changed_fields(arrangement, attrs)
        }
      )
      Result.new(status: :updated, record: arrangement)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def ensure_update_allowed!(departure, arrangement, version, attrs)
    return ensure_editable_draft_arrangement!(departure, arrangement, version) if departure.draft? || departure.active?

    unless departed_clear_inactive_contact?(departure, arrangement, attrs)
      raise Error.new("A departed departure cannot expand supplier arrangement planning.", code: :invalid_state)
    end
  end

  def departed_clear_inactive_contact?(departure, arrangement, attrs)
    return false unless departure.departed?
    return false unless attrs[:name] == arrangement.name
    return false unless attrs[:supplier_contact_id].nil?
    return false if arrangement.supplier_contact_id.nil?

    contact = arrangement.supplier_contact
    contact&.inactive?
  end
end
