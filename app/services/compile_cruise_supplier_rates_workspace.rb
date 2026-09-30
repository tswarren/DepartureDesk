# frozen_string_literal: true

# Presentation facts for the Supplier rates workspace. Scenario amounts and
# commission method come from CompileCruiseSupplierRatePreview. Stage prefers
# a Contracted definition when one exists. Readiness is that definition's
# forecast-ready status.
class CompileCruiseSupplierRatesWorkspace
  Illustration = Data.define(:key, :label, :gross_minor_units, :currency, :available?)
  AttentionItem = Data.define(:code, :message, :resource_id, :stage, :advanced?)
  Row = Data.define(
    :resource_id, :code, :name, :stage, :stage_label, :status_label,
    :advanced?, :commission_label, :illustrations
  )
  Result = Data.define(
    :advanced?, :category_count, :contracted_count, :estimate_count,
    :unrecorded_count, :advanced_count, :rows, :attention_items
  )

  COMMISSION_LABELS = {
    "not_provided" => "Not provided yet",
    "dollar" => "Dollar amount",
    "percentage" => "Percentage"
  }.freeze

  def initialize(agency:, arrangement:, shape:, readiness: nil)
    @agency = agency
    @arrangement = arrangement
    @shape = shape
    @readiness = readiness
  end

  def call
    return empty_result(advanced: true) unless @shape.compatible?

    version = @shape.version
    return empty_result(advanced: false) if version.nil?

    rows = version.supplier_resource_definitions.includes(:supplier_resource).order(:position, :id).map do |definition|
      row_for(version, definition)
    end

    Result.new(
      advanced?: false,
      category_count: rows.size,
      contracted_count: rows.count { |row| row.stage == "contracted" },
      estimate_count: rows.count { |row| row.stage == "estimate" },
      unrecorded_count: rows.count { |row| row.status_label == "Not recorded" },
      advanced_count: rows.count(&:advanced?),
      rows: rows,
      attention_items: attention_items(version, rows)
    )
  end

  private

  def empty_result(advanced:)
    Result.new(
      advanced?: advanced,
      category_count: 0,
      contracted_count: 0,
      estimate_count: 0,
      unrecorded_count: 0,
      advanced_count: 0,
      rows: [],
      attention_items: []
    )
  end

  def row_for(version, definition)
    resource = definition.supplier_resource
    shape = DetectCruiseSupplierRateShape.new(
      agency: @agency,
      arrangement: @arrangement,
      resource: resource,
      version: version
    ).call
    stage = selected_stage(shape)
    if stage.nil?
      return blank_row(definition, advanced: representable_gap?(shape) ? false : true)
    end

    preview = CompileCruiseSupplierRatePreview.new(
      agency: @agency,
      arrangement: @arrangement,
      resource: resource,
      version: version,
      stage: stage
    ).call
    return blank_row(definition, advanced: true) unless preview.compatible? && !preview.advanced?

    Row.new(
      resource_id: definition.supplier_resource_id,
      code: definition.supplier_code.presence,
      name: definition.name,
      stage: stage,
      stage_label: stage_label(stage),
      status_label: preview.definition&.forecast_ready? ? "Ready" : "Needs review",
      advanced?: false,
      commission_label: COMMISSION_LABELS.fetch(preview.commission_method, "—"),
      illustrations: illustrations_for(preview)
    )
  end

  def representable_gap?(shape)
    shape.compatible? && (shape.empty? || shape.summary[:state] == "missing")
  end

  def selected_stage(shape)
    return nil unless shape.compatible?
    return nil if shape.empty? || shape.summary[:state] == "missing"

    definitions = shape.source&.supplier_cost_definitions.to_a
    if definitions.any?(&:contracted?)
      "contracted"
    elsif definitions.any?(&:estimate?)
      "estimate"
    end
  end

  def blank_row(definition, advanced:)
    Row.new(
      resource_id: definition.supplier_resource_id,
      code: definition.supplier_code.presence,
      name: definition.name,
      stage: nil,
      stage_label: "—",
      status_label: advanced ? "Advanced" : "Not recorded",
      advanced?: advanced,
      commission_label: advanced ? "Advanced" : "—",
      illustrations: []
    )
  end

  def illustrations_for(preview)
    preview.illustrations.map do |illustration|
      Illustration.new(
        key: illustration.key,
        label: illustration.label,
        gross_minor_units: illustration.gross_minor_units,
        currency: preview.currency,
        available?: illustration.complete && illustration.gross_minor_units.present?
      )
    end
  end

  def stage_label(stage)
    stage == "contracted" ? "Contracted" : "Estimate"
  end

  def attention_items(version, rows)
    review = CompileCruiseActivationReview.new(
      agency: @agency,
      arrangement: @arrangement,
      version: version,
      presentation: false,
      readiness: supplied_readiness(version)
    ).call
    blockers = review.blockers.select { |blocker| blocker.code == :cruise_contracted_rates_missing }
    items = rows.filter_map do |row|
      next unless row.status_label == "Needs review"

      AttentionItem.new(
        code: :rate_review,
        message: "Review #{row.stage_label} Supplier rates for #{category_label(row)}",
        resource_id: row.resource_id,
        stage: row.stage,
        advanced?: false
      )
    end
    blockers.each do |blocker|
      row = rows.find { |candidate| candidate.resource_id == blocker.resource_id }
      next if row&.status_label == "Needs review" && row.stage == "contracted"

      items << AttentionItem.new(
        code: :cruise_contracted_rates_missing,
        message: "Record contracted Supplier rates for #{category_label(row) || 'this category'}",
        resource_id: blocker.resource_id,
        stage: row&.stage,
        advanced?: row&.advanced? == true
      )
    end
    rows.each do |row|
      next unless row.status_label == "Not recorded"
      next if blockers.any? { |blocker| blocker.resource_id == row.resource_id }

      items << AttentionItem.new(
        code: :rates_missing,
        message: "Record Supplier rates for #{category_label(row)}",
        resource_id: row.resource_id,
        stage: nil,
        advanced?: false
      )
    end
    items
  end

  def category_label(row)
    return nil if row.nil?

    row.code.presence || row.name
  end

  def supplied_readiness(version)
    readiness = @readiness
    return nil if readiness.nil? || readiness.version&.id != version&.id

    readiness
  end
end
