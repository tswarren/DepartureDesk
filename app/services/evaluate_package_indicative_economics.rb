# frozen_string_literal: true

class EvaluatePackageIndicativeEconomics
  def initialize(agency:, actor:, package:, version: nil, scenario: {}, selected_inclusion_ids: [])
    @agency = agency
    @actor = actor
    @package = package
    @version = version || package.editable_draft_version
    @scenario = scenario.is_a?(EvaluateClientPrice::Scenario) ? scenario : EvaluateClientPrice::Scenario.build(scenario)
    @selected_inclusion_ids = selected_inclusion_ids
  end

  def call
    price = EvaluatePackagePrice.new(
      package: @package, version: @version, scenario: @scenario,
      selected_inclusion_ids: @selected_inclusion_ids,
      selected_option_ids: @scenario.selected_option_ids
    ).call
    return unknown("Client revenue is incomplete.", price: price) unless price.complete

    sources = []
    selected_inclusions.each do |inclusion|
      collected = CollectSelectedOfferBindings.new(
        version: inclusion.service_offer_version,
        scenario: @scenario,
        package_preview: true
      ).call
      next if collected.status != :ok

      matcher = source_matcher
      next if matcher.nil?

      collected.bindings.each do |binding|
        sources.concat(matcher.sources_for_binding(binding))
      end
    end
    sources = sources.uniq(&:id)
    return unknown("No attributable Supplier cost source.", price: price) if sources.empty?

    seed_offer = selected_inclusions.first.service_offer
    EvaluateIndicativeScenarioEconomics.new(
      agency: @agency,
      actor: @actor,
      offer: seed_offer,
      version: selected_inclusions.first.service_offer_version,
      scenario: @scenario,
      price: price,
      package_preview: true,
      attributed_sources: sources
    ).call
  end

  private

  def selected_inclusions
    inclusions = @version.inclusions.includes(:service_offer, service_offer_version: :source_bindings).order(:position).to_a
    ids = Array(@selected_inclusion_ids).map(&:to_s)
    inclusions.select { |inclusion| inclusion.included? || ids.include?(inclusion.id.to_s) }
  end

  def source_matcher
    offer = selected_inclusions.first&.service_offer
    return if offer.nil?

    @source_matcher ||= EvaluateIndicativeScenarioEconomics.new(
      agency: @agency,
      actor: @actor,
      offer: offer,
      scenario: @scenario,
      package_preview: true
    )
  end

  def unknown(reason, price: nil)
    EvaluateIndicativeScenarioEconomics::Result.new(
      status: :unknown,
      label: "indicative scenario economics",
      client_revenue_minor_units: price&.amount_minor_units,
      forecast_supplier_cost_minor_units: nil,
      expected_commission_minor_units: nil,
      indicative_margin_minor_units: nil,
      currency: price&.currency,
      price: price,
      attributed_source_ids: [],
      reason: reason,
      observed_at: Time.current
    )
  end
end
