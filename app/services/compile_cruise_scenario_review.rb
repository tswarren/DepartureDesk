# frozen_string_literal: true

class CompileCruiseScenarioReview
  SCENARIOS = {
    "single" => { positions: %w[single], persons: 1 },
    "double" => { positions: %w[first second], persons: 2 },
    "triple" => { positions: %w[first second additional], persons: 3 }
  }.freeze

  def initialize(agency:, actor:, offer:, version:, option:)
    @agency = agency
    @actor = actor
    @offer = offer
    @version = version
    @option = option
  end

  def call
    workspace = CompileCruiseClientTermsWorkspace.new(agency: @agency, offer: @offer, version: @version).call
    category = workspace[:categories].find { |row| row[:option].id == @option.id }
    return [] if category.nil?

    enabled = category[:bands].enabled
    SCENARIOS.map do |name, spec|
      missing = spec[:positions] - enabled
      if missing.any?
        next {
          name: name, omitted: true, pending: false, price: nil, economics: nil, capacity: nil,
          reason: "#{name.humanize} is unavailable until #{missing.to_sentence} is enabled."
        }
      end

      scenario = EvaluateClientPrice::Scenario.build(
        occupancy_positions: spec[:positions].map { |key| { key: key, rate_category: @option.client_rate_category_key } },
        persons: spec[:persons],
        resource_units: 1,
        selected_option_ids: [ @option.id ]
      )
      price = @version.price_definition && EvaluateClientPrice.new(definition: @version.price_definition, scenario: scenario).call
      pending = spec[:positions].any? { |band| category[:components].none? { |component| component.occupancy_position_key == band && component.client_role == "base_price" } }
      economics = economics_for(scenario, price)
      {
        name: name,
        omitted: false,
        pending: pending,
        price: price,
        economics: economics,
        capacity: capacity_context(category),
        reason: pending ? "A required Client price is still blank." : nil
      }
    end
  end

  private

  def economics_for(scenario, price)
    return if @actor.nil?

    EvaluateIndicativeScenarioEconomics.new(
      agency: @agency, actor: @actor, offer: @offer, version: @version, scenario: scenario, price: price
    ).call
  rescue AgencyCommand::Error
    nil
  end

  def capacity_context(category)
    pool = CapacityPool.find_by(
      agency_id: @agency.id,
      supplier_arrangement_id: category[:binding].supplier_arrangement_id,
      supplier_resource_id: category[:resource].id
    )
    projection = pool&.capacity_projection
    if projection.nil?
      return { quantity: nil, observed_at: Time.current, text: "Capacity is not established. This is not promised inventory." }
    end

    {
      quantity: projection.current_supplier_capacity,
      observed_at: projection.rebuilt_at,
      text: "Current supplier capacity #{projection.current_supplier_capacity} as of #{projection.rebuilt_at.iso8601}. This is not promised inventory."
    }
  end
end
