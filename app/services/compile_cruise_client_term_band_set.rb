# frozen_string_literal: true

class CompileCruiseClientTermBandSet
  Result = Data.define(:enabled, :authorizing_profiles, :copy_available, :unavailable_reasons, :saved_bands, :advanced?)

  def initialize(agency:, arrangement_version:, resource:)
    @agency = agency
    @arrangement_version = arrangement_version
    @resource = resource
  end

  def call
    shape = DetectCruiseSupplierRateShape.new(
      agency: @agency,
      arrangement: @arrangement_version.supplier_arrangement,
      resource: @resource,
      version: @arrangement_version
    ).call
    return advanced("More than one Supplier rate schedule applies to this category.") unless shape.compatible?

    profiles = confirmed_profiles
    return advanced("Confirm occupancy for this cabin category before entering Client terms.") if profiles.empty?

    enabled = []
    authorizing = {}
    profiles.each do |profile|
      count = profile.supplier_cost_occupancy_profile_positions.size
      case count
      when 1
        enable(enabled, authorizing, "single", profile)
      when 2
        enable(enabled, authorizing, "first", profile)
        enable(enabled, authorizing, "second", profile)
      else
        next if count < 3
        next unless additional_supported?(shape)

        enable(enabled, authorizing, "first", profile)
        enable(enabled, authorizing, "second", profile)
        enable(enabled, authorizing, "additional", profile)
      end
    end

    Result.new(
      enabled: CruiseClientTermRows::BANDS & enabled,
      authorizing_profiles: authorizing,
      copy_available: {},
      unavailable_reasons: {},
      saved_bands: [],
      advanced?: false
    )
  end

  private

  def confirmed_profiles
    assumption = @arrangement_version.supplier_cost_usage_assumptions.find_by(supplier_resource_id: @resource.id)
    return [] if assumption.nil?

    assumption.supplier_cost_occupancy_profiles.includes(:supplier_cost_occupancy_profile_positions).order(:position, :id).to_a
  end

  def additional_supported?(shape)
    return false if shape.empty?

    Array(shape.projected_matrix[:profile_details]).any? { |profile| profile[:family].to_s == "additional" || profile["family"].to_s == "additional" }
  end

  def enable(enabled, authorizing, key, profile)
    enabled << key
    authorizing[key] ||= profile.label
  end

  def advanced(reason)
    Result.new(
      enabled: [],
      authorizing_profiles: {},
      copy_available: {},
      unavailable_reasons: { base: reason },
      saved_bands: [],
      advanced?: true
    )
  end
end
