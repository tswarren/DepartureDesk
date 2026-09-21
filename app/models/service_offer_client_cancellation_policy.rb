# frozen_string_literal: true

class ServiceOfferClientCancellationPolicy < ApplicationRecord
  include DraftVersionDefinition
  guards_draft_version :service_offer_version

  belongs_to :agency
  belongs_to :departure
  belongs_to :service_offer
  belongs_to :service_offer_version
  has_many :tiers, class_name: "ServiceOfferClientCancellationTier", dependent: :restrict_with_exception

  attr_readonly :agency_id, :departure_id, :service_offer_id, :service_offer_version_id
end
