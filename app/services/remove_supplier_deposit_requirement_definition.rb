# frozen_string_literal: true

class RemoveSupplierDepositRequirementDefinition < AgencyCommand
  include DepositDefinitionCommandSupport

  def initialize(agency:, actor:, definition:, version_lock_version:)
    @agency = agency
    @actor = actor
    @definition = definition
    @version = definition.supplier_arrangement_version
    @version_lock_version = version_lock_version
  end

  def call
    ensure_arrangement_actor!
    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      departure, arrangement, version, contractor = lock_deposit_graph!
      definition = version.supplier_deposit_requirement_definitions.lock.find(@definition.id)
      ensure_deposit_editable!(departure, arrangement, version, contractor)
      ensure_current_lock_version!(version, @version_lock_version)
      details = deposit_details(definition)
      definition.supplier_deposit_requirement_definition_cost_links.order(:id).lock.load.each(&:destroy!)
      definition.supplier_deposit_requirement_definition_coverage_links.order(:id).lock.load.each(&:destroy!)
      definition.destroy!
      bump_version!(version)
      audit!(
        agency: @agency, actor: @actor, subject: arrangement,
        action: "supplier_arrangement.deposit_definition_removed",
        details:
      )
      AgencyCommand::Result.new(status: :destroyed, record: definition)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
