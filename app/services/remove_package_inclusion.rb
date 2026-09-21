# frozen_string_literal: true

class RemovePackageInclusion < AgencyCommand
  include PackageCommandSupport

  def initialize(agency:, actor:, package:, inclusion:, version_lock_version:)
    @agency = agency
    @actor = actor
    @package = package
    @inclusion = inclusion
    @version_lock_version = version_lock_version
  end

  def call
    ensure_offer_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      departure, package, version = lock_departure_package_draft!(@package)
      ensure_package_draft_editable!(departure, package, version)
      ensure_current_lock_version!(version, @version_lock_version)
      inclusion = version.inclusions.lock.find_by(id: record_id(@inclusion))
      raise Error.new("That inclusion was not found.", code: :not_found) if inclusion.nil?

      if inclusion.inline_create?
        raise Error.new("An inline package-only service cannot be removed. Abandon the package draft instead.", code: :invalid_state)
      end

      if inclusion.adopted_draft?
        offer_version = inclusion.service_offer_version.lock!
        offer_version.update!(owning_package_version: nil)
      end
      inclusion.destroy!
      bump_version!(version)
      audit!(
        agency: @agency,
        action: "package.inclusion_removed",
        subject: package,
        actor: @actor,
        details: package_audit_details(
          package, version,
          "service_offer_id" => inclusion.service_offer_id,
          "origin" => inclusion.origin
        )
      )
      Result.new(status: :updated, record: package.reload)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def record_id(record)
    record.respond_to?(:id) ? record.id : record
  end
end
