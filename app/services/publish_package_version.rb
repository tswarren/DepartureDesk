# frozen_string_literal: true

class PublishPackageVersion < AgencyCommand
  include PackageCommandSupport

  def initialize(agency:, actor:, package:, version_lock_version:, sales_enabled: true, idempotency_key:)
    @agency = agency
    @actor = actor
    @package = package
    @version_lock_version = version_lock_version
    @sales_enabled = sales_enabled
    @idempotency_key = idempotency_key
  end

  def call
    ensure_offer_actor!
    published_owned = []

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      package_row = @agency.packages.find_by(id: record_id(@package))
      raise Error.new("That package was not found.", code: :not_found) if package_row.nil?

      departure = lock_departure_for!(package_row.departure_id)
      package = lock_package_for!(package_row)

      key = normalize_idempotency_key(@idempotency_key)
      existing = AgencyCommandIdempotencyKey.where(
        agency: @agency, command_name: self.class.name, idempotency_key: key
      ).lock.first
      if existing
        return AgencyCommand::Result.new(status: :replayed, record: PackageVersion.find(existing.result_record_id))
      end

      version = lock_editable_package_draft!(package)
      ensure_current_lock_version!(version, @version_lock_version)

      owned = version.owned_service_offer_versions.lock.order(:id).to_a
      lock_service_offers_in_uuid_order!(owned.map(&:service_offer_id))

      readiness = EvaluatePackagePublicationReadiness.new(agency: @agency, version: version).call
      unless readiness.ok
        raise Error.new(readiness.issues.first.message, code: :invalid)
      end
      unless departure.active?
        raise Error.new("Publication requires an active Departure.", code: :invalid_state)
      end

      payload = {
        package_id: package.id,
        package_version_id: version.id,
        owned_service_offer_version_ids: owned.map(&:id).sort,
        sales_enabled: !!@sales_enabled
      }

      result = idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: payload,
        result_class: PackageVersion
      ) do
        publish_graph!(package, version, departure, owned, published_owned)
      end

      key_row = AgencyCommandIdempotencyKey.find_by!(
        agency: @agency,
        command_name: self.class.name,
        idempotency_key: key
      )
      if result.status == :created
        publication_result = PackagePublicationResult.create!(
          agency: @agency,
          departure: departure,
          agency_command_idempotency_key: key_row,
          package_version: result.record
        )
        published_owned.each do |sov|
          PackagePublicationResultServiceVersion.create!(
            agency: @agency,
            package_publication_result: publication_result,
            service_offer_version: sov
          )
        end
      end

      result
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def record_id(record)
    record.respond_to?(:id) ? record.id : record
  end

  def publish_graph!(package, version, departure, owned, published_owned)
    now = Time.current

    owned.each do |sov|
      next if sov.published?

      offer = sov.service_offer
      previous = offer.current_published_version
      previous.update!(status: "superseded") if previous&.published?
      sov.update!(status: "published", published_at: now)
      ServiceOfferVersionSalesState.create!(
        agency: @agency, departure: departure, service_offer_version: sov, sales_enabled: !!@sales_enabled
      )
      ServiceOfferPublicationManifest.create!(
        agency: @agency, departure: departure, service_offer_version: sov,
        actor_agency_user: @actor, published_at: now,
        fingerprint_json: OfferPublicationFingerprint.for_service_offer_version(sov)
      )
      offer.update!(current_published_version: sov)
      published_owned << sov
    end

    previous_package = package.current_published_version
    previous_package.update!(status: "superseded") if previous_package&.published?

    version.update!(status: "published", published_at: now)
    PackageVersionSalesState.create!(
      agency: @agency, departure: departure, package_version: version, sales_enabled: !!@sales_enabled
    )
    PackagePublicationManifest.create!(
      agency: @agency, departure: departure, package_version: version,
      actor_agency_user: @actor, published_at: now,
      fingerprint_json: OfferPublicationFingerprint.for_package_version(version)
    )
    package.update!(current_published_version: version)

    audit!(
      agency: @agency,
      action: "package.published",
      subject: package,
      actor: @actor,
      details: package_audit_details(
        package, version,
        "owned_service_offer_version_ids" => published_owned.map(&:id),
        "sales_enabled" => !!@sales_enabled
      )
    )
    version.reload
  end
end
