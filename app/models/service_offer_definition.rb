# frozen_string_literal: true

class ServiceOfferDefinition < ApplicationRecord
  include DraftVersionDefinition
  guards_draft_version :service_offer_version

  FULFILLMENT_BASES = %w[m3_backed on_request agency_fulfilled externally_fulfilled].freeze
  TITLE_LIMIT = 160
  DESCRIPTION_LIMIT = 2_000

  belongs_to :agency
  belongs_to :departure
  belongs_to :service_offer
  belongs_to :service_offer_version

  enum :fulfillment_basis, FULFILLMENT_BASES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :service_offer_id, :service_offer_version_id

  normalizes :client_title, with: ->(value) { value.to_s.strip }
  normalizes :client_description, with: ->(value) { value.to_s.strip.presence }

  validates :client_title, presence: true, length: { maximum: TITLE_LIMIT }
  validates :client_description, length: { maximum: DESCRIPTION_LIMIT }, allow_nil: true
end
