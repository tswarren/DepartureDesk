# frozen_string_literal: true

module OfferVersionGraphCopy
  module_function

  def copy_service_offer_version!(agency:, departure:, offer:, from:, to:)
    if from.definition
      to.create_definition!(
        agency:, departure:, service_offer: offer,
        client_title: from.definition.client_title,
        client_description: from.definition.client_description,
        client_timing_text: from.definition.client_timing_text,
        fulfillment_basis: from.definition.fulfillment_basis
      )
    end

    binding_map = {}
    from.source_bindings.order(:position).each do |binding|
      attrs = binding.attributes.except(
        "id", "service_offer_version_id", "created_at", "updated_at", "lock_version"
      )
      copy = to.source_bindings.create!(attrs.merge(
        "agency_id" => agency.id,
        "departure_id" => departure.id,
        "service_offer_id" => offer.id,
        "service_offer_version_id" => to.id
      ))
      binding_map[binding.id] = copy
    end

    if from.price_definition
      price = to.create_price_definition!(
        agency:, departure:, service_offer: offer,
        currency: from.price_definition.currency,
        mode: from.price_definition.mode,
        rounding_mode: from.price_definition.rounding_mode
      )
      component_map = {}
      from.price_definition.service_offer_price_components.order(:position).each do |component|
        copied = price.service_offer_price_components.create!(
          agency:, departure:, service_offer: offer, service_offer_version: to,
          label: component.label, client_role: component.client_role,
          calculation_kind: component.calculation_kind, quantity_basis: component.quantity_basis,
          amount_minor_units: component.amount_minor_units, percentage_rate: component.percentage_rate,
          percentage_treatment: component.percentage_treatment,
          occupancy_position_key: component.occupancy_position_key,
          client_rate_category_key: component.client_rate_category_key,
          position: component.position
        )
        component_map[component.id] = copied
      end
      ServiceOfferPriceComponentBase.where(service_offer_version_id: from.id).find_each do |base|
        next unless component_map[base.service_offer_price_component_id] && component_map[base.base_component_id]

        ServiceOfferPriceComponentBase.create!(
          agency:, departure:, service_offer: offer, service_offer_version: to,
          service_offer_price_component: component_map[base.service_offer_price_component_id],
          base_component: component_map[base.base_component_id]
        )
      end
    end

    option_map = {}
    from.choice_groups.order(:position).each do |group|
      new_group = to.choice_groups.create!(
        agency:, departure:, service_offer: offer,
        name: group.name, min_selections: group.min_selections,
        max_selections: group.max_selections, position: group.position
      )
      group.service_offer_choice_options.order(:position).each do |option|
        new_option = new_group.service_offer_choice_options.create!(
          agency:, departure:, service_offer: offer, service_offer_version: to,
          name: option.name, client_description: option.client_description,
          price_effect_minor_units: option.price_effect_minor_units, position: option.position
        )
        option_map[option.id] = new_option
        activation = option.source_activation
        next unless activation

        new_option.create_source_activation!(
          agency:, departure:, service_offer: offer, service_offer_version: to,
          activation_kind: activation.activation_kind,
          service_offer_source_binding: binding_map[activation.service_offer_source_binding_id],
          alternative_group_key: activation.alternative_group_key
        )
      end
    end

    copy_terms!(agency:, departure:, offer:, from:, to:)
  end

  def copy_terms!(agency:, departure:, offer:, from:, to:)
    if from.payment_schedule
      schedule = to.create_payment_schedule!(
        agency:, departure:, service_offer: offer, name: from.payment_schedule.name
      )
      from.payment_schedule.service_offer_client_payment_schedule_lines.order(:position).each do |line|
        schedule.service_offer_client_payment_schedule_lines.create!(
          agency:, departure:, service_offer: offer, service_offer_version: to,
          label: line.label, amount_minor_units: line.amount_minor_units,
          percentage_rate: line.percentage_rate, due_kind: line.due_kind,
          due_on: line.due_on, days_offset: line.days_offset, position: line.position
        )
      end
    end
    if from.cancellation_policy
      policy = to.create_cancellation_policy!(
        agency:, departure:, service_offer: offer,
        name: from.cancellation_policy.name,
        manual_review: from.cancellation_policy.manual_review,
        manual_review_text: from.cancellation_policy.manual_review_text
      )
      from.cancellation_policy.service_offer_client_cancellation_tiers.order(:position).each do |tier|
        policy.service_offer_client_cancellation_tiers.create!(
          agency:, departure:, service_offer: offer, service_offer_version: to,
          label: tier.label, amount_minor_units: tier.amount_minor_units,
          percentage_rate: tier.percentage_rate, threshold_kind: tier.threshold_kind,
          threshold_on: tier.threshold_on, days_before_start: tier.days_before_start,
          position: tier.position
        )
      end
    end
    from.stated_conditions.order(:position).each do |condition|
      to.stated_conditions.create!(
        agency:, departure:, service_offer: offer,
        label: condition.label, body: condition.body, position: condition.position
      )
    end
  end
end
