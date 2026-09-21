# frozen_string_literal: true

class DepartureBuilderWorkspace
  ComponentCard = Data.define(
    :service_offer, :version, :definition, :placement_label, :timing_label,
    :fulfillment_label, :package, :inclusion
  )

  def initialize(agency:, departure:, package_id: nil, work_on: nil)
    @agency = agency
    @departure = departure
    @requested_package_id = package_id
    @work_on = work_on.to_s.presence_in(%w[preview supplier pricing]) || "supplier"
  end

  attr_reader :work_on

  def readiness
    @readiness ||= EvaluateDepartureBuilderReadiness.new(agency: @agency, departure: @departure).call
  end

  def recommendation
    @recommendation ||= RecommendDepartureBuilderAction.new(
      agency: @agency, departure: @departure, readiness: readiness
    ).call
  end

  def editable_packages
    @editable_packages ||= @departure.packages.select { |package| package.editable_draft_version.present? }
  end

  def selected_package
    return if editable_packages.empty?

    @selected_package ||= editable_packages.find { |package| package.id.to_s == @requested_package_id.to_s } ||
      editable_packages.first
  end

  def component_cards
    cards = []
    if selected_package
      version = selected_package.editable_draft_version
      version.inclusions.includes(:service_offer, service_offer_version: :definition).order(:position, :id).each do |inclusion|
        offer_version = inclusion.service_offer_version
        cards << ComponentCard.new(
          service_offer: inclusion.service_offer,
          version: offer_version,
          definition: offer_version.definition,
          placement_label: inclusion.placement.titleize,
          timing_label: timing_label_for(offer_version.definition),
          fulfillment_label: fulfillment_label_for(offer_version.definition),
          package: selected_package,
          inclusion: inclusion
        )
      end
    end

    unassigned_offers.each do |offer|
      version = offer.editable_draft_version
      cards << ComponentCard.new(
        service_offer: offer,
        version: version,
        definition: version.definition,
        placement_label: "Not yet assigned",
        timing_label: timing_label_for(version.definition),
        fulfillment_label: fulfillment_label_for(version.definition),
        package: nil,
        inclusion: nil
      )
    end
    cards
  end

  def empty?
    editable_packages.empty? && unassigned_offers.empty?
  end

  def unassigned_offers
    @unassigned_offers ||= @departure.service_offers.select do |offer|
      version = offer.editable_draft_version
      version&.draft? && version.owning_package_version_id.nil?
    end.sort_by(&:created_at)
  end

  private

  def timing_label_for(definition)
    definition&.client_timing_text.presence || "Timing not added"
  end

  def fulfillment_label_for(definition)
    case definition&.fulfillment_basis
    when "undecided" then "Decide later"
    when "m3_backed" then "Supplier-backed"
    when "on_request" then "On request"
    when "agency_fulfilled" then "Agency fulfilled"
    when "externally_fulfilled" then "External fulfillment"
    else "—"
    end
  end
end
