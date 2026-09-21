# frozen_string_literal: true

class PublishServiceOfferVersion < AgencyCommand
  include OfferCommandSupport

  def initialize(agency:, actor:, offer:, version_lock_version:, sales_enabled: true, idempotency_key:)
    @agency = agency
    @actor = actor
    @offer = offer
    @version_lock_version = version_lock_version
    @sales_enabled = sales_enabled
    @idempotency_key = idempotency_key
  end

  def call
    ensure_offer_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      offer_row = @agency.service_offers.find_by(id: record_id(@offer))
      raise Error.new("That service offer was not found.", code: :not_found) if offer_row.nil?

      departure = lock_departure_for!(offer_row.departure_id)
      offer = lock_offer_for!(offer_row)

      key = normalize_idempotency_key(@idempotency_key)
      existing = AgencyCommandIdempotencyKey.where(
        agency: @agency, command_name: self.class.name, idempotency_key: key
      ).lock.first
      if existing
        return AgencyCommand::Result.new(status: :replayed, record: ServiceOfferVersion.find(existing.result_record_id))
      end

      version = lock_editable_offer_draft!(offer)
      ensure_current_lock_version!(version, @version_lock_version)

      readiness = EvaluateServiceOfferPublicationReadiness.new(agency: @agency, version: version).call
      unless readiness.ok
        raise Error.new(readiness.issues.first.message, code: :invalid)
      end
      unless departure.active?
        raise Error.new("Publication requires an active Departure.", code: :invalid_state)
      end

      payload = {
        service_offer_id: offer.id,
        service_offer_version_id: version.id,
        sales_enabled: !!@sales_enabled
      }

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: payload,
        result_class: ServiceOfferVersion
      ) do
        publish_version!(offer, version, departure)
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def record_id(record)
    record.respond_to?(:id) ? record.id : record
  end

  def publish_version!(offer, version, departure)
    now = Time.current
    previous = offer.current_published_version
    if previous&.published?
      previous.update!(status: "superseded")
    end

    version.update!(status: "published", published_at: now)
    ServiceOfferVersionSalesState.create!(
      agency: @agency,
      departure: departure,
      service_offer_version: version,
      sales_enabled: !!@sales_enabled
    )
    ServiceOfferPublicationManifest.create!(
      agency: @agency,
      departure: departure,
      service_offer_version: version,
      actor_agency_user: @actor,
      published_at: now,
      fingerprint_json: OfferPublicationFingerprint.for_service_offer_version(version)
    )
    offer.update!(current_published_version: version)
    audit!(
      agency: @agency,
      action: "service_offer.published",
      subject: offer,
      actor: @actor,
      details: {
        "service_offer_id" => offer.id,
        "service_offer_version_id" => version.id,
        "sales_enabled" => !!@sales_enabled
      }
    )
    version.reload
  end
end
