# frozen_string_literal: true

class DepartureBuilderWorkspace
  ComponentCard = Data.define(
    :service_offer, :version, :definition, :placement_label, :timing_label,
    :fulfillment_label, :price_label, :package, :inclusion
  )
  ContextualAction = Data.define(:label, :path, :method)

  def initialize(agency:, departure:, package_id: nil, work_on: nil, require_explicit_package: false)
    @agency = agency
    @departure = departure
    @requested_package_id = package_id
    @work_on = work_on.to_s.presence_in(%w[preview supplier pricing])
    @require_explicit_package = require_explicit_package
  end

  attr_reader :work_on

  def readiness
    @readiness ||= EvaluateDepartureBuilderReadiness.new(agency: @agency, departure: @departure).call
  end

  def recommendation
    @recommendation ||= RecommendDepartureBuilderAction.new(
      agency: @agency,
      departure: @departure,
      readiness: readiness,
      work_on: @work_on
    ).call
  end

  def editable_packages
    @editable_packages ||= @departure.packages.select { |package| package.editable_draft_version.present? }
  end

  def package_selection_required?
    @require_explicit_package && editable_packages.size > 1 && @requested_package_id.blank?
  end

  def package_selection_invalid?
    return false if @requested_package_id.blank?
    return false if editable_packages.empty?

    editable_packages.none? { |package| package.id.to_s == @requested_package_id.to_s }
  end

  def selected_package
    return if editable_packages.empty?
    return if package_selection_required? || package_selection_invalid?

    @selected_package ||= if editable_packages.one?
      editable_packages.first
    else
      editable_packages.find { |package| package.id.to_s == @requested_package_id.to_s }
    end
  end

  def component_cards
    cards = []
    if selected_package
      version = selected_package.editable_draft_version
      version.inclusions.includes(:service_offer, service_offer_version: [ :definition, :price_definition ])
        .order(:position, :id).each do |inclusion|
        offer_version = inclusion.service_offer_version
        cards << build_card(
          inclusion.service_offer, offer_version, inclusion.placement.titleize, selected_package, inclusion
        )
      end
    end

    unassigned_offers.each do |offer|
      version = offer.editable_draft_version
      cards << build_card(offer, version, "Not yet assigned", nil, nil)
    end
    cards
  end

  def contextual_action_for(card)
    case @work_on
    when "supplier"
      if card.definition&.undecided?
        ContextualAction.new(
          label: "Decide how provided",
          path: [ :fulfillment, :departure_builder_component, @departure, card.service_offer ],
          method: :get
        )
      elsif card.definition&.m3_backed?
        ContextualAction.new(
          label: "Review Supplier support",
          path: [ :departure_service_offer, @departure, card.service_offer ],
          method: :get
        )
      else
        ContextualAction.new(
          label: "Review provision",
          path: [ :fulfillment, :departure_builder_component, @departure, card.service_offer ],
          method: :get
        )
      end
    when "pricing"
      ContextualAction.new(
        label: "Set component price",
        path: [ :departure_service_offer, @departure, card.service_offer ],
        method: :get
      )
    when "preview"
      ContextualAction.new(
        label: card.timing_label == "Timing not added" ? "Add Client timing" : "View component details",
        path: [ :edit_departure_service_offer, @departure, card.service_offer ],
        method: :get
      )
    else
      if card.inclusion.nil?
        ContextualAction.new(
          label: "Assign to a Package",
          path: [ :departure_packages, @departure ],
          method: :get
        )
      elsif card.definition&.undecided?
        ContextualAction.new(
          label: "Decide how provided",
          path: [ :fulfillment, :departure_builder_component, @departure, card.service_offer ],
          method: :get
        )
      elsif card.timing_label == "Timing not added"
        ContextualAction.new(
          label: "Add Client timing",
          path: [ :edit_departure_service_offer, @departure, card.service_offer ],
          method: :get
        )
      else
        ContextualAction.new(
          label: "View component details",
          path: [ :departure_service_offer, @departure, card.service_offer ],
          method: :get
        )
      end
    end
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

  def build_card(offer, version, placement_label, package, inclusion)
    definition = version.definition
    ComponentCard.new(
      service_offer: offer,
      version: version,
      definition: definition,
      placement_label: placement_label,
      timing_label: timing_label_for(definition),
      fulfillment_label: fulfillment_label_for(definition),
      price_label: price_label_for(version),
      package: package,
      inclusion: inclusion
    )
  end

  def timing_label_for(definition)
    definition&.client_timing_text.presence || "Timing not added"
  end

  def fulfillment_label_for(definition)
    case definition&.fulfillment_basis
    when "undecided" then "Decide later"
    when "m3_backed" then "Supplier-supported"
    when "on_request" then "On request"
    when "agency_fulfilled" then "Agency fulfilled"
    when "externally_fulfilled" then "External fulfillment"
    else "—"
    end
  end

  def price_label_for(version)
    return "Client price set" if version.price_definition.present?

    "Pending — Client price"
  end
end
