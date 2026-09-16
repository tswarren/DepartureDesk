class CreateServiceOccurrence < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, item:, attributes:, version_lock_version:, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @item = item
    @attributes = attributes.to_h.with_indifferent_access
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key || @attributes.delete(:idempotency_key)
  end

  def call
    ensure_arrangement_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      arrangement = lock_arrangement_for!(@item.supplier_arrangement)
      departure = lock_departure_for!(arrangement.departure)
      attrs = normalize_occurrence_attributes(@attributes, departure)
      provider = resolve_optional_active_supplier!(@attributes[:service_provider_id], "Service provider")
      version = lock_initial_version_for!(arrangement)
      item = lock_arrangement_item_for!(arrangement, @item)
      ensure_editable_draft_arrangement!(departure, arrangement, version)
      ensure_current_lock_version!(version, @version_lock_version)

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: attrs.merge(
          supplier_arrangement_id: arrangement.id,
          supplier_arrangement_version_id: version.id,
          arrangement_item_id: item.id,
          service_provider_id: provider&.id
        ),
        result_class: ServiceOccurrence
      ) do
        occurrence = item.service_occurrences.create!(
          agency: @agency,
          departure: departure,
          supplier_arrangement: arrangement,
          status: "planned"
        )
        version.service_occurrence_definitions.create!(
          attrs.merge(
            agency: @agency,
            departure: departure,
            supplier_arrangement: arrangement,
            arrangement_item: item,
            service_occurrence: occurrence,
            service_provider: provider
          )
        )
        bump_version!(version)
        audit!(
          agency: @agency,
          action: "supplier_arrangement.occurrence_created",
          subject: arrangement,
          actor: @actor,
          details: { "supplier_arrangement_id" => arrangement.id, "service_occurrence_id" => occurrence.id }
        )
        occurrence
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
