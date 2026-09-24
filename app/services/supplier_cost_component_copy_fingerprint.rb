# frozen_string_literal: true

class SupplierCostComponentCopyFingerprint
  SNAPSHOT_KEYS = %w[
    schema mapped_client_role mapped_calculation_kind mapped_quantity_basis
    target_occupancy_position percentage_treatment base_semantics
  ].freeze

  def self.snapshot(mapped_client_role:, mapped_calculation_kind:, mapped_quantity_basis:, target_occupancy_position:)
    {
      "schema" => 1,
      "mapped_client_role" => mapped_client_role,
      "mapped_calculation_kind" => mapped_calculation_kind,
      "mapped_quantity_basis" => mapped_quantity_basis,
      "target_occupancy_position" => target_occupancy_position,
      "percentage_treatment" => nil,
      "base_semantics" => nil
    }
  end

  def self.valid_snapshot?(mapping)
    return false unless mapping.is_a?(Hash)
    data = mapping.stringify_keys
    data["schema"] == 1 && data.keys.map(&:to_s).sort == SNAPSHOT_KEYS.sort
  end

  def self.hexdigest(component, snapshot)
    Digest::SHA256.hexdigest(canonical_json(component, snapshot))
  end

  def self.canonical_json(component, snapshot)
    data = snapshot.stringify_keys
    JSON.generate({
      "schema" => 1,
      "source_role" => component.economic_role,
      "source_stage" => component.supplier_cost_definition.stage,
      "currency" => component.currency,
      "amount_minor_units" => component.amount_minor_units,
      "rate" => normalize_rate(component.rate),
      "source_quantity_basis" => component.quantity_basis,
      "participant_category" => component.participant_category&.label,
      "bases" => bases_for(component),
      "mapped_client_role" => data["mapped_client_role"],
      "mapped_calculation_kind" => data["mapped_calculation_kind"],
      "mapped_quantity_basis" => data["mapped_quantity_basis"],
      "target_occupancy_position" => data["target_occupancy_position"],
      "percentage_treatment" => data["percentage_treatment"],
      "base_semantics" => data["base_semantics"]
    })
  end

  def self.normalize_rate(rate)
    return nil if rate.nil?

    stripped = BigDecimal(rate.to_s).to_s("F").sub(/\.?0+\z/, "")
    stripped.presence || "0"
  end

  def self.bases_for(component)
    component.supplier_cost_component_bases.sort_by { |base| [ base.position, base.id ] }.map do |link|
      source = link.base_component
      {
        "economic_role" => source.economic_role,
        "calculation_kind" => source.calculation_kind,
        "direction" => link.direction
      }
    end
  end

  private_class_method :normalize_rate, :bases_for
end
