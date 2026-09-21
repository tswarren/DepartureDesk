# frozen_string_literal: true

class CreateInitialPackageWithOutlineServiceOffer < AgencyCommand
  include PackageCommandSupport

  def initialize(agency:, actor:, departure:, attributes:, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @attributes = attributes.to_h.with_indifferent_access
    @idempotency_key = idempotency_key || @attributes.delete(:idempotency_key)
  end

  def call
    ensure_offer_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      departure = lock_departure_for!(@departure)
      ensure_departure_accepts_new_package!(departure)
      ensure_departure_accepts_new_offer!(departure)

      package_name = normalize_package_name(@attributes[:package_name].presence || @attributes[:name])
      client_title = normalize_client_title(@attributes[:client_title].presence || @attributes[:component_name])
      component_name = normalize_offer_name(@attributes[:component_name].presence || client_title)
      placement = normalize_placement(@attributes[:placement])
      client_timing_text = normalize_client_timing_text(@attributes[:client_timing_text])
      payload = {
        departure_id: departure.id,
        package_name: package_name,
        component_name: component_name,
        client_title: client_title,
        client_timing_text: client_timing_text,
        placement: placement,
        fulfillment_basis: "undecided"
      }

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: payload,
        result_class: Package
      ) do
        package = @agency.packages.create!(departure: departure, name: package_name)
        package_version = package.versions.create!(
          agency: @agency,
          departure: departure,
          version_number: 1,
          status: "draft"
        )
        offer = @agency.service_offers.create!(
          departure: departure,
          name: component_name
        )
        offer_version = offer.versions.create!(
          agency: @agency,
          departure: departure,
          version_number: 1,
          status: "draft",
          owning_package_version: package_version
        )
        offer_version.create_definition!(
          agency: @agency,
          departure: departure,
          service_offer: offer,
          client_title: client_title,
          client_description: normalize_client_description(@attributes[:client_description]),
          client_timing_text: client_timing_text,
          fulfillment_basis: "undecided"
        )
        package_version.inclusions.create!(
          agency: @agency,
          departure: departure,
          package: package,
          service_offer: offer,
          service_offer_version: offer_version,
          placement: placement,
          origin: "inline_create",
          position: 1
        )
        audit!(
          agency: @agency,
          action: "package.created",
          subject: package,
          actor: @actor,
          details: package_audit_details(package, package_version, "origin" => "initial_outline")
        )
        audit!(
          agency: @agency,
          action: "service_offer.created",
          subject: offer,
          actor: @actor,
          details: {
            "service_offer_id" => offer.id,
            "service_offer_version_id" => offer_version.id,
            "departure_id" => departure.id,
            "package_id" => package.id,
            "fulfillment_basis" => "undecided",
            "origin" => "initial_outline"
          }
        )
        audit!(
          agency: @agency,
          action: "package.service_included",
          subject: package,
          actor: @actor,
          details: package_audit_details(
            package,
            package_version,
            "service_offer_id" => offer.id,
            "origin" => "initial_outline"
          )
        )
        package
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def normalize_placement(value)
    placement = value.to_s.presence || "included"
    unless PackageInclusion::PLACEMENTS.include?(placement)
      raise Error.new("Choose included or optional placement.", code: :invalid)
    end

    placement
  end
end
