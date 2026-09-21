# frozen_string_literal: true

class ServiceOfferChoiceGroup < ApplicationRecord
  include DraftVersionDefinition
  guards_draft_version :service_offer_version

  belongs_to :agency
  belongs_to :departure
  belongs_to :service_offer
  belongs_to :service_offer_version
  has_many :service_offer_choice_options, dependent: :restrict_with_exception

  attr_readonly :agency_id, :departure_id, :service_offer_id, :service_offer_version_id

  normalizes :name, with: ->(value) { value.to_s.strip }

  validates :name, presence: true, length: { maximum: 160 }
  validates :min_selections, :max_selections, :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :bounds

  private

  def bounds
    return if min_selections.nil? || max_selections.nil?
    errors.add(:max_selections, "must be at least the minimum") if max_selections < min_selections
  end
end
