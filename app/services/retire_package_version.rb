# frozen_string_literal: true

class RetirePackageVersion < AgencyCommand
  include PackageCommandSupport

  def initialize(agency:, actor:, package:, reason:)
    @agency = agency
    @actor = actor
    @package = package
    @reason = reason.to_s.strip
  end

  def call
    ensure_offer_actor!
    raise Error.new("Enter a retirement reason.", code: :invalid) if @reason.blank?

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      package = lock_package_for!(@package)
      version = package.current_published_version
      raise Error.new("That package has no published version.", code: :invalid_state) if version.nil?
      version = package.versions.lock.find(version.id)
      raise Error.new("That package version is not published.", code: :invalid_state) unless version.published?

      version.update!(status: "retired", retired_at: Time.current)
      state = version.sales_state
      state.update!(sales_enabled: false) if state&.sales_enabled
      package.update!(current_published_version: nil) if package.current_published_version_id == version.id
      audit!(
        agency: @agency, action: "package.retired", subject: package, actor: @actor,
        details: package_audit_details(package, version, "reason" => @reason)
      )
      package
    end
  end
end
