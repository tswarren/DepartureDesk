# frozen_string_literal: true

class ServiceOfferClientStatedCondition < ApplicationRecord
  include DraftVersionDefinition
  guards_draft_version :service_offer_version

  KINDS = %w[eligibility acknowledgment].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :service_offer
  belongs_to :service_offer_version

  enum :condition_kind, KINDS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :service_offer_id, :service_offer_version_id

  normalizes :body, with: ->(value) { value.to_s.strip }
  validates :body, presence: true, length: { maximum: 2_000 }
end
