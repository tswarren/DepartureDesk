# frozen_string_literal: true

class RemovePackagePriceDefinition < AgencyCommand
  include PackageCommandSupport

  def initialize(agency:, actor:, package:, version_lock_version:)
    @agency = agency
    @actor = actor
    @package = package
    @version_lock_version = version_lock_version
  end

  def call
    ensure_offer_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      departure, package, version = lock_departure_package_draft!(@package)
      ensure_package_draft_editable!(departure, package, version)
      ensure_departure_accepts_price_removal!(departure)
      ensure_current_lock_version!(version, @version_lock_version)
      definition = version.price_definition
      raise Error.new("That package has no price.", code: :invalid_state) if definition.nil?

      PackagePriceComponentBase.where(package_price_definition_id: definition.id).delete_all
      PackagePriceComponent.where(package_price_definition_id: definition.id).delete_all
      definition.delete
      bump_version!(version)
      audit!(
        agency: @agency, action: "package.price_removed", subject: package, actor: @actor,
        details: package_audit_details(package, version)
      )
      Result.new(status: :updated, record: package.reload)
    end
  end
end
