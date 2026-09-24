# frozen_string_literal: true

class ProposeCruiseSupplierTermCopy
  Result = Data.define(:cells, :unsupported)
  Cell = Data.define(
    :row_key, :band, :amount, :label, :source_id, :source_label, :source_amount,
    :role, :expands
  )

  CLIENT_ROWS = {
    "base_fare" => "cruise_fare",
    "nccf" => "nccf",
    "taxes_fees" => "taxes_fees",
    "discount" => "discount"
  }.freeze

  def initialize(agency:, arrangement_version:, resource:, enabled_bands:)
    @agency = agency
    @arrangement_version = arrangement_version
    @resource = resource
    @enabled_bands = Array(enabled_bands)
  end

  def call
    shape = DetectCruiseSupplierRateShape.new(
      agency: @agency,
      arrangement: @arrangement_version.supplier_arrangement,
      resource: @resource,
      version: @arrangement_version
    ).call
    return Result.new(cells: [], unsupported: shape.reasons.presence || [ "Supplier rates are not available to copy." ]) unless shape.compatible?
    return Result.new(cells: [], unsupported: [ "Enter Supplier rates before copying them." ]) if shape.empty? || shape.definition.nil?

    proposals = []
    unsupported = []
    shape.definition.supplier_cost_components.sort_by { |component| [ component.position, component.id ] }.each do |component|
      classify(component, proposals, unsupported)
    end
    Result.new(cells: without_collisions(proposals, unsupported), unsupported: unsupported)
  end

  private

  def classify(component, proposals, unsupported)
    if component.economic_role.in?(%w[expected_commission informational_allocation])
      unsupported << "#{component.label} is not copied into Client terms."
      return
    end
    unless %w[supplier_charge supplier_credit].include?(component.economic_role) && %w[fixed unit_rate].include?(component.calculation_kind)
      unsupported << "#{component.label} cannot be copied."
      return
    end
    return if component.amount_minor_units.nil?

    row_key, family = source_mapping(component)
    if row_key.nil? || family.nil?
      unsupported << "#{component.label} is not a traveler-position Client term."
      return
    end

    targets = target_bands(row_key, family)
    if targets.empty?
      unsupported << "#{component.label} does not cover an enabled traveler position."
      return
    end

    client_row = row_key == "base_fare" && family == "single_supplement" ? "single_supplement" : CLIENT_ROWS[row_key]
    if client_row.nil?
      unsupported << "#{component.label} is not a standard Client term."
      return
    end

    amount = format("%.2f", Money.new(component.amount_minor_units, component.currency).amount)
    targets.each do |band|
      proposals << Cell.new(
        row_key: client_row,
        band: band,
        amount: amount,
        label: CruiseClientTermRows.label_for(client_row),
        source_id: component.id,
        source_label: component.label,
        source_amount: amount,
        role: CruiseClientTermRows.role_for(client_row),
        expands: targets.size > 1
      )
    end
  end

  def source_mapping(component)
    legacy = CruiseSupplierRateSupport::LEGACY_LABEL_TO_CELL[component.label]
    if legacy
      return [ legacy[0].to_s, legacy[1].to_s ]
    end

    row_key = CruiseSupplierRateSupport.static_row_key_for_label(component.label)&.to_s
    profile = CruiseSupplierRateSupport.profile_key_for_component(component)
    return [ nil, nil ] if row_key.blank? || profile.blank?

    decoded = CruiseSupplierRateSupport.decode_profile_key(profile)
    [ row_key, decoded[:family].to_s ]
  end

  def target_bands(row_key, family)
    candidates = case family
    when "first_second" then %w[first second]
    when "additional" then %w[additional]
    when "every_traveler" then @enabled_bands
    when "single_supplement" then %w[single]
    else []
    end
    client_row = row_key == "base_fare" && family == "single_supplement" ? "single_supplement" : CLIENT_ROWS[row_key]
    allowed = client_row ? CruiseClientTermRows.allowed_bands(client_row) : []
    candidates & @enabled_bands & allowed
  end

  def without_collisions(proposals, unsupported)
    grouped = proposals.group_by { |cell| [ cell.row_key, cell.band ] }
    grouped.flat_map do |(row_key, band), cells|
      sources = cells.map(&:source_id).uniq
      if sources.size > 1
        unsupported << "Several Supplier terms map to #{CruiseClientTermRows.label_for(row_key)} #{band}."
        []
      else
        cells
      end
    end
  end
end
