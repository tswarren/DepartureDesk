class RemoveSupplierCommitmentTriggerDefinition < AgencyCommand
  include CommitmentTriggerCommandSupport

  def initialize(agency:, actor:, trigger:, version_lock_version:)
    @agency, @actor, @trigger = agency, actor, trigger
    @version = trigger.supplier_arrangement_version
    @version_lock_version = version_lock_version
  end

  def call
    ensure_arrangement_actor!
    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      departure, arrangement, version, contractor = lock_trigger_graph!
      ensure_trigger_editable!(departure, arrangement, version, contractor)
      trigger = version.supplier_commitment_trigger_definitions.lock.find(@trigger.id)
      ensure_current_lock_version!(version, @version_lock_version)
      details = trigger_details(trigger)
      trigger.destroy!
      bump_version!(version)
      audit!(
        agency: @agency, actor: @actor, subject: arrangement,
        action: "supplier_arrangement.commitment_trigger_removed", details:
      )
      trigger
    end
  rescue ActiveRecord::DeleteRestrictionError
    raise AgencyCommand::Error.new("That trigger is already used by a commitment.", code: :dependency_exists)
  end
end
