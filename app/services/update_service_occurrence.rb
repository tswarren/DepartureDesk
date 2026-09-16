class UpdateServiceOccurrence < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, definition:, attributes:, lock_version:)
    @agency = agency
    @actor = actor
    @definition = definition
    @attributes = attributes.to_h.with_indifferent_access
    @lock_version = lock_version
  end

  def call
    ensure_arrangement_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      arrangement = lock_arrangement_for!(@definition.supplier_arrangement)
      departure = lock_departure_for!(arrangement.departure)
      attrs = normalize_occurrence_attributes(@attributes, departure)
      provider = resolve_optional_active_supplier!(@attributes[:service_provider_id], "Service provider")
      version = lock_initial_version_for!(arrangement)
      item = lock_arrangement_item_for!(arrangement, @definition.arrangement_item)
      occurrence = lock_occurrence_for!(item, @definition.service_occurrence)
      definition = lock_occurrence_definition_for!(version, @definition)
      ensure_editable_draft_arrangement!(departure, arrangement, version)
      ensure_current_lock_version!(definition)

      attrs[:service_provider_id] = provider&.id
      return Result.new(status: :noop, record: definition) if same_values?(definition, attrs)

      definition.update!(attrs)
      audit!(
        agency: @agency,
        action: "supplier_arrangement.occurrence_updated",
        subject: arrangement,
        actor: @actor,
        details: {
          "supplier_arrangement_id" => arrangement.id,
          "service_occurrence_id" => occurrence.id,
          "service_occurrence_definition_id" => definition.id,
          "changed_fields" => changed_fields(definition, attrs)
        }
      )
      Result.new(status: :updated, record: definition)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
