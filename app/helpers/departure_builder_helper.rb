# frozen_string_literal: true

module DepartureBuilderHelper
  def builder_recommendation_path(recommendation)
    return departure_builder_path(@departure) if recommendation.nil?

    case recommendation.path_helper.to_sym
    when :departure
      departure_builder_path(@departure)
    when :new_departure_builder_component
      args = recommendation.path_args || {}
      new_departure_builder_component_path(@departure, package_id: args[:package_id])
    when :departure_builder
      departure_builder_path(@departure, recommendation.path_args.except(:id, :departure_id))
    when :departure_package
      departure_package_path(@departure, recommendation.path_args[:id])
    when :departure_service_offer
      departure_service_offer_path(@departure, recommendation.path_args[:id])
    when :fulfillment_departure_builder_component
      fulfillment_departure_builder_component_path(@departure, recommendation.path_args[:id])
    when :departure_activation
      departure_activation_path(@departure)
    else
      departure_builder_path(@departure)
    end
  end

  def builder_contextual_path(action)
    case action.path
    in [ :fulfillment, :departure_builder_component, departure, offer ]
      fulfillment_departure_builder_component_path(departure, offer)
    in [ :departure_service_offer, departure, offer ]
      departure_service_offer_path(departure, offer)
    in [ :edit_departure_service_offer, departure, offer ]
      edit_departure_service_offer_path(departure, offer)
    in [ :departure_packages, departure ]
      departure_packages_path(departure)
    else
      departure_builder_path(@departure)
    end
  end
end
