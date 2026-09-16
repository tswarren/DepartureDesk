class CreateArrangementItem < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, arrangement:, attributes:, version_lock_version:, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @attributes = attributes.to_h.with_indifferent_access
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key || @attributes.delete(:idempotency_key)
  end

  def call
    ensure_arrangement_actor!
    attrs = normalize_item_attributes(@attributes)

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      provider = resolve_optional_active_supplier!(@attributes[:default_service_provider_id], "Default service provider")
      arrangement = lock_arrangement_for!(@arrangement)
      departure = lock_departure_for!(arrangement.departure)
      version = lock_initial_version_for!(arrangement)
      ensure_editable_draft_arrangement!(departure, arrangement, version)
      ensure_current_lock_version!(version, @version_lock_version)

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: attrs.merge(
          supplier_arrangement_id: arrangement.id,
          supplier_arrangement_version_id: version.id,
          default_service_provider_id: provider&.id
        ),
        result_class: ArrangementItem
      ) do
        item = arrangement.arrangement_items.create!(agency: @agency, departure: departure)
        version.arrangement_item_definitions.create!(
          attrs.merge(
            agency: @agency,
            departure: departure,
            supplier_arrangement: arrangement,
            arrangement_item: item,
            default_service_provider: provider,
            position: next_item_position(version)
          )
        )
        bump_version!(version)
        audit!(
          agency: @agency,
          action: "supplier_arrangement.item_created",
          subject: arrangement,
          actor: @actor,
          details: { "supplier_arrangement_id" => arrangement.id, "arrangement_item_id" => item.id }
        )
        item
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
