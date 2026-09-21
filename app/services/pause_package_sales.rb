# frozen_string_literal: true

class PausePackageSales < AgencyCommand
  include PackageCommandSupport

  def initialize(agency:, actor:, package:, reason: nil)
    @agency = agency
    @actor = actor
    @package = package
    @reason = reason.to_s.strip.presence
  end

  def call
    ensure_offer_actor!
    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      package = lock_package_for!(@package)
      version = package.current_published_version
      raise Error.new("That package has no published version.", code: :invalid_state) if version.nil?
      version = package.versions.lock.find(version.id)
      raise Error.new("That package version is not published.", code: :invalid_state) unless version.published?

      state = version.sales_state || raise(Error.new("Sales state is missing.", code: :invalid_state))
      state = PackageVersionSalesState.lock.find(state.id)
      return package if state.sales_enabled == false

      state.update!(sales_enabled: false)
      audit!(
        agency: @agency, action: "package.sales_paused", subject: package, actor: @actor,
        details: package_audit_details(package, version, "reason" => @reason)
      )
      package
    end
  end
end
