class UpdateSupplierCommitmentTriggerDefinition < AgencyCommand
  include CommitmentTriggerCommandSupport

  def initialize(agency:, actor:, trigger:, attributes:, lock_version:)
    @agency, @actor, @trigger = agency, actor, trigger
    @version = trigger.supplier_arrangement_version
    @attributes = attributes
    @lock_version = lock_version
  end

  def call
    ensure_arrangement_actor!
    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      departure, arrangement, version, contractor = lock_trigger_graph!
      ensure_trigger_editable!(departure, arrangement, version, contractor)
      trigger = version.supplier_commitment_trigger_definitions.lock.find(@trigger.id)
      ensure_current_lock_version!(trigger)
      before = trigger_details(trigger)
      trigger.update!(normalize_trigger_attributes(version, arrangement, @attributes))
      bump_version!(version)
      audit!(
        agency: @agency, actor: @actor, subject: arrangement,
        action: "supplier_arrangement.commitment_trigger_updated",
        details: trigger_details(trigger).merge("before" => before)
      )
      trigger
    end
  rescue ActiveRecord::StaleObjectError, ActiveRecord::RecordNotUnique
    raise AgencyCommand::Error.new(STALE_MESSAGE, code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
