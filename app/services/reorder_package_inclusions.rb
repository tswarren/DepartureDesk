# frozen_string_literal: true

class ReorderPackageInclusions < AgencyCommand
  include PackageCommandSupport

  def initialize(agency:, actor:, package:, ordered_ids:, version_lock_version:)
    @agency = agency
    @actor = actor
    @package = package
    @ordered_ids = Array(ordered_ids)
    @version_lock_version = version_lock_version
  end

  def call
    ensure_offer_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      departure, package, version = lock_departure_package_draft!(@package)
      ensure_package_draft_editable!(departure, package, version)
      ensure_current_lock_version!(version, @version_lock_version)
      inclusions = version.inclusions.lock.order(:position, :id).to_a
      ids = inclusions.map { |row| row.id.to_s }
      submitted = @ordered_ids.map(&:to_s)
      if submitted.sort != ids.sort
        raise Error.new("Inclusion order must list every included service once.", code: :invalid)
      end

      offset = inclusions.size
      inclusions.each_with_index do |inclusion, index|
        inclusion.update!(position: offset + index + 1)
      end
      submitted.each_with_index do |id, index|
        inclusions.find { |row| row.id.to_s == id }.update!(position: index + 1)
      end
      bump_version!(version)
      audit!(
        agency: @agency,
        action: "package.inclusions_reordered",
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
