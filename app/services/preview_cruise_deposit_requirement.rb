# frozen_string_literal: true

# Write-free Cruise deposit amount preview over a normalized candidate.
class PreviewCruiseDepositRequirement
  Result = Data.define(
    :status,
    :amount_minor_units,
    :components,
    :inputs,
    :pending_reasons,
    :quantity_label,
    :stale?,
    :version_lock_version
  )

  def self.call(**)
    new(**).call
  end

  def initialize(
    agency:,
    arrangement:,
    version:,
    candidate:,
    version_lock_version: nil,
    at: Time.current
  )
    @agency = agency
    @arrangement = arrangement
    @version = version
    @candidate = candidate
    @version_lock_version = version_lock_version
    @at = at
  end

  def call
    arrangement = @agency.supplier_arrangements.find(@arrangement.id)
    version = arrangement.versions.find(@version.id)

    if @version_lock_version.present? && version.lock_version != Integer(@version_lock_version)
      return Result.new(
        status: "stale",
        amount_minor_units: nil,
        components: [],
        inputs: {},
        pending_reasons: [ "This Arrangement version changed. Refresh before continuing." ],
        quantity_label: nil,
        stale?: true,
        version_lock_version: version.lock_version
      )
    end

    definition = build_unsaved_definition(version, @candidate.attributes)
    evaluated = SupplierDepositAmountEvaluator.call(
      definition: definition,
      version: version,
      arrangement: arrangement,
      mode: :preview,
      at: @at,
      coverage_links: @candidate.coverage_links,
      contributor_definition_ids: @candidate.contributor_definition_ids.presence
    )

    quantity_label = Array(evaluated[:components]).lazy
      .map { |row| row.with_indifferent_access[:quantity_label] }
      .find(&:present?)

    Result.new(
      status: "ready",
      amount_minor_units: evaluated[:amount_minor_units],
      components: evaluated[:components],
      inputs: evaluated[:inputs],
      pending_reasons: [],
      quantity_label: quantity_label,
      stale?: false,
      version_lock_version: version.lock_version
    )
  rescue SupplierDepositAmountEvaluator::IncompleteCalculation => error
    Result.new(
      status: "pending",
      amount_minor_units: nil,
      components: [],
      inputs: {},
      pending_reasons: [ error.message ],
      quantity_label: nil,
      stale?: false,
      version_lock_version: version.lock_version
    )
  end

  private

  def build_unsaved_definition(version, attributes)
    attrs = attributes.to_h.with_indifferent_access
    definition = version.supplier_deposit_requirement_definitions.build(
      agency_id: version.agency_id,
      amount_shape: attrs[:amount_shape],
      currency: attrs[:currency],
      fixed_amount_minor_units: attrs[:fixed_amount_minor_units],
      rate_minor_units: attrs[:rate_minor_units],
      quantity_basis: attrs[:quantity_basis],
      explicit_quantity: attrs[:explicit_quantity],
      percentage: attrs[:percentage],
      rounding_scope: attrs[:rounding_scope],
      target_amount_minor_units: attrs[:target_amount_minor_units],
      rule_shape: attrs[:rule_shape],
      rule_parameters: attrs[:rule_parameters],
      precision: attrs[:precision],
      time_zone: attrs[:time_zone],
      description: attrs[:description],
      position: next_position(version)
    )
    definition
  end

  def next_position(version)
    (version.supplier_deposit_requirement_definitions.maximum(:position) || 0) + 1
  end
end
