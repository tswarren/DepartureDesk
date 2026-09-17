class SupplierCostDefinition < ApplicationRecord
  include ExactVersionCopyLineage
  STAGES = %w[estimate contracted].freeze
  STATUSES = %w[working forecast_ready].freeze
  MODES = %w[calculated zero_cost].freeze
  ROUNDING_MODES = %w[half_up].freeze
  ZERO_COST_REASON_LIMIT = 500
  READINESS_PROVENANCE_LIMIT = 500

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_cost_source
  belongs_to :forecast_ready_by, class_name: "AgencyUser", optional: true

  has_many :supplier_cost_components, dependent: :restrict_with_exception

  enum :stage, STAGES.index_by(&:itself), validate: true
  enum :status, STATUSES.index_by(&:itself), validate: true, default: "working"
  enum :mode, MODES.index_by(&:itself), validate: true, default: "calculated"
  enum :rounding_mode, ROUNDING_MODES.index_by(&:itself), validate: true, default: "half_up"

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :supplier_cost_source_id

  normalizes :currency, with: ->(value) { value.to_s.strip.upcase }
  normalizes :zero_cost_reason, :readiness_provenance, :readiness_fingerprint,
    with: ->(value) { value.to_s.strip.presence }

  validates :currency, presence: true, format: { with: Agency::CURRENCY_FORMAT }
  validates :zero_cost_reason, length: { maximum: ZERO_COST_REASON_LIMIT }, allow_nil: true
  validates :readiness_provenance, length: { maximum: READINESS_PROVENANCE_LIMIT }, allow_nil: true
  validate :currency_is_known_and_matches_departure
  validate :zero_cost_reason_matches_mode
  validate :readiness_fields_match_status

  private

  def currency_is_known_and_matches_departure
    return if currency.blank?

    Money::Currency.find(currency)
    errors.add(:currency, "must equal the departure operating currency") if departure && currency != departure.operating_currency
  rescue Money::Currency::UnknownCurrency
    errors.add(:currency, "is not a supported currency")
  end

  def zero_cost_reason_matches_mode
    if zero_cost?
      errors.add(:zero_cost_reason, "can't be blank") if zero_cost_reason.blank?
    elsif zero_cost_reason.present?
      errors.add(:zero_cost_reason, "must be blank for a calculated definition")
    end
  end

  def readiness_fields_match_status
    readiness = [ forecast_ready_by_id, forecast_ready_at, readiness_fingerprint ]
    if forecast_ready?
      errors.add(:base, "Forecast readiness evidence is incomplete") if readiness.any?(&:blank?)
      if contracted? && readiness_provenance.blank?
        errors.add(:readiness_provenance, "can't be blank for contracted terms")
      end
    elsif readiness.any?(&:present?) || readiness_provenance.present?
      errors.add(:base, "Working definitions cannot retain forecast readiness evidence")
    end
  end
end
