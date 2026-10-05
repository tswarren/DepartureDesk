# frozen_string_literal: true

class CompileActivityAgreement
  ActivityRow = Data.define(
    :item, :item_definition, :occurrence_definition, :resource_definition, :pool_definition,
    :component, :threshold, :payment, :inclusion, :cancellation, :review_deadline,
    :final_count_deadline, :cutoff_deadline, :expected_persons, :forecast_minor_units,
    :advanced_reason, :outcome
  )
  Result = Data.define(
    :arrangement, :version, :activities, :confirmation_allowed, :confirmation_blocker,
    :activation_allowed, :activation_blocker, :confirmed, :editable
  )

  ILLUSTRATIONS = [ 4, 5, 20, 40 ].freeze

  def initialize(agency:, departure:, arrangement:, version:)
    @agency = agency
    @departure = departure
    @arrangement = arrangement
    @version = version
  end

  def call
    rows = item_definitions.map { |definition| build_row(definition) }
    blocker = confirmation_blocker_for(rows)
    Result.new(
      arrangement: @arrangement, version: @version, activities: rows,
      confirmation_allowed: blocker.nil?,
      confirmation_blocker: blocker,
      activation_allowed: activation_blocker_for(rows, blocker).nil?,
      activation_blocker: activation_blocker_for(rows, blocker),
      confirmed: SupplierConfirmation.exists?(supplier_arrangement_version_id: @version.id),
      editable: @version.draft? && !SupplierConfirmation.exists?(supplier_arrangement_version_id: @version.id)
    )
  end

  def self.illustrations(rate_minor_units)
    return [] if rate_minor_units.nil?

    ILLUSTRATIONS.map { |count| [ count, count * rate_minor_units ] }
  end

  private

  def item_definitions
    @version.arrangement_item_definitions.where(category: "activity_attraction").order(:position, :id).to_a
  end

  def build_row(item_definition)
    item = item_definition.arrangement_item
    component = ActivityAgreementShape.sole_component(@version, item)
    assumption = @version.supplier_cost_usage_assumptions.find_by(arrangement_item: item)
    ActivityRow.new(
      item:,
      item_definition:,
      occurrence_definition: @version.service_occurrence_definitions.find_by(arrangement_item: item),
      resource_definition: @version.supplier_resource_definitions.find_by(arrangement_item: item),
      pool_definition: @version.capacity_pool_definitions.find_by(arrangement_item: item),
      component:,
      threshold: @version.supplier_operating_threshold_definitions.find_by(arrangement_item: item),
      payment: @version.supplier_payment_requirement_definitions.find_by(arrangement_item: item),
      inclusion: reference(item, "rate_inclusions"),
      cancellation: reference(item, "cancellation"),
      review_deadline: ActivityAgreementShape.deadline(@version, item, "other"),
      final_count_deadline: ActivityAgreementShape.deadline(@version, item, "final_count_due"),
      cutoff_deadline: ActivityAgreementShape.deadline(@version, item, "cancellation_cutoff"),
      expected_persons: assumption&.expected_persons,
      forecast_minor_units: forecast_for(item),
      advanced_reason: ActivityAgreementShape.review_reason(@version, item),
      outcome: outcome_for(item)
    )
  end

  def reference(item, kind)
    @version.supplier_agreement_references.find_by(arrangement_item_id: item.id, kind: kind)
  end

  def forecast_for(item)
    forecast = EvaluateSupplierCostForecast.new(
      agency: @agency, departure: @departure, arrangement: @arrangement, version: @version
    ).call
    source = forecast.arrangements.flat_map(&:sources).find do |entry|
      SupplierCostSource.find_by(id: entry.source_id)&.arrangement_item_id == item.id
    end
    source&.totals&.forecast_supplier_cost_minor_units
  end

  def outcome_for(item)
    threshold = @arrangement.governing_version&.supplier_operating_threshold_definitions&.find_by(arrangement_item: item)
    return nil if threshold.nil?

    SupplierOperatingThresholdOutcome.find_by(supplier_operating_threshold_definition_id: threshold.id)
  end

  def confirmation_blocker_for(rows)
    return ActivityAgreementShape::ADVANCED if ActivityAgreementShape.foreign_item?(@version)
    return "Add an activity." if rows.empty?

    rows.filter_map(&:advanced_reason).first
  end

  def activation_blocker_for(rows, confirmation_blocker)
    return confirmation_blocker if confirmation_blocker
    return "Confirm the Activity agreement before activation." unless SupplierConfirmation.exists?(supplier_arrangement_version_id: @version.id)
    if rows.any? { |row| row.component && !row.component.supplier_cost_definition.forecast_ready? }
      return "Mark the per-participant rate ready before activation."
    end

    nil
  end
end
