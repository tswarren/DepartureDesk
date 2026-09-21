# frozen_string_literal: true

class UpdateServiceOfferClientTerms < AgencyCommand
  include OfferCommandSupport

  def initialize(agency:, actor:, offer:, attributes:, version_lock_version:)
    @agency = agency
    @actor = actor
    @offer = offer
    @attributes = attributes.to_h.with_indifferent_access
    @version_lock_version = version_lock_version
  end

  def call
    ensure_offer_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      departure, offer, version = lock_departure_offer_draft!(@offer)
      ensure_offer_draft_editable!(departure, offer, version)
      ensure_current_lock_version!(version, @version_lock_version)
      apply_caps!(version)
      replace_payment!(version, offer, departure)
      replace_cancellation!(version, offer, departure)
      replace_conditions!(version, offer, departure)
      bump_version!(version)
      audit!(
        agency: @agency, action: "service_offer.terms_updated", subject: offer, actor: @actor,
        details: { "service_offer_id" => offer.id, "service_offer_version_id" => version.id }
      )
      Result.new(status: :updated, record: offer.reload)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def apply_caps!(version)
    version.sales_cap_quantity = @attributes[:sales_cap_quantity].presence
    version.sales_cap_basis = @attributes[:sales_cap_basis].presence
    if version.sales_cap_basis.to_s == "package_bookings"
      raise Error.new("A standalone service cannot use a package-bookings cap.", code: :invalid)
    end

    version.save!
  end

  def replace_payment!(version, offer, departure)
    ServiceOfferClientPaymentScheduleLine.where(service_offer_version_id: version.id).delete_all
    ServiceOfferClientPaymentSchedule.where(service_offer_version_id: version.id).delete_all
    lines = Array(@attributes[:payment_lines]).map { |row| row.to_h.with_indifferent_access }.reject { |row| row[:due_kind].blank? }
    return if lines.empty?

    schedule = version.create_payment_schedule!(agency: @agency, departure: departure, service_offer: offer)
    lines.each_with_index do |attrs, index|
      schedule.lines.create!(
        agency: @agency, departure: departure, service_offer: offer, service_offer_version: version,
        position: index + 1,
        due_kind: attrs[:due_kind],
        due_on: attrs[:due_on],
        milestone_name: attrs[:milestone_name],
        amount_kind: attrs[:amount_kind],
        amount_minor_units: attrs[:amount_minor_units],
        percent_rate: attrs[:percent_rate],
        percent_base: attrs[:amount_kind].to_s == "percent" ? "selected_client_price" : nil
      )
    end
  end

  def replace_cancellation!(version, offer, departure)
    ServiceOfferClientCancellationTier.where(service_offer_version_id: version.id).delete_all
    ServiceOfferClientCancellationPolicy.where(service_offer_version_id: version.id).delete_all
    tiers = Array(@attributes[:cancellation_tiers]).map { |row| row.to_h.with_indifferent_access }.reject { |row| row[:consequence_kind].blank? }
    return if tiers.empty?

    policy = version.create_cancellation_policy!(agency: @agency, departure: departure, service_offer: offer)
    tiers.each_with_index do |attrs, index|
      policy.tiers.create!(
        agency: @agency, departure: departure, service_offer: offer, service_offer_version: version,
        position: index + 1,
        threshold_kind: attrs[:threshold_kind],
        threshold_on: attrs[:threshold_on],
        days_before: attrs[:days_before],
        consequence_kind: attrs[:consequence_kind],
        amount_minor_units: attrs[:amount_minor_units],
        percent_rate: attrs[:percent_rate],
        percent_base: attrs[:consequence_kind].to_s == "percent" ? "selected_client_price" : nil,
        summary: attrs[:summary]
      )
    end
  end

  def replace_conditions!(version, offer, departure)
    ServiceOfferClientStatedCondition.where(service_offer_version_id: version.id).delete_all
    Array(@attributes[:stated_conditions]).each_with_index do |raw, index|
      attrs = raw.to_h.with_indifferent_access
      next if attrs[:body].to_s.strip.blank?

      version.stated_conditions.create!(
        agency: @agency, departure: departure, service_offer: offer,
        position: index + 1, condition_kind: attrs[:condition_kind], body: attrs[:body]
      )
    end
  end
end
