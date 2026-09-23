# frozen_string_literal: true

class CompileCruiseDepositsAndDeadlinesWorkspace
  DeadlineRow = Data.define(
    :definition,
    :shape,
    :compatible?,
    :template,
    :display_label,
    :kind,
    :timing_sentence,
    :coverage_summary,
    :action,
    :advanced_path,
    :projected_fields
  )

  Result = Data.define(
    :compatible?,
    :version,
    :item,
    :editable?,
    :governing_read_only?,
    :successor_draft?,
    :can_create_successor?,
    :deadline_rows,
    :deposit_placeholder,
    :advanced_deadlines_path,
    :advanced_deposits_path,
    :return_to,
    :reasons
  )

  RETURN_TOKEN = "cruise_deposits_and_deadlines"

  def initialize(agency:, arrangement:, version: nil)
    @agency = agency
    @arrangement = arrangement
    @version = version
  end

  def call
    arrangement = @agency.supplier_arrangements.find(@arrangement.id)
    cruise_shape = DetectCruiseArrangementShape.new(
      agency: @agency,
      arrangement: arrangement,
      version: @version
    ).call

    unless cruise_shape.compatible?
      return Result.new(
        compatible?: false,
        version: cruise_shape.version,
        item: cruise_shape.item,
        editable?: false,
        governing_read_only?: false,
        successor_draft?: false,
        can_create_successor?: false,
        deadline_rows: [],
        deposit_placeholder: deposit_placeholder_message,
        advanced_deadlines_path: nil,
        advanced_deposits_path: nil,
        return_to: RETURN_TOKEN,
        reasons: cruise_shape.reasons
      )
    end

    version = cruise_shape.version
    departure = arrangement.departure
    editable = version.draft?
    successor_draft = version.draft? && version.version_number.to_i > 1
    governing_read_only = !editable && version.activated?
    can_create_successor =
      departure.active? &&
      arrangement.active? &&
      version.activated? &&
      arrangement.versions.none?(&:draft?)

    advanced_deadlines = Rails.application.routes.url_helpers
      .departure_arrangement_version_deadlines_path(
        departure, arrangement, version, return_to: RETURN_TOKEN
      )
    advanced_deposits = Rails.application.routes.url_helpers
      .departure_arrangement_version_deposits_path(
        departure, arrangement, version, return_to: RETURN_TOKEN
      )

    definitions = version.supplier_deadline_definitions
      .includes(
        :supplier_deadline_definition_coverage_links,
        :supplier_deadline_commitment_definition_lines
      )
      .order(:position, :id)
      .to_a

    rows = definitions.map do |definition|
      shape = DetectCruiseSupplierDeadlineShape.new(
        agency: @agency,
        arrangement: arrangement,
        definition: definition,
        version: version
      ).call
      DeadlineRow.new(
        definition: definition,
        shape: shape,
        compatible?: shape.compatible?,
        template: shape.template,
        display_label: definition.display_label,
        kind: definition.kind,
        timing_sentence: shape.compatible? ?
          shape.summary[:timing_sentence] :
          CruiseDeadlineTemplateSupport.timing_sentence(definition),
        coverage_summary: coverage_summary_for(definition, cruise_shape),
        action: shape.compatible? ? "edit" : "advanced",
        advanced_path: advanced_deadlines,
        projected_fields: shape.projected_fields
      )
    end

    Result.new(
      compatible?: true,
      version: version,
      item: cruise_shape.item,
      editable?: editable,
      governing_read_only?: governing_read_only,
      successor_draft?: successor_draft,
      can_create_successor?: can_create_successor,
      deadline_rows: rows,
      deposit_placeholder: deposit_placeholder_message,
      advanced_deadlines_path: advanced_deadlines,
      advanced_deposits_path: advanced_deposits,
      return_to: RETURN_TOKEN,
      reasons: []
    )
  end

  private

  def deposit_placeholder_message
    "Deposit requirements are not yet typed here. Open advanced deposits, or continue after the next Cruise deposits slice."
  end

  def coverage_summary_for(definition, cruise_shape)
    links = definition.supplier_deadline_definition_coverage_links.order(:position, :id).to_a
    projected = CruiseDeadlineTemplateSupport.project_coverage_fields(links)
    case projected[:scope]
    when "arrangement"
      "Entire Cruise (#{cruise_shape.item_definition&.name || "Arrangement Item"})"
    when "resource"
      resource = cruise_shape.resources.find { |row| row.id == projected[:supplier_resource_id] }
      resource ? "Cabin category #{resource_label(resource, cruise_shape.version)}" : "Selected cabin category"
    when "capacity_pool"
      "Selected cabin Capacity Pool"
    else
      "Advanced coverage"
    end
  end

  def resource_label(resource, version)
    definition = version.supplier_resource_definitions.find_by(supplier_resource_id: resource.id)
    definition&.supplier_code.presence || definition&.name || resource.id
  end
end
