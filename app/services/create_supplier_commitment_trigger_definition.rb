class CreateSupplierCommitmentTriggerDefinition < AgencyCommand
  include CommitmentTriggerCommandSupport

  def initialize(agency:, actor:, version:, attributes:, version_lock_version:, idempotency_key:)
    @agency, @actor, @version = agency, actor, version
    @attributes = attributes
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      departure, arrangement, version, contractor = lock_trigger_graph!
      ensure_trigger_editable!(departure, arrangement, version, contractor)
      attrs = normalize_trigger_attributes(version, arrangement, @attributes)
      idempotent_create!(
        command_name: self.class.name, idempotency_key: @idempotency_key,
        payload: attrs.merge(supplier_arrangement_version_id: version.id),
        result_class: SupplierCommitmentTriggerDefinition
      ) do
        ensure_current_lock_version!(version, @version_lock_version)
        trigger = version.supplier_commitment_trigger_definitions.create!(
          attrs.merge(
            agency: @agency, departure:, supplier_arrangement: arrangement,
            position: version.supplier_commitment_trigger_definitions.maximum(:position).to_i + 1
          )
        )
        bump_version!(version)
        audit!(
          agency: @agency, actor: @actor, subject: arrangement,
          action: "supplier_arrangement.commitment_trigger_created",
          details: trigger_details(trigger)
        )
        trigger
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  rescue ActiveRecord::RecordNotUnique
    raise AgencyCommand::Error.new("That trigger conflicts with another update.", code: :conflict)
  end
end
