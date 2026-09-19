# frozen_string_literal: true

class RemoveSupplierDeadlineDefinition < AgencyCommand
  include DeadlineDefinitionCommandSupport

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
      departure, arrangement, version, contractor = lock_deadline_graph!
      definition = version.supplier_deadline_definitions.lock.find(@definition.id)
      ensure_deadline_editable!(departure, arrangement, version, contractor)
      ensure_current_lock_version!(version, @version_lock_version)
      details = deadline_details(definition)
      definition.supplier_deadline_commitment_definition_lines.order(:id).lock.load.each(&:destroy!)
      definition.supplier_deadline_definition_coverage_links.order(:id).lock.load.each(&:destroy!)
      definition.destroy!
      bump_version!(version)
      audit!(
        agency: @agency, actor: @actor, subject: arrangement,
        action: "supplier_arrangement.deadline_definition_removed",
        details:
      )
      AgencyCommand::Result.new(status: :destroyed, record: definition)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
