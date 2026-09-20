# frozen_string_literal: true

class ServiceOfferPriceDefinition < ApplicationRecord
  include DraftVersionDefinition
  guards_draft_version :service_offer_version

  MODES = %w[calculated zero_price].freeze
  ROUNDING_MODES = %w[half_up].freeze
  ZERO_PRICE_REASON_LIMIT = 500

  belongs_to :agency
  belongs_to :departure
  belongs_to :service_offer
  belongs_to :service_offer_version

  has_many :service_offer_price_components, dependent: :restrict_with_exception
  has_many :service_offer_price_component_bases, class_name: "ServiceOfferPriceComponentBase",
    dependent: :restrict_with_exception

  enum :mode, MODES.index_by(&:itself), validate: true, default: "calculated"
  enum :rounding_mode, ROUNDING_MODES.index_by(&:itself), validate: true, default: "half_up"

  attr_readonly :agency_id, :departure_id, :service_offer_id, :service_offer_version_id

  normalizes :currency, with: ->(value) { value.to_s.strip.upcase }
  normalizes :zero_price_reason, with: ->(value) { value.to_s.strip.presence }

  validates :currency, presence: true, format: { with: Agency::CURRENCY_FORMAT }
  validates :zero_price_reason, length: { maximum: ZERO_PRICE_REASON_LIMIT }, allow_nil: true
  validate :currency_is_known_and_matches_departure
  validate :zero_price_reason_matches_mode
  validate :base_price_selectors_do_not_overlap

  def overlapping_base_prices?
    bases = service_offer_price_components.select(&:base_price?)
    bases.combination(2).any? { |left, right| selectors_overlap?(left, right) }
  end

  private

  def currency_is_known_and_matches_departure
    return if currency.blank?

    Money::Currency.find(currency)
    if departure && currency != departure.operating_currency
      errors.add(:currency, "must equal the departure operating currency")
    end
  rescue Money::Currency::UnknownCurrency
    errors.add(:currency, "is not a supported currency")
  end

  def zero_price_reason_matches_mode
    if zero_price?
      errors.add(:zero_price_reason, "can't be blank") if zero_price_reason.blank?
    elsif zero_price_reason.present?
      errors.add(:zero_price_reason, "must be blank for a calculated definition")
    end
  end

  def base_price_selectors_do_not_overlap
    return unless overlapping_base_prices?

    errors.add(:base, "A generic base price cannot overlap a more specific base price")
  end

  def selectors_overlap?(left, right)
    category_overlap?(left.client_rate_category_key, right.client_rate_category_key) &&
      category_overlap?(left.occupancy_position_key, right.occupancy_position_key)
  end

  def category_overlap?(left, right)
    left.blank? || right.blank? || left == right
  end
end
