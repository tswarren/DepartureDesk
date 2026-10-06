# frozen_string_literal: true

# Presentation facts for the Supplier rates workspace. Rows are the typed
# Cruise cabin categories from Cabin inventory, not every Supplier Resource.
# Scenario amounts come from CompileCruiseSupplierRatePreview. Stage prefers
# a Contracted definition when one exists. Readiness is that definition's
# forecast-ready status. Commission text is the recorded term when that term
# is one percentage or one dollar amount.
class CompileCruiseSupplierRatesWorkspace
  Illustration = Data.define(:key, :label, :gross_minor_units, :currency, :available?)
  AttentionItem = Data.define(:code, :message, :resource_id, :stage, :advanced?)
  Row = Data.define(
    :resource_id, :code, :name, :stage, :stage_label, :status_label,
    :advanced?, :commission_label, :illustrations, :single, :double, :triple
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
  SINGLE_KEYS = %w[single single_adult].freeze
  DOUBLE_KEYS = %w[double double_adult].freeze
  TRIPLE_KEYS = %w[triple].freeze

  def initialize(agency:, arrangement:, shape:, readiness: nil, cabin_rows: nil)
    @agency = agency
    @arrangement = arrangement
    @shape = shape
    @readiness = readiness
    @cabin_rows = cabin_rows
  end

  def call
    return empty_result(advanced: true) unless @shape.compatible?

    version = @shape.version
    return empty_result(advanced: false) if version.nil?

    rows = cabin_category_definitions(version).map do |definition|
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
      status_label: rate_status_label(preview.definition),
      advanced?: false,
      commission_label: commission_label_for(preview),
      **scenario_fields(illustrations_for(preview))
    )
  end

  def cabin_category_definitions(version)
    resource_ids = cabin_category_rows.filter_map { |row|
      row.resource_id unless row.inventory_label == "Inventory not configured"
    }
    version.supplier_resource_definitions
      .includes(:supplier_resource)
      .where(supplier_resource_id: resource_ids)
      .order(:position, :id)
  end

  def cabin_category_rows
    return @cabin_rows if @cabin_rows

    CompileCruiseCompositionSummary.new(
      agency: @agency,
      arrangement: @arrangement,
      shape: @shape
    ).cabin_inventory_rows
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
      **scenario_fields([])
    )
  end

  def scenario_fields(illustrations)
    {
      illustrations: illustrations,
      single: scenario_for(illustrations, SINGLE_KEYS),
      double: scenario_for(illustrations, DOUBLE_KEYS),
      triple: scenario_for(illustrations, TRIPLE_KEYS)
    }
  end

  def scenario_for(illustrations, keys)
    illustrations.find { |illustration| keys.include?(illustration.key) } ||
      Illustration.new(key: keys.first, label: nil, gross_minor_units: nil, currency: nil, available?: false)
  end

  def rate_status_label(definition)
    return "Not recorded" unless definition
    return "Ready" if definition.forecast_ready?
    return "Reviewed" if definition.contract_review_current?

    "Needs review"
  end

  def commission_label_for(preview)
    method = preview.commission_method.to_s
    return "Not provided yet" if method.blank? || method == "not_provided"
    return "No commission expected" if method == "none"

    definition = preview.definition
    components = definition&.supplier_cost_components.to_a.select { |component|
      component.economic_role == "expected_commission"
    }
    case method
    when "percentage"
      rates = components.select { |component| component.calculation_kind == "percentage" }
        .filter_map(&:rate)
        .map { |rate| BigDecimal(rate.to_s) }
        .uniq
      return recorded_percent_label(rates.first) if rates.one?

      "Percentage"
    when "dollar"
      amounts = components.select { |component| component.calculation_kind == "unit_rate" }
        .filter_map(&:amount_minor_units)
        .uniq
      if amounts.one? && preview.currency.present?
        return Money.new(amounts.first, preview.currency).format
      end

      "Dollar amount"
    else
      COMMISSION_LABELS.fetch(method, "—")
    end
  end

  def recorded_percent_label(rate)
    percent = BigDecimal(rate.to_s) * 100
    text = percent.frac.zero? ? percent.to_i.to_s : percent.to_s("F").sub(/\.?0+\z/, "")
    "#{text}%"
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
      next if row.nil?
      next if row.status_label == "Needs review" && row.stage == "contracted"

      items << AttentionItem.new(
        code: :cruise_contracted_rates_missing,
        message: "Record contracted Supplier rates for #{category_label(row)}",
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
