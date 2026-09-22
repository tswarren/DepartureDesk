# frozen_string_literal: true

class SummarizeDepartureCompositionAreas
  AreaSummary = Data.define(:key, :label, :status, :finding_count, :primary_route_helper, :primary_route_args)

  AREAS = [
    [ "services", "Services", :services_departure_composition_path ],
    [ "suppliers", "Suppliers", :suppliers_departure_composition_path ],
    [ "package", "Package & Client terms", :package_departure_composition_path ],
    [ "review", "Review", :review_departure_composition_path ]
  ].freeze

  def initialize(agency:, actor:, departure:, outcome: nil, package: nil, readiness: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @outcome = outcome.to_s.presence
    @outcome = "proposal" if @outcome == "preview"
    @package = package
    @readiness = readiness
  end

  def call
    findings = readiness.findings
    AREAS.map do |key, label, route_helper|
      area_findings = findings.select { |finding| finding.affected_area == key }
      relevant = if @outcome.present?
        area_findings.select { |finding| finding.applicable_to?(@outcome) }
      else
        area_findings
      end
      AreaSummary.new(
        key: key,
        label: label,
        status: status_for(key, relevant),
        finding_count: relevant.size,
        primary_route_helper: route_helper,
        primary_route_args: route_args
      )
    end
  end

  private

  def readiness
    @readiness ||= EvaluateDepartureBuilderReadiness.new(agency: @agency, departure: @departure).call
  end

  def route_args
    args = { departure_id: @departure.id }
    args[:outcome] = @outcome if @outcome.present?
    args[:package_id] = @package.id if @package
    args
  end

  def status_for(key, findings)
    return "Needs attention" if findings.any? { |finding| %w[blocked needs_attention].include?(finding.state.to_s) }
    return "In progress" if findings.any? { |finding| finding.state.to_s == "incomplete" }
    return "Not started" if not_started?(key)
    return "In progress" if findings.any?
    return "Ready for outcome" if ready?(key)

    "In progress"
  end

  def not_started?(key)
    case key
    when "services"
      editable_offers.none? && editable_packages.none?
    when "suppliers"
      @departure.supplier_arrangements.none? &&
        editable_offers.none? { |offer| offer.editable_draft_version&.definition&.m3_backed? }
    when "package"
      editable_packages.none?
    when "review"
      editable_offers.none? && editable_packages.none?
    else
      false
    end
  end

  def ready?(key)
    case key
    when "services"
      editable_packages.any? || editable_offers.any?
    when "suppliers"
      @departure.supplier_arrangements.any? ||
        editable_offers.any? { |offer| !offer.editable_draft_version&.definition&.undecided? }
    when "package"
      editable_packages.any? &&
        editable_packages.all? { |package| package.editable_draft_version&.price_definition.present? }
    when "review"
      editable_packages.any? || editable_offers.any?
    else
      false
    end
  end

  def editable_packages
    @editable_packages ||= @departure.packages.select { |package| package.editable_draft_version.present? }
  end

  def editable_offers
    @editable_offers ||= @departure.service_offers.select { |offer| offer.editable_draft_version.present? }
  end
end
