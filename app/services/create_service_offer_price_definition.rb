# frozen_string_literal: true

class CreateServiceOfferPriceDefinition < AgencyCommand
  include PriceCommandSupport

  def initialize(agency:, actor:, offer:, attributes:, version_lock_version:, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @offer = offer
    @attributes = attributes.to_h.with_indifferent_access
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key || @attributes.delete(:idempotency_key)
  end

  def call
    ensure_offer_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      departure, offer, version = lock_departure_offer_draft!(@offer)
      ensure_offer_draft_editable!(departure, offer, version)
      ensure_departure_accepts_price_expansion!(departure)
      currency = require_operating_currency!(departure)
      mode_attrs = normalize_price_mode(@attributes)
      components = component_payload(@attributes, currency: currency, mode: mode_attrs[:mode])
      payload = {
        service_offer_id: offer.id,
        service_offer_version_id: version.id,
        mode: mode_attrs[:mode],
        zero_price_reason: mode_attrs[:zero_price_reason],
        components: digestable_components(components)
      }

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: payload,
        result_class: ServiceOfferPriceDefinition
      ) do
        ensure_current_lock_version!(version, @version_lock_version)
        if version.price_definition
          raise Error.new("This service offer already has a price.", code: :invalid_state)
        end

        definition = ServiceOfferPriceDefinition.create!(
          agency: @agency,
          departure: departure,
          service_offer: offer,
          service_offer_version: version,
          currency: currency,
          rounding_mode: "half_up",
          **mode_attrs
        )
        created = if definition.calculated?
          replace_price_components!(definition, version, offer, departure, components)
        else
          []
        end
        bump_version!(version)
        audit!(
          agency: @agency,
          action: "service_offer.price_created",
          subject: offer,
          actor: @actor,
          details: price_audit_details(offer, version, definition, component_count: created.size)
        )
        definition
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid
    raise Error.new("That Client price is invalid.", code: :invalid)
  end

  private

  def component_payload(attributes, currency:, mode:)
    return [] if mode == "zero_price"
    return components_from_pattern(attributes, currency: currency) if attributes[:pattern].present?

    Array(attributes[:components]).presence ||
      raise(Error.new("Enter a price pattern or components.", code: :invalid))
  end

  def digestable_components(components)
    components.map do |component|
      component.to_h.deep_stringify_keys
    end
  end
end
