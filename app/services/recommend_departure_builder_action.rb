# frozen_string_literal: true

class RecommendDepartureBuilderAction
  Recommendation = Data.define(:finding, :label)

  STATE_RANK = {
    "blocked" => 0,
    "needs_attention" => 1,
    "incomplete" => 2,
    "waiting" => 3
  }.freeze

  def initialize(agency:, departure:, readiness: nil)
    @agency = agency
    @departure = departure
    @readiness = readiness
  end

  def call
    findings = (@readiness || EvaluateDepartureBuilderReadiness.new(agency: @agency, departure: @departure).call).findings
    actionable = findings.reject { |finding| finding.state.to_s == "waiting" }
    chosen = (actionable.presence || findings).min_by { |finding| STATE_RANK.fetch(finding.state.to_s, 9) }
    return if chosen.nil?

    Recommendation.new(finding: chosen, label: chosen.message)
  end
end
