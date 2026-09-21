# frozen_string_literal: true

class CreatePackageDraft < AgencyCommand
  include PackageCommandSupport

  def initialize(agency:, actor:, departure:, attributes:, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @attributes = attributes.to_h.with_indifferent_access
    @idempotency_key = idempotency_key || @attributes.delete(:idempotency_key)
  end

  def call
    ensure_offer_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      departure = lock_departure_for!(@departure)
      ensure_departure_accepts_new_package!(departure)
      name = normalize_package_name(@attributes[:name])

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: { departure_id: departure.id, name: name },
        result_class: Package
      ) do
        package = @agency.packages.create!(departure: departure, name: name)
        version = package.versions.create!(
          agency: @agency,
          departure: departure,
          version_number: 1,
          status: "draft"
        )
        audit!(
          agency: @agency,
          action: "package.created",
          subject: package,
          actor: @actor,
          details: package_audit_details(package, version)
        )
        package
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
