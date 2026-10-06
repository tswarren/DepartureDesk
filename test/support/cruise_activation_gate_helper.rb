# frozen_string_literal: true

module CruiseActivationGateHelper
  def satisfy_cruise_activation_gate!(agency:, actor:, arrangement:, version:)
    return unless version.arrangement_item_definitions.any? { |item| item.category == "cruise" }

    unless version.supplier_arrangement_cruise_agreement_confirmations.exists?(current: true, status: "confirmed")
      version.supplier_arrangement_cruise_agreement_confirmations.create!(
        agency: agency,
        departure: arrangement.departure,
        supplier_arrangement: arrangement,
        status: "confirmed",
        current: true,
        group_reference: "1119999",
        contract_date: Date.new(2026, 9, 13),
        group_creation_date: Date.new(2026, 9, 13),
        confirmed_at: Time.current,
        confirmed_by: actor
      )
    end

    occurrence = version.service_occurrence_definitions.order(:id).first
    version.supplier_resource_definitions.each do |resource_definition|
      source = version.supplier_cost_sources.find_by(
        supplier_resource_id: resource_definition.supplier_resource_id,
        arrangement_item_id: resource_definition.arrangement_item_id,
        service_occurrence_id: occurrence&.service_occurrence_id
      )
      if source&.supplier_cost_definitions&.any? { |definition| definition.contracted? && definition.forecast_ready? }
        source.supplier_cost_definitions.each do |definition|
          next unless definition.contracted? && definition.forecast_ready?

          stamp_cruise_contract_review!(definition, actor)
        end
        next
      end

      source ||= version.supplier_cost_sources.create!(
        agency: agency,
        departure: arrangement.departure,
        supplier_arrangement: arrangement,
        arrangement_item_id: resource_definition.arrangement_item_id,
        service_occurrence_id: occurrence&.service_occurrence_id,
        supplier_resource_id: resource_definition.supplier_resource_id,
        charging_supplier: arrangement.contracting_supplier,
        label: "#{resource_definition.supplier_code} contracted rates",
        position: version.supplier_cost_sources.maximum(:position).to_i + 1
      )
      next if source.supplier_cost_definitions.exists?(stage: "contracted", status: "forecast_ready")

      definition = source.supplier_cost_definitions.create!(
        agency: agency,
        departure: arrangement.departure,
        supplier_arrangement: arrangement,
        supplier_arrangement_version: version,
        stage: "contracted",
        status: "forecast_ready",
        mode: "zero_cost",
        zero_cost_reason: "Included",
        currency: arrangement.departure.operating_currency,
        forecast_ready_by: actor,
        forecast_ready_at: Time.current,
        readiness_fingerprint: "sha256:cruise-activation-gate",
        readiness_provenance: "Signed terms"
      )
      stamp_cruise_contract_review!(definition, actor)
    end
  end

  def stamp_cruise_contract_review!(definition, actor)
    return if definition.contract_review_current?

    definition.update_columns(
      contract_reviewed_by_id: actor.id,
      contract_reviewed_at: definition.forecast_ready_at || Time.current,
      contract_review_fingerprint: SupplierCostDefinitionFingerprint.call(definition),
      contract_review_provenance: definition.readiness_provenance.presence || "Signed terms",
      updated_at: Time.current
    )
  end
end
