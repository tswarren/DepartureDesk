# frozen_string_literal: true

class CompileCruiseDepositsAndDeadlinesWorkspace
  OperationalFacts = Data.define(
    :term_summary,
    :occurrence_due_sentence,
    :projection_status,
    :tranche_amount_sentence,
    :commitment_state_label,
    :attest_path,
    :commitments_path
  )

  SuccessorCompareFacts = Data.define(
    :governing_term_summary,
    :proposed_term_summary,
    :governing_operational_summary,
    :reconcile_foreshadow,
    :reconcile_foreshadow_label
  )

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
    :projected_fields,
    :operational,
    :successor_compare
  )

  DepositRow = Data.define(
    :definition,
    :shape,
    :compatible?,
    :template,
    :display_label,
    :amount_sentence,
    :timing_sentence,
    :coverage_summary,
    :action,
    :advanced_path,
    :projected_fields,
    :operational,
    :successor_compare
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
    :deposit_rows,
    :advanced_deadlines_path,
    :advanced_deposits_path,
    :return_to,
    :reasons
  )

  RETURN_TOKEN = "cruise_deposits_and_deadlines"

  COMMITMENT_OUTCOME_LABELS = {
    "handled_externally" => "Handled externally",
    "satisfied" => "Satisfied",
    "released" => "Released",
    "waived" => "Waived",
    "cancelled" => "Cancelled",
    "superseded" => "Superseded"
  }.freeze

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
        deposit_rows: [],
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

    predecessor = version.copied_from

    deadline_definitions = version.supplier_deadline_definitions
      .includes(
        :supplier_deadline_definition_coverage_links,
        :supplier_deadline_commitment_definition_lines,
        supplier_deadline_occurrences: :supplier_deadline_projection
      )
      .order(:position, :id)
      .to_a

    deadline_rows = deadline_definitions.map do |definition|
      shape = DetectCruiseSupplierDeadlineShape.new(
        agency: @agency,
        arrangement: arrangement,
        definition: definition,
        version: version
      ).call
      timing = shape.compatible? ?
        shape.summary[:timing_sentence] :
        CruiseDeadlineTemplateSupport.timing_sentence(definition)
      coverage = deadline_coverage_summary_for(definition, cruise_shape)
      term_summary = [ definition.display_label, definition.kind.humanize, timing, coverage ].join(" · ")

      DeadlineRow.new(
        definition: definition,
        shape: shape,
        compatible?: shape.compatible?,
        template: shape.template,
        display_label: definition.display_label,
        kind: definition.kind,
        timing_sentence: timing,
        coverage_summary: coverage,
        action: shape.compatible? ? "edit" : "advanced",
        advanced_path: advanced_deadlines,
        projected_fields: shape.projected_fields,
        operational: governing_read_only ?
          deadline_operational(definition, arrangement, departure, term_summary) :
          nil,
        successor_compare: successor_draft ?
          deadline_successor_compare(
            definition:,
            arrangement:,
            version:,
            predecessor:,
            cruise_shape:,
            proposed_summary: term_summary
          ) :
          nil
      )
    end

    deposit_definitions = version.supplier_deposit_requirement_definitions
      .includes(
        :supplier_deposit_requirement_definition_coverage_links,
        :supplier_deposit_requirement_definition_contributor_links,
        :supplier_deposit_requirement_definition_cost_links,
        supplier_deposit_requirement_tranches: {
          supplier_commitment: {
            supplier_commitment_dispositions: :supplier_commitment_reopening
          },
          governing_deadline_occurrence: :supplier_deadline_projection
        }
      )
      .order(:position, :id)
      .to_a

    deposit_rows = deposit_definitions.map do |definition|
      shape = DetectCruiseDepositRequirementShape.new(
        agency: @agency,
        arrangement: arrangement,
        definition: definition,
        version: version
      ).call
      amount = shape.compatible? ?
        shape.summary[:amount_sentence] :
        CruiseDepositTemplateSupport.amount_sentence(
          definition,
          currency: departure.operating_currency
        )
      timing = shape.compatible? ?
        shape.summary[:timing_sentence] :
        CruiseDepositTemplateSupport.timing_sentence(definition)
      coverage = CruiseDepositTemplateSupport.coverage_summary(definition, cruise_shape)
      term_summary = [
        shape.summary[:display_label],
        amount,
        timing,
        coverage
      ].join(" · ")

      DepositRow.new(
        definition: definition,
        shape: shape,
        compatible?: shape.compatible?,
        template: shape.template,
        display_label: shape.summary[:display_label],
        amount_sentence: amount,
        timing_sentence: timing,
        coverage_summary: coverage,
        action: shape.compatible? ? "edit" : "advanced",
        advanced_path: advanced_deposits,
        projected_fields: shape.projected_fields,
        operational: governing_read_only ?
          deposit_operational(definition, arrangement, departure, term_summary) :
          nil,
        successor_compare: successor_draft ?
          deposit_successor_compare(
            definition:,
            arrangement:,
            version:,
            predecessor:,
            cruise_shape:,
            proposed_summary: term_summary
          ) :
          nil
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
      deadline_rows: deadline_rows,
      deposit_rows: deposit_rows,
      advanced_deadlines_path: advanced_deadlines,
      advanced_deposits_path: advanced_deposits,
      return_to: RETURN_TOKEN,
      reasons: []
    )
  end

  private

  def deadline_coverage_summary_for(definition, cruise_shape)
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

  def deadline_operational(definition, arrangement, departure, term_summary)
    occurrence = current_deadline_occurrence(definition)
    projection = occurrence&.supplier_deadline_projection
    commitment = occurrence && arrangement.supplier_commitments
      .includes(supplier_commitment_dispositions: :supplier_commitment_reopening)
      .find { |row|
        row.supplier_deadline_occurrence_id == occurrence.id &&
          row.opening_kind == "deadline_requirement"
      }

    OperationalFacts.new(
      term_summary: term_summary,
      occurrence_due_sentence: occurrence_due_sentence(occurrence),
      projection_status: projection&.status&.humanize,
      tranche_amount_sentence: nil,
      commitment_state_label: commitment_state_label(commitment),
      attest_path: nil,
      commitments_path: commitments_path(departure, arrangement)
    )
  end

  def deposit_operational(definition, arrangement, departure, term_summary)
    tranche = definition.supplier_deposit_requirement_tranches
      .sort_by { |row| [ row.materialized_at, row.id ] }
      .last
    occurrence = tranche&.governing_deadline_occurrence
    projection = occurrence&.supplier_deadline_projection
    commitment = tranche&.supplier_commitment
    attest_path = if commitment&.open_state?
      Rails.application.routes.url_helpers.departure_arrangement_path(departure, arrangement)
    end

    OperationalFacts.new(
      term_summary: term_summary,
      occurrence_due_sentence: occurrence_due_sentence(occurrence),
      projection_status: projection&.status&.humanize,
      tranche_amount_sentence: tranche && Money.new(
        tranche.current_amount_minor_units,
        tranche.currency
      ).format,
      commitment_state_label: commitment_state_label(commitment),
      attest_path: attest_path,
      commitments_path: commitments_path(departure, arrangement)
    )
  end

  def deadline_successor_compare(definition:, arrangement:, version:, predecessor:, cruise_shape:, proposed_summary:)
    governing = predecessor &&
      SupplierDeadlineDefinition.find_by(
        id: definition.copied_from_id,
        supplier_arrangement_version_id: predecessor.id
      )
    governing_summary = if governing
      [
        governing.display_label,
        governing.kind.humanize,
        CruiseDeadlineTemplateSupport.timing_sentence(governing),
        deadline_coverage_summary_for(governing, cruise_shape)
      ].join(" · ")
    else
      "No governing lineage"
    end

    occurrence = governing && current_deadline_occurrence(governing)
    foreshadow = CruiseSuccessorReconcileForeshadow.for_deadline_definition(
      definition:,
      arrangement:,
      version:,
      predecessor_version: predecessor
    )

    SuccessorCompareFacts.new(
      governing_term_summary: governing_summary,
      proposed_term_summary: proposed_summary,
      governing_operational_summary: occurrence_due_sentence(occurrence) || "No materialized occurrence",
      reconcile_foreshadow: foreshadow,
      reconcile_foreshadow_label: CruiseSuccessorReconcileForeshadow.label_for(foreshadow)
    )
  end

  def deposit_successor_compare(definition:, arrangement:, version:, predecessor:, cruise_shape:, proposed_summary:)
    governing = predecessor &&
      SupplierDepositRequirementDefinition.find_by(
        id: definition.copied_from_id,
        supplier_arrangement_version_id: predecessor.id
      )
    governing_summary = if governing
      [
        governing.description.presence || "Deposit requirement",
        CruiseDepositTemplateSupport.amount_sentence(
          governing,
          currency: arrangement.departure.operating_currency
        ),
        CruiseDepositTemplateSupport.timing_sentence(governing),
        CruiseDepositTemplateSupport.coverage_summary(governing, cruise_shape)
      ].join(" · ")
    else
      "No governing lineage"
    end

    tranche = governing&.supplier_deposit_requirement_tranches
      &.sort_by { |row| [ row.materialized_at, row.id ] }
      &.last
    operational = if tranche
      [
        Money.new(tranche.current_amount_minor_units, tranche.currency).format,
        occurrence_due_sentence(tranche.governing_deadline_occurrence)
      ].compact.join(" · ")
    else
      "No materialized tranche"
    end

    foreshadow = CruiseSuccessorReconcileForeshadow.for_deposit_definition(
      definition:,
      arrangement:,
      version:,
      predecessor_version: predecessor
    )

    SuccessorCompareFacts.new(
      governing_term_summary: governing_summary,
      proposed_term_summary: proposed_summary,
      governing_operational_summary: operational,
      reconcile_foreshadow: foreshadow,
      reconcile_foreshadow_label: CruiseSuccessorReconcileForeshadow.label_for(foreshadow)
    )
  end

  def current_deadline_occurrence(definition)
    definition.supplier_deadline_occurrences
      .select(&:current?)
      .max_by { |row| [ row.materialized_at, row.id ] }
  end

  def occurrence_due_sentence(occurrence)
    return unless occurrence

    if occurrence.calculated_on.present?
      "#{occurrence.calculated_on.iso8601} (#{occurrence.time_zone})"
    elsif occurrence.calculated_at.present?
      zone = occurrence.time_zone
      "#{occurrence.calculated_at.in_time_zone(zone).strftime('%Y-%m-%d %H:%M')} (#{zone})"
    end
  end

  def commitment_state_label(commitment)
    return "No commitment" unless commitment
    return "Open" if commitment.open_state?

    COMMITMENT_OUTCOME_LABELS.fetch(commitment.disposition_outcome.to_s) {
      commitment.disposition_outcome.to_s.humanize
    }
  end

  def commitments_path(departure, arrangement)
    Rails.application.routes.url_helpers
      .departure_arrangement_commitments_path(departure, arrangement)
  end
end
