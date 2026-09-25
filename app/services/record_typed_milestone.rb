# frozen_string_literal: true

class RecordTypedMilestone < AgencyCommand
  include DeadlineDefinitionCommandSupport

  TEMPLATES = {
    "option_date" => { deadline_type: "option_or_release_date", description: "Option date" },
    "rooming_list" => { deadline_type: "rooming_list_due", description: "Rooming list" },
    "final_payment" => { deadline_type: "other", description: "Final payment", other_label: "Final payment" }
  }.freeze

  def initialize(agency:, actor:, arrangement:, category:, attributes:, idempotency_key:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @category = category
    @attributes = attributes.to_h.with_indifferent_access
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    template = TEMPLATES[@attributes[:template].to_s]
    raise Error.new("Choose a deadline template.", code: :invalid) unless template

    arrangement = @agency.supplier_arrangements.find(@arrangement.id)
    version = arrangement.versions.find_by(status: "draft")
    raise Error.new("Open a successor draft before changing this deadline.", code: :invalid_state) unless version

    item = arrangement.arrangement_items.find(@attributes[:arrangement_item_id])
    definition = version.arrangement_item_definitions.find_by!(arrangement_item_id: item.id)
    raise Error.new("That item is not part of this workspace.", code: :invalid) unless definition.category == @category

    occurrence = version.service_occurrence_definitions.find_by(arrangement_item_id: item.id)
    CreateSupplierDeadlineDefinition.new(
      agency: @agency, actor: @actor, version: version,
      version_lock_version: @attributes[:version_lock_version],
      idempotency_key: @idempotency_key,
      attributes: {
        deadline_type: template[:deadline_type],
        kind: "actionable",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => @attributes[:date].to_s },
        precision: "date_only",
        time_zone: @attributes[:time_zone].presence || occurrence&.time_zone || arrangement.departure.time_zone,
        cardinality: "one_shared",
        description: @attributes[:description].presence || template[:description],
        other_label: template[:other_label],
        coverage_links: [ { arrangement_item_id: item.id } ],
        commitment_lines: []
      }
    ).call
  end
end
