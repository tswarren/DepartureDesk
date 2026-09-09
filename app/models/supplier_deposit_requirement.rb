class SupplierDepositRequirement < ApplicationRecord
  STATUSES = %w[active cancelled].freeze

  belongs_to :agency
  belongs_to :office
  belongs_to :departure
  belongs_to :arrangement, class_name: "SupplierArrangement", inverse_of: :supplier_deposit_requirements
  belongs_to :supplier_cost_term, optional: true
  belongs_to :created_by_membership, class_name: "AgencyMembership", inverse_of: false
  belongs_to :status_changed_by_membership, class_name: "AgencyMembership", inverse_of: false

  has_many :supplier_deadlines, foreign_key: :source_deposit_requirement_id, inverse_of: :source_deposit_requirement, dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true
  monetize :amount_minor_units, as: :amount, with_model_currency: :currency

  attr_readonly :agency_id, :office_id, :departure_id, :arrangement_id, :created_by_membership_id

  normalizes :name, :currency, :due_rule, :trigger_condition, :provenance, :status_reason, with: ->(value) { value&.strip.presence }

  validates :name, :amount_minor_units, :currency, :due_rule, :trigger_condition, :provenance, :status_changed_at, presence: true
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validates :amount_minor_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :currency_is_known
  validate :same_scope
  validate :status_metadata

  private

  def currency_is_known
    return if currency.blank?

    Money::Currency.find(currency)
  rescue Money::Currency::UnknownCurrency
    errors.add(:currency, "is not a supported currency")
  end

  def same_scope
    if arrangement && [ arrangement.agency_id, arrangement.office_id, arrangement.departure_id ] != [ agency_id, office_id, departure_id ]
      errors.add(:arrangement, "must belong to the same departure")
    end
    if supplier_cost_term && [ supplier_cost_term.agency_id, supplier_cost_term.office_id, supplier_cost_term.departure_id, supplier_cost_term.arrangement_id ] != [ agency_id, office_id, departure_id, arrangement_id ]
      errors.add(:supplier_cost_term, "must belong to the same arrangement")
    end
    errors.add(:supplier_cost_term, "must use the same currency") if supplier_cost_term && currency.present? && supplier_cost_term.currency != currency
  end

  def status_metadata
    if active?
      errors.add(:status_reason, "must be blank while active") if status_reason.present?
    elsif status_reason.blank?
      errors.add(:status_reason, "is required")
    end
  end
end
