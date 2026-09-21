# frozen_string_literal: true

class ServiceOfferDefinition < ApplicationRecord
  include DraftVersionDefinition
  guards_draft_version :service_offer_version

  FULFILLMENT_BASES = %w[m3_backed on_request agency_fulfilled externally_fulfilled undecided].freeze
  PUBLISHABLE_FULFILLMENT_BASES = %w[m3_backed on_request agency_fulfilled externally_fulfilled].freeze
  TITLE_LIMIT = 160
  DESCRIPTION_LIMIT = 2_000
  CLIENT_TIMING_LIMIT = 160

  belongs_to :agency
  belongs_to :departure
  belongs_to :service_offer
  belongs_to :service_offer_version

  enum :fulfillment_basis, FULFILLMENT_BASES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :service_offer_id, :service_offer_version_id

  normalizes :client_title, with: ->(value) { value.to_s.strip }
  normalizes :client_description, :client_timing_text, with: ->(value) { value.to_s.strip.presence }

  validates :client_title, presence: true, length: { maximum: TITLE_LIMIT }
  validates :client_description, length: { maximum: DESCRIPTION_LIMIT }, allow_nil: true
  validates :client_timing_text, length: { maximum: CLIENT_TIMING_LIMIT }, allow_nil: true
  validate :undecided_only_on_draft_or_abandoned

  private

  def undecided_only_on_draft_or_abandoned
    return unless undecided?
    return if service_offer_version.blank?
    return if service_offer_version.draft? || service_offer_version.abandoned?

    errors.add(:fulfillment_basis, "undecided is only valid on draft or abandoned versions")
  end
end
