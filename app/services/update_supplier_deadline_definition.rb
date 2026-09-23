# frozen_string_literal: true

class UpdateSupplierDeadlineDefinition < AgencyCommand
  include DeadlineDefinitionCommandSupport

  def initialize(agency:, actor:, definition:, attributes:, lock_version:)
    @agency = agency
    @actor = actor
    @definition = definition
    @attributes = attributes
    @lock_version = lock_version
  end

  def call
    ensure_arrangement_actor!
    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      @version = @definition.supplier_arrangement_version
      departure, arrangement, version, contractor = lock_deadline_graph!
      definition = version.supplier_deadline_definitions.lock.find(@definition.id)
      ensure_deadline_editable!(departure, arrangement, version, contractor)
      ensure_current_lock_version!(definition, @lock_version)
      attrs = normalize_deadline_attributes(version, arrangement, @attributes)
      coverage_links = attrs.delete(:coverage_links)
      commitment_lines = attrs.delete(:commitment_lines)
      # Replace children before updating kind so informational↔actionable transitions
      # do not fail association validation against the previous commitment-line graph.
      replace_deadline_children!(definition, coverage_links, commitment_lines)
      definition.update!(attrs)
      bump_version!(version)
      audit!(
        agency: @agency, actor: @actor, subject: arrangement,
        action: "supplier_arrangement.deadline_definition_updated",
        details: deadline_details(definition)
      )
      AgencyCommand::Result.new(status: :updated, record: definition)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  rescue ActiveRecord::RecordNotUnique
    raise AgencyCommand::Error.new("That deadline conflicts with another update.", code: :conflict)
  rescue SupplierDeadlineRuleEvaluator::UnsupportedRule => error
    raise AgencyCommand::Error.new(error.message, code: :invalid)
  end
end
