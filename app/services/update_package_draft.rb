# frozen_string_literal: true

class UpdatePackageDraft < AgencyCommand
  include PackageCommandSupport

  def initialize(agency:, actor:, package:, attributes:, package_lock_version:, version_lock_version:)
    @agency = agency
    @actor = actor
    @package = package
    @attributes = attributes.to_h.with_indifferent_access
    @package_lock_version = package_lock_version
    @version_lock_version = version_lock_version
  end

  def call
    ensure_offer_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      departure, package, version = lock_departure_package_draft!(@package)
      ensure_package_draft_editable!(departure, package, version)
      ensure_current_lock_version!(package, @package_lock_version)
      ensure_current_lock_version!(version, @version_lock_version)
      attrs = {}
      attrs[:name] = normalize_package_name(@attributes[:name]) if @attributes.key?(:name)
      package.update!(attrs) if attrs.any?
      bump_version!(version)
      audit!(
        agency: @agency,
        action: "package.updated",
        subject: package,
        actor: @actor,
        details: package_audit_details(package, version)
      )
      Result.new(status: :updated, record: package.reload)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
