# frozen_string_literal: true

class AbandonPackageDraft < AgencyCommand
  include PackageCommandSupport

  def initialize(agency:, actor:, package:, reason:, package_lock_version:, version_lock_version:)
    @agency = agency
    @actor = actor
    @package = package
    @reason = reason
    @package_lock_version = package_lock_version
    @version_lock_version = version_lock_version
  end

  def call
    ensure_offer_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      departure, package, version = lock_departure_package_draft!(@package)
      if version.abandoned?
        return Result.new(status: :noop, record: package)
      end

      ensure_current_lock_version!(package, @package_lock_version)
      ensure_current_lock_version!(version, @version_lock_version)
      reason = normalize_reason(@reason)
      inclusions = version.inclusions.lock.order(:id).to_a
      offer_ids = inclusions.map(&:service_offer_id)
      lock_service_offers_in_uuid_order!(offer_ids) if offer_ids.any?

      inclusions.each do |inclusion|
        offer_version = inclusion.service_offer_version.lock!
        if inclusion.inline_create?
          next if offer_version.abandoned?

          offer_version.update!(status: "abandoned", abandoned_at: Time.current, abandoned_reason: reason)
          audit!(
            agency: @agency,
            action: "service_offer.discarded",
            subject: inclusion.service_offer,
            actor: @actor,
            details: {
              "service_offer_id" => inclusion.service_offer_id,
              "service_offer_version_id" => offer_version.id,
              "reason" => reason,
              "package_id" => package.id
            }
          )
        elsif inclusion.adopted_draft? && offer_version.owning_package_version_id == version.id
          offer_version.update!(owning_package_version: nil)
        end
      end

      version.update!(status: "abandoned", abandoned_at: Time.current, abandoned_reason: reason)
      audit!(
        agency: @agency,
        action: "package.abandoned",
        subject: package,
        actor: @actor,
        details: package_audit_details(package, version, "reason" => reason)
      )
      Result.new(status: :updated, record: package.reload)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
