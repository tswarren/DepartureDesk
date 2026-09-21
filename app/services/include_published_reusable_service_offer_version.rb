# frozen_string_literal: true

class IncludePublishedReusableServiceOfferVersion < AgencyCommand
  include PackageCommandSupport

  def initialize(agency:, actor:, package:, offer_version:, version_lock_version:, placement: "included", idempotency_key: nil)
    @agency = agency
    @actor = actor
    @package = package
    @offer_version = offer_version
    @version_lock_version = version_lock_version
    @placement = placement
    @idempotency_key = idempotency_key
  end

  def call
    ensure_offer_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      package_row = @agency.packages.find_by(id: record_id(@package))
      raise Error.new("That package was not found.", code: :not_found) if package_row.nil?
      offer_version_row = @agency.service_offer_versions.find_by(id: record_id(@offer_version))
      raise Error.new("That service offer version was not found.", code: :not_found) if offer_version_row.nil?
      raise Error.new("That service offer version was not found.", code: :not_found) if offer_version_row.departure_id != package_row.departure_id
      unless offer_version_row.published?
        raise Error.new("Only a published reusable version can be pinned this way.", code: :invalid_state)
      end
      if offer_version_row.owning_package_version_id.present?
        raise Error.new("A package-owned version cannot be included as published reusable.", code: :invalid_state)
      end

      departure, package, version = lock_departure_package_draft!(package_row)
      locked_offer = lock_service_offers_in_uuid_order!(offer_version_row.service_offer_id).first
      locked_offer_version = locked_offer.versions.lock.find(offer_version_row.id)
      ensure_package_draft_editable!(departure, package, version)
      ensure_current_lock_version!(version, @version_lock_version)

      placement = @placement.to_s.presence || "included"
      unless PackageInclusion::PLACEMENTS.include?(placement)
        raise Error.new("Choose included or optional placement.", code: :invalid)
      end

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: {
          package_id: package.id,
          package_version_id: version.id,
          service_offer_version_id: locked_offer_version.id,
          placement: placement
        },
        result_class: Package
      ) do
        version.inclusions.create!(
          agency: @agency,
          departure: departure,
          package: package,
          service_offer: locked_offer,
          service_offer_version: locked_offer_version,
          placement: placement,
          origin: "published_reusable",
          position: next_inclusion_position(version)
        )
        bump_version!(version)
        audit!(
          agency: @agency,
          action: "package.published_reusable_included",
          subject: package,
          actor: @actor,
          details: package_audit_details(
            package, version,
            "service_offer_id" => locked_offer.id,
            "service_offer_version_id" => locked_offer_version.id
          )
        )
        package.reload
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def record_id(record)
    record.respond_to?(:id) ? record.id : record
  end
end
