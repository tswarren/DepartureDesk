# frozen_string_literal: true

class ServiceOfferChoiceOption < ApplicationRecord
  include DraftVersionDefinition
  guards_draft_version :service_offer_version

  belongs_to :agency
  belongs_to :departure
  belongs_to :service_offer
  belongs_to :service_offer_version
  belongs_to :service_offer_choice_group
  has_one :source_activation, class_name: "ServiceOfferChoiceOptionSourceActivation",
    dependent: :restrict_with_exception

  attr_readonly :agency_id, :departure_id, :service_offer_id, :service_offer_version_id,
    :service_offer_choice_group_id

  normalizes :name, with: ->(value) { value.to_s.strip }
  normalizes :client_description, with: ->(value) { value.to_s.strip.presence }
  normalizes :client_rate_category_key, with: ->(value) { value.to_s.strip.presence }

  validates :name, presence: true, length: { maximum: 160 }
  validates :client_rate_category_key, length: { maximum: ServiceOfferPriceComponent::RATE_CATEGORY_LIMIT }, allow_nil: true
  validates :position, numericality: { only_integer: true, greater_than: 0 }
end
