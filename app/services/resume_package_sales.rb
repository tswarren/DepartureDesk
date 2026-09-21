# frozen_string_literal: true

class ResumePackageSales < AgencyCommand
  include PackageCommandSupport

  def initialize(agency:, actor:, package:)
    @agency = agency
    @actor = actor
    @package = package
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

      structural = structural_resume_ok?(version)
      raise Error.new("That package is not structurally eligible to resume sales.", code: :invalid_state) unless structural

      state = PackageVersionSalesState.lock.find(version.sales_state.id)
      return package if state.sales_enabled

      state.update!(sales_enabled: true)
      audit!(
        agency: @agency, action: "package.sales_resumed", subject: package, actor: @actor,
        details: package_audit_details(package, version)
      )
      package
    end
  end

  private

  def structural_resume_ok?(version)
    version.published? && version.publication_manifest.present? && !version.departure.departed?
  end
end
