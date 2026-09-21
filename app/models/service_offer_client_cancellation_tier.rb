# frozen_string_literal: true

class ServiceOfferClientCancellationTier < ApplicationRecord
  include DraftVersionDefinition
  guards_draft_version :service_offer_version

  THRESHOLD_KINDS = %w[on_or_before_date days_before_departure].freeze
  CONSEQUENCE_KINDS = %w[fixed percent manual_review].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :service_offer
  belongs_to :service_offer_version
  belongs_to :service_offer_client_cancellation_policy

  enum :threshold_kind, THRESHOLD_KINDS.index_by(&:itself), validate: true
  enum :consequence_kind, CONSEQUENCE_KINDS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :service_offer_id, :service_offer_version_id,
    :service_offer_client_cancellation_policy_id
end
