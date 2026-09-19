# frozen_string_literal: true

class CreateSupplierDepositRequirementDefinition < AgencyCommand
  include DepositDefinitionCommandSupport

  def initialize(agency:, actor:, version:, attributes:, version_lock_version:, idempotency_key:)
    @agency = agency
    @actor = actor
    @version = version
    @attributes = attributes
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      departure, arrangement, version, contractor = lock_deposit_graph!
      ensure_deposit_editable!(departure, arrangement, version, contractor)
      attrs = normalize_deposit_attributes(version, arrangement, @attributes)
      coverage_links = attrs.delete(:coverage_links)
      cost_links = attrs.delete(:cost_links)
      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: attrs.merge(
          supplier_arrangement_version_id: version.id,
          coverage_links:,
          cost_links:
        ),
        result_class: SupplierDepositRequirementDefinition
      ) do
        ensure_current_lock_version!(version, @version_lock_version)
        definition = version.supplier_deposit_requirement_definitions.create!(
          attrs.merge(
            agency: @agency, departure:, supplier_arrangement: arrangement,
            position: version.supplier_deposit_requirement_definitions.maximum(:position).to_i + 1
          )
        )
        persist_deposit_children!(definition, coverage_links, cost_links)
        bump_version!(version)
        audit!(
          agency: @agency, actor: @actor, subject: arrangement,
          action: "supplier_arrangement.deposit_definition_created",
          details: deposit_details(definition)
        )
        definition
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  rescue ActiveRecord::RecordNotUnique
    raise AgencyCommand::Error.new("That deposit conflicts with another update.", code: :conflict)
  rescue SupplierDeadlineRuleEvaluator::UnsupportedRule => error
    raise AgencyCommand::Error.new(error.message, code: :invalid)
  end
end
