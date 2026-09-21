# frozen_string_literal: true

class AdoptServiceOfferDraftAsPackageOnly < AgencyCommand
  include PackageCommandSupport

  def initialize(agency:, actor:, package:, offer:, version_lock_version:, offer_version_lock_version:, placement: "included", idempotency_key: nil)
    @agency = agency
    @actor = actor
    @package = package
    @offer = offer
    @version_lock_version = version_lock_version
    @offer_version_lock_version = offer_version_lock_version
    @placement = placement
    @idempotency_key = idempotency_key
  end

  def call
    ensure_offer_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      package_row = @agency.packages.find_by(id: record_id(@package))
      raise Error.new("That package was not found.", code: :not_found) if package_row.nil?
      offer_row = @agency.service_offers.find_by(id: record_id(@offer))
      raise Error.new("That service offer was not found.", code: :not_found) if offer_row.nil?
      raise Error.new("That service offer was not found.", code: :not_found) if offer_row.departure_id != package_row.departure_id

      departure, package, version = lock_departure_package_draft!(package_row)
      locked_offer = lock_service_offers_in_uuid_order!(offer_row).first
      offer_version = lock_editable_offer_draft!(locked_offer)
      ensure_package_draft_editable!(departure, package, version)
      ensure_current_lock_version!(version, @version_lock_version)
      ensure_current_lock_version!(offer_version, @offer_version_lock_version)
      unless offer_version.draft?
        raise Error.new("Only an editable draft can be adopted as package-only.", code: :invalid_state)
      end
      if offer_version.owning_package_version_id.present?
        raise Error.new("That service offer version already belongs to a package.", code: :invalid_state)
      end
      if PackageInclusion.where(service_offer_version_id: offer_version.id).exists?
        raise Error.new("That service offer draft is already included in a package.", code: :invalid_state)
      end

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
          service_offer_id: locked_offer.id,
          service_offer_version_id: offer_version.id,
          placement: placement
        },
        result_class: Package
      ) do
        offer_version.update!(owning_package_version: version)
        version.inclusions.create!(
          agency: @agency,
          departure: departure,
          package: package,
          service_offer: locked_offer,
          service_offer_version: offer_version,
          placement: placement,
          origin: "adopted_draft",
          position: next_inclusion_position(version)
        )
        bump_version!(version)
        bump_version!(offer_version)
        audit!(
          agency: @agency,
          action: "package.service_adopted",
          subject: package,
          actor: @actor,
          details: package_audit_details(
            package, version,
            "service_offer_id" => locked_offer.id,
            "service_offer_version_id" => offer_version.id
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
