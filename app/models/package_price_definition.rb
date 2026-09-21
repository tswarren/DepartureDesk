# frozen_string_literal: true

class PackagePriceDefinition < ApplicationRecord
  include DraftVersionDefinition
  guards_draft_version :package_version

  MODES = %w[bundled service_sum].freeze
  ROUNDING_MODES = %w[half_up].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :package
  belongs_to :package_version
  has_many :package_price_components, dependent: :restrict_with_exception
  has_many :package_price_component_bases, class_name: "PackagePriceComponentBase", dependent: :restrict_with_exception

  enum :mode, MODES.index_by(&:itself), validate: true
  enum :rounding_mode, ROUNDING_MODES.index_by(&:itself), validate: true, default: "half_up"

  attr_readonly :agency_id, :departure_id, :package_id, :package_version_id

  normalizes :currency, with: ->(value) { value.to_s.strip.upcase }

  validates :currency, presence: true, format: { with: Agency::CURRENCY_FORMAT }
  validates :single_occupancy_supplement_rate, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :currency_matches_departure
  validate :supplement_only_on_bundled
  validate :bundled_components_are_unscoped
  validate :service_sum_components_are_fixed_adjustments

  private

  def currency_matches_departure
    return if currency.blank? || departure.nil?
    errors.add(:currency, "must equal the departure operating currency") if currency != departure.operating_currency
  end

  def supplement_only_on_bundled
    return if bundled? || single_occupancy_supplement_rate.nil?

    errors.add(:single_occupancy_supplement_rate, "is only valid on a bundled package price")
  end

  def bundled_components_are_unscoped
    return unless bundled?

    package_price_components.each do |component|
      if component.base_price? && (component.calculation_kind != "unit_rate" || component.quantity_basis != "persons")
        errors.add(:base, "Bundled package base price must be an unscoped per-person rate")
      end
    end
  end

  def service_sum_components_are_fixed_adjustments
    return unless service_sum?

    package_price_components.each do |component|
      unless component.named_discount? || component.named_surcharge?
        errors.add(:base, "Service-sum package prices accept only named discounts and surcharges")
      end
      unless component.fixed?
        errors.add(:base, "Service-sum package adjustments must be fixed amounts")
      end
    end
  end
end
