# frozen_string_literal: true

module DepartureBuilderHelper
  def builder_recommendation_path(recommendation)
    return composition_fallback_path if recommendation.nil?

    case recommendation.path_helper.to_sym
    when :departure
      composition_fallback_path
    when :new_departure_builder_component, :new_departure_composition_service
      args = recommendation.path_args || {}
      new_departure_composition_service_path(@departure, package_id: args[:package_id], outcome: @outcome)
    when :departure_builder, :departure_composition
      departure_composition_path(@departure, composition_link_context(recommendation.path_args))
    when :departure_package
      departure_package_path(@departure, recommendation.path_args[:id])
    when :departure_service_offer
      departure_service_offer_path(@departure, recommendation.path_args[:id])
    when :fulfillment_departure_builder_component
      fulfillment_departure_builder_component_path(
        @departure,
        recommendation.path_args[:id],
        return_to: "services",
        outcome: @outcome,
        package_id: recommendation.path_args[:package_id] || @package_id
      )
    when :departure_activation
      departure_activation_path(@departure)
    when :services_departure_composition
      services_departure_composition_path(@departure, composition_link_context)
    when :suppliers_departure_composition
      suppliers_departure_composition_path(@departure, composition_link_context)
    when :package_departure_composition
      package_departure_composition_path(@departure, composition_link_context)
    when :review_departure_composition
      review_departure_composition_path(@departure, composition_link_context)
    else
      composition_fallback_path
    end
  end

  def builder_contextual_path(action)
    case action.path
    in [ :fulfillment, :departure_builder_component, departure, offer ]
      fulfillment_departure_builder_component_path(
        departure, offer, return_to: "services", outcome: @outcome, package_id: @package_id
      )
    in [ :departure_service_offer, departure, offer ]
      departure_service_offer_path(departure, offer)
    in [ :edit_departure_service_offer, departure, offer ]
      edit_departure_service_offer_path(departure, offer)
    in [ :departure_packages, departure ]
      departure_packages_path(departure)
    else
      composition_fallback_path
    end
  end

  def composition_link_context(extra = {})
    {
      outcome: @outcome,
      package_id: @package_id || @workspace&.selected_package&.id
    }.merge(extra || {}).compact_blank
  end

  def composition_area_path(summary)
    helper = summary.primary_route_helper.to_s
    helper = "#{helper}_path" unless helper.end_with?("_path", "_url")
    public_send(helper, @departure, composition_link_context)
  end

  def composition_fallback_path
    departure_composition_path(@departure, composition_link_context)
  end

  def composition_finding_path(finding)
    builder_recommendation_path(
      RecommendDepartureBuilderAction::Recommendation.new(
        finding: finding,
        label: finding.message,
        button_label: "Resolve",
        path_helper: finding.route_name,
        path_args: finding.route_params
      )
    )
  end

  def composition_outcome_label(outcome)
    CompositionAccess::OUTCOME_LABELS[outcome.to_s] || outcome.to_s.humanize
  end
end
