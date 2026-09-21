# frozen_string_literal: true

class UpdateServiceOfferPriceDefinition < AgencyCommand
  include PriceCommandSupport

  def initialize(agency:, actor:, offer:, attributes:, version_lock_version:)
    @agency = agency
    @actor = actor
    @offer = offer
    @attributes = attributes.to_h.with_indifferent_access
    @version_lock_version = version_lock_version
  end

  def call
    ensure_offer_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      departure, offer, version = lock_departure_offer_draft!(@offer)
      ensure_offer_draft_editable!(departure, offer, version)
      ensure_departure_accepts_price_expansion!(departure)
      ensure_current_lock_version!(version, @version_lock_version)
      definition = lock_price_definition!(version)
      raise Error.new("That service offer has no price to update.", code: :invalid_state) if definition.nil?

      currency = require_operating_currency!(departure)
      mode_attrs = normalize_price_mode(@attributes)
      components = if mode_attrs[:mode] == "zero_price"
        []
      elsif @attributes[:pattern].present?
        components_from_pattern(@attributes, currency: currency)
      else
        Array(@attributes[:components]).presence ||
          raise(Error.new("Enter a price pattern or components.", code: :invalid))
      end

      ServiceOfferPriceComponentBase.where(service_offer_price_definition_id: definition.id).delete_all
      ServiceOfferPriceComponent.where(service_offer_price_definition_id: definition.id).delete_all
      definition.update!(**mode_attrs, currency: currency)
      created = if definition.calculated?
        replace_price_components!(definition, version, offer, departure, components)
      else
        []
      end
      bump_version!(version)
      audit!(
        agency: @agency,
        action: "service_offer.price_updated",
        subject: offer,
        actor: @actor,
        details: price_audit_details(offer, version, definition, component_count: created.size)
      )
      Result.new(status: :updated, record: definition.reload)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid
    raise Error.new("That Client price is invalid.", code: :invalid)
  end
end
