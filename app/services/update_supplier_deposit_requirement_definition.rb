# frozen_string_literal: true

class UpdateSupplierDepositRequirementDefinition < AgencyCommand
  include DepositDefinitionCommandSupport

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
      departure, arrangement, version, contractor = lock_deposit_graph!
      definition = version.supplier_deposit_requirement_definitions.lock.find(@definition.id)
      ensure_deposit_editable!(departure, arrangement, version, contractor)
      ensure_current_lock_version!(definition, @lock_version)
      attrs = normalize_deposit_attributes(
        version, arrangement, @attributes.merge(_cumulative_definition: definition)
      )
      coverage_links = attrs.delete(:coverage_links)
      cost_links = attrs.delete(:cost_links)
      contributor_links = attrs.delete(:contributor_links)
      attrs.delete(:_cumulative_definition)
      definition.update!(attrs)
      replace_deposit_children!(definition, coverage_links, cost_links, contributor_links)
      bump_version!(version)
      audit!(
        agency: @agency, actor: @actor, subject: arrangement,
        action: "supplier_arrangement.deposit_definition_updated",
        details: deposit_details(definition)
      )
      AgencyCommand::Result.new(status: :updated, record: definition)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  rescue ActiveRecord::RecordNotUnique
    raise AgencyCommand::Error.new("That deposit conflicts with another update.", code: :conflict)
  rescue SupplierDeadlineRuleEvaluator::UnsupportedRule => error
    raise AgencyCommand::Error.new(error.message, code: :invalid)
  end
end
