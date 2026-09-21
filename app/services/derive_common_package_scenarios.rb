# frozen_string_literal: true

class DeriveCommonPackageScenarios
  ScenarioSummary = Data.define(
    :key, :label, :complete, :amount_minor_units, :currency, :missing_inputs, :lines
  )
  Result = Data.define(:summaries)

  def initialize(agency:, package:)
    @agency = agency
    @package = package
  end

  def call
    version = @package.editable_draft_version || @package.current_published_version
    return Result.new(summaries: []) if version.nil?

    summaries = []
    summaries << summarize("two_travelers", "Two travelers", version, persons: 2)
    one_person = summarize("one_traveler", "One traveler", version, persons: 1)
    summaries << one_person if one_person.complete || one_person.missing_inputs.any?

    option_variation(version).each { |summary| summaries << summary }
    Result.new(summaries: summaries)
  end

  private

  def summarize(key, label, version, persons:)
    evaluation = EvaluatePackagePrice.new(
      package: @package,
      version: version,
      scenario: {
        persons: persons,
        resource_units: 1,
        nights: 7,
        service_instances: 1,
        occupancy_positions: occupancy_for(persons)
      },
      selected_inclusion_ids: included_ids(version)
    ).call

    ScenarioSummary.new(
      key: key,
      label: label,
      complete: evaluation.complete,
      amount_minor_units: evaluation.complete ? evaluation.amount_minor_units : nil,
      currency: evaluation.currency,
      missing_inputs: missing_from(evaluation),
      lines: Array(evaluation.lines)
    )
  rescue StandardError => error
    ScenarioSummary.new(
      key: key,
      label: label,
      complete: false,
      amount_minor_units: nil,
      currency: nil,
      missing_inputs: [ error.message ],
      lines: []
    )
  end

  def option_variation(version)
    groups = version.inclusions.includes(service_offer_version: { choice_groups: :service_offer_choice_options }).flat_map do |inclusion|
      inclusion.service_offer_version.choice_groups.to_a
    end
    option = groups.flat_map(&:service_offer_choice_options).find { |row| row.position.to_i > 1 }
    return [] if option.nil?

    evaluation = EvaluatePackagePrice.new(
      package: @package,
      version: version,
      scenario: {
        persons: 2,
        resource_units: 1,
        nights: 7,
        service_instances: 1,
        occupancy_positions: occupancy_for(2),
        selected_option_ids: [ option.id ]
      },
      selected_inclusion_ids: included_ids(version)
    ).call
    [
      ScenarioSummary.new(
        key: "option_#{option.id}",
        label: "With #{option.name}",
        complete: evaluation.complete,
        amount_minor_units: evaluation.complete ? evaluation.amount_minor_units : nil,
        currency: evaluation.currency,
        missing_inputs: missing_from(evaluation),
        lines: Array(evaluation.lines)
      )
    ]
  rescue StandardError
    []
  end

  def missing_from(evaluation)
    return [] if evaluation.complete

    Array(evaluation.blockers).map { |blocker| blocker.is_a?(Hash) ? blocker[:message] || blocker["message"] : blocker.to_s }
  end

  def included_ids(version)
    version.inclusions.select(&:included?).map { |row| row.id.to_s }
  end

  def occupancy_for(persons)
    persons.times.map { |index| { key: index.zero? ? "first" : "additional_#{index}" } }
  end
end
