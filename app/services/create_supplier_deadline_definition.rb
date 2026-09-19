# frozen_string_literal: true

class CreateSupplierDeadlineDefinition < AgencyCommand
  include DeadlineDefinitionCommandSupport

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
      departure, arrangement, version, contractor = lock_deadline_graph!
      ensure_deadline_editable!(departure, arrangement, version, contractor)
      attrs = normalize_deadline_attributes(version, arrangement, @attributes)
      coverage_links = attrs.delete(:coverage_links)
      commitment_lines = attrs.delete(:commitment_lines)
      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: attrs.merge(
          supplier_arrangement_version_id: version.id,
          coverage_links:,
          commitment_lines:
        ),
        result_class: SupplierDeadlineDefinition
      ) do
        ensure_current_lock_version!(version, @version_lock_version)
        definition = version.supplier_deadline_definitions.create!(
          attrs.merge(
            agency: @agency, departure:, supplier_arrangement: arrangement,
            position: version.supplier_deadline_definitions.maximum(:position).to_i + 1
          )
        )
        persist_deadline_children!(definition, coverage_links, commitment_lines)
        bump_version!(version)
        audit!(
          agency: @agency, actor: @actor, subject: arrangement,
          action: "supplier_arrangement.deadline_definition_created",
          details: deadline_details(definition)
        )
        definition
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  rescue ActiveRecord::RecordNotUnique
    raise AgencyCommand::Error.new("That deadline conflicts with another update.", code: :conflict)
  rescue SupplierDeadlineRuleEvaluator::UnsupportedRule => error
    raise AgencyCommand::Error.new(error.message, code: :invalid)
  end
end
