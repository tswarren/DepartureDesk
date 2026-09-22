# frozen_string_literal: true

class RecommendDepartureBuilderAction
  Recommendation = Data.define(:finding, :label, :button_label, :path_helper, :path_args)

  STATE_RANK = {
    "blocked" => 0,
    "needs_attention" => 1,
    "incomplete" => 2,
    "waiting" => 3
  }.freeze

  EARLY_OUTLINE_CODES = %i[
    no_components no_package empty_package undecided_fulfillment
  ].freeze

  def initialize(agency:, departure:, readiness: nil, work_on: nil, outcome: nil)
    @agency = agency
    @departure = departure
    @readiness = readiness
    raw = (outcome.presence || work_on).to_s
    raw = "proposal" if raw == "preview"
    @outcome = raw.presence
  end

  def call
    findings = (@readiness || EvaluateDepartureBuilderReadiness.new(agency: @agency, departure: @departure).call).findings
    ordered = prefer_outcome(findings)
    return if ordered.empty?

    actionable = ordered.reject { |finding| finding.state.to_s == "waiting" }
    pool = actionable.presence || ordered
    if early_outline?(findings) && @outcome != "publication"
      pool = pool.reject { |finding| early_publication_noise?(finding) }
    end
    chosen = pool.min_by { |finding| STATE_RANK.fetch(finding.state.to_s, 9) }
    return if chosen.nil?

    Recommendation.new(
      finding: chosen,
      label: chosen.message,
      button_label: button_label_for(chosen),
      path_helper: chosen.route_name,
      path_args: chosen.route_params
    )
  end

  private

  def prefer_outcome(findings)
    return findings if @outcome.blank?

    findings.select { |finding| finding.applicable_to?(@outcome) }
  end

  def early_outline?(findings)
    findings.any? { |finding| EARLY_OUTLINE_CODES.include?(finding.code) }
  end

  def early_publication_noise?(finding)
    finding.group == "Ready to publish" ||
      finding.code == :departure_not_active ||
      finding.code.to_s.end_with?("_not_ready")
  end

  def button_label_for(finding)
    case finding.code
    when :no_components then "Add the first component"
    when :no_package then "Create main package"
    when :empty_package then "Add a component"
    when :undecided_fulfillment then "Decide how provided"
    when :package_price_missing then "Set Package price"
    when :component_price_pending then "Set component price"
    else finding.message.to_s.split(".").first.presence || "Continue"
    end
  end
end
