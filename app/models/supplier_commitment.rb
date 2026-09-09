class SupplierCommitment < ApplicationRecord
  STATUSES = %w[open released satisfied superseded cancelled].freeze

  belongs_to :agency
  belongs_to :office
  belongs_to :departure
  belongs_to :arrangement, class_name: "SupplierArrangement", inverse_of: :supplier_commitments
  belongs_to :reservation, class_name: "SupplierReservation", optional: true, inverse_of: :supplier_commitments
  belongs_to :resource, class_name: "SupplierResource", optional: true, inverse_of: :supplier_commitments
  belongs_to :service_occurrence, class_name: "SupplierServiceOccurrence", optional: true, inverse_of: :supplier_commitments
  belongs_to :governing_term, class_name: "SupplierCostTerm", inverse_of: :supplier_commitments
  belongs_to :supersedes_commitment, class_name: "SupplierCommitment", optional: true, inverse_of: :superseding_commitments
  belongs_to :created_by_membership, class_name: "AgencyMembership", inverse_of: false
  belongs_to :status_changed_by_membership, class_name: "AgencyMembership", inverse_of: false

  has_many :superseding_commitments, class_name: "SupplierCommitment", foreign_key: :supersedes_commitment_id, inverse_of: :supersedes_commitment, dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true
  monetize :valuation_amount_minor_units, as: :valuation_amount, with_model_currency: :currency

  attr_readonly :agency_id, :office_id, :departure_id, :arrangement_id, :reservation_id, :resource_id,
    :service_occurrence_id, :governing_term_id, :economic_item_id, :economic_item_key, :created_by_membership_id

  normalizes :economic_item_key, :cost_category, :quantity_basis, :quantity_unit, :currency, :governing_term_snapshot,
    :opened_reason, :status_reason, with: ->(value) { value&.strip.presence }

  validates :economic_item_id, :economic_item_key, :cost_category, :quantity_basis, :quantity_unit, :currency,
    :valuation_amount_minor_units, :governing_term_snapshot, :opened_reason, :status_changed_at, presence: true
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validates :valuation_amount_minor_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :currency_is_known
  validate :same_scope
  validate :governing_term_is_active
  validate :status_metadata

  scope :open, -> { where(status: "open") }

  private

  def currency_is_known
    return if currency.blank?

    Money::Currency.find(currency)
  rescue Money::Currency::UnknownCurrency
    errors.add(:currency, "is not a supported currency")
  end

  def same_scope
    if governing_term && [ governing_term.agency_id, governing_term.office_id, governing_term.departure_id, governing_term.arrangement_id ] != [ agency_id, office_id, departure_id, arrangement_id ]
      errors.add(:governing_term, "must belong to the same arrangement")
    end
    errors.add(:governing_term, "must use the same currency") if governing_term && currency.present? && governing_term.currency != currency
  end

  def governing_term_is_active
    return if governing_term&.active?

    errors.add(:governing_term, "must be active")
  end

  def status_metadata
    if open?
      errors.add(:status_reason, "must be blank while open") if status_reason.present?
    elsif status_reason.blank?
      errors.add(:status_reason, "is required")
    end
  end
end
