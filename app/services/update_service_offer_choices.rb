# frozen_string_literal: true

class UpdateServiceOfferChoices < AgencyCommand
  include OfferCommandSupport

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
      ensure_current_lock_version!(version, @version_lock_version)
      replace_groups!(version, offer, departure)
      validate_choice_gated!(version)
      bump_version!(version)
      audit!(
        agency: @agency, action: "service_offer.choice_updated", subject: offer, actor: @actor,
        details: { "service_offer_id" => offer.id, "service_offer_version_id" => version.id }
      )
      Result.new(status: :updated, record: offer.reload)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def replace_groups!(version, offer, departure)
    ServiceOfferChoiceOptionSourceActivation.where(service_offer_version_id: version.id).delete_all
    ServiceOfferChoiceOption.where(service_offer_version_id: version.id).delete_all
    ServiceOfferChoiceGroup.where(service_offer_version_id: version.id).delete_all
    Array(@attributes[:groups]).each_with_index do |raw, index|
      group_attrs = raw.to_h.with_indifferent_access
      options = Array(group_attrs[:options]).map { |row| row.to_h.with_indifferent_access }.reject { |row| row[:name].to_s.strip.blank? }
      next if group_attrs[:name].to_s.strip.blank? && options.empty?
      min = group_attrs[:min_selections].to_i
      max = group_attrs[:max_selections].present? ? group_attrs[:max_selections].to_i : options.size
      if min.negative? || max < min || max > options.size
        raise Error.new("Choice group min and max must fit the options.", code: :invalid)
      end

      group = version.choice_groups.create!(
        agency: @agency, departure: departure, service_offer: offer,
        name: group_attrs[:name].to_s.strip, min_selections: min, max_selections: max, position: index + 1
      )
      options.each_with_index do |option_raw, option_index|
        option_attrs = option_raw.is_a?(Hash) ? option_raw.with_indifferent_access : option_raw.to_h.with_indifferent_access
        option = group.service_offer_choice_options.create!(
          agency: @agency, departure: departure, service_offer: offer, service_offer_version: version,
          name: option_attrs[:name].to_s.strip,
          client_description: option_attrs[:client_description],
          price_effect_minor_units: option_attrs[:price_effect_minor_units],
          position: option_index + 1
        )
        activation = option_attrs[:activation].to_h.with_indifferent_access
        kind = activation[:activation_kind].to_s.presence || "none"
        binding = if kind == "binding"
          version.source_bindings.find_by(id: activation[:service_offer_source_binding_id]) ||
            raise(Error.new("Choice activation must point at this service offer version.", code: :invalid))
        end
        option.create_source_activation!(
          agency: @agency, departure: departure, service_offer: offer, service_offer_version: version,
          activation_kind: kind,
          service_offer_source_binding: binding,
          alternative_group_key: activation[:alternative_group_key]
        )
      end
    end
  end

  def validate_choice_gated!(version)
    gated = version.source_bindings.select(&:choice_gated?)
    activations = ServiceOfferChoiceOptionSourceActivation.where(service_offer_version_id: version.id)
    gated.each do |binding|
      unless activations.exists?(activation_kind: "binding", service_offer_source_binding_id: binding.id)
        raise Error.new("Every choice-gated source must be reachable from an option.", code: :invalid)
      end
    end
  end
end
