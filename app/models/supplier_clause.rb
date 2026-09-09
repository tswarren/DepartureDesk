class SupplierClause < ApplicationRecord
  CLAUSE_TYPES = %w[release attrition cancellation guarantee].freeze
  CAPACITY_ACTIONS = %w[none release reduction expiration guarantee_adjustment].freeze
  COMMITMENT_ACTIONS = %w[none open release satisfy cancel].freeze

  belongs_to :agency
  belongs_to :office
  belongs_to :departure
  belongs_to :arrangement, class_name: "SupplierArrangement", inverse_of: :supplier_clauses
  belongs_to :resource, class_name: "SupplierResource", optional: true, inverse_of: :supplier_clauses
  belongs_to :service_occurrence, class_name: "SupplierServiceOccurrence", optional: true, inverse_of: :supplier_clauses
  belongs_to :governing_term, class_name: "SupplierCostTerm", optional: true, inverse_of: :supplier_clauses
  belongs_to :affected_commitment, class_name: "SupplierCommitment", optional: true, inverse_of: :supplier_clauses
  belongs_to :created_by_membership, class_name: "AgencyMembership", inverse_of: false

  has_many :supplier_deadlines, foreign_key: :source_clause_id, inverse_of: :source_clause, dependent: :restrict_with_exception

  enum :clause_type, CLAUSE_TYPES.index_by(&:itself), validate: true, prefix: :clause
  enum :capacity_action, CAPACITY_ACTIONS.index_by(&:itself), validate: true, prefix: :capacity
  enum :commitment_action, COMMITMENT_ACTIONS.index_by(&:itself), validate: true, prefix: :commitment

  attr_readonly :agency_id, :office_id, :departure_id, :arrangement_id, :created_by_membership_id

  normalizes :name, :capacity_action, :commitment_action, :currency, with: ->(value) { value&.strip }
  normalizes :provenance, with: ->(value) { value&.strip.presence }

  validates :name, :provenance, presence: true
  validates :capacity_quantity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :guaranteed_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :amount_minor_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }, allow_nil: true
  validate :currency_is_known
  validate :same_scope
  validate :effective_interval
  validate :capacity_target_complete
  validate :commitment_target_complete
  validate :guarantee_has_substance

  private

  def currency_is_known
    return if currency.blank?

    Money::Currency.find(currency)
  rescue Money::Currency::UnknownCurrency
    errors.add(:currency, "is not a supported currency")
  end

  def same_scope
    expected = [ agency_id, office_id, departure_id, arrangement_id ]
    errors.add(:office, "must belong to the same agency") if office && agency_id && office.agency_id != agency_id
    errors.add(:departure, "must belong to the same office") if departure && [ departure.agency_id, departure.office_id ] != [ agency_id, office_id ]
    errors.add(:arrangement, "must belong to the same departure") if arrangement && [ arrangement.agency_id, arrangement.office_id, arrangement.departure_id ] != [ agency_id, office_id, departure_id ]
    errors.add(:resource, "must belong to the same arrangement") if resource && [ resource.agency_id, resource.office_id, resource.departure_id, resource.arrangement_id ] != expected
    errors.add(:service_occurrence, "must belong to the same resource") if service_occurrence && [ service_occurrence.agency_id, service_occurrence.office_id, service_occurrence.departure_id, service_occurrence.arrangement_id, service_occurrence.resource_id ] != [ *expected, resource_id ]
    errors.add(:governing_term, "must belong to the same arrangement") if governing_term && [ governing_term.agency_id, governing_term.office_id, governing_term.departure_id, governing_term.arrangement_id ] != expected
    errors.add(:affected_commitment, "must belong to the same arrangement") if affected_commitment && [ affected_commitment.agency_id, affected_commitment.office_id, affected_commitment.departure_id, affected_commitment.arrangement_id ] != expected
  end

  def effective_interval
    return if effective_on.blank? || effective_until.blank? || effective_until > effective_on

    errors.add(:effective_until, "must be after the effective date")
  end

  def capacity_target_complete
    return if capacity_action == "none"

    errors.add(:resource, "is required for capacity consequences") if resource.blank?
    errors.add(:service_occurrence, "is required for capacity consequences") if service_occurrence.blank?
    if capacity_action == "guarantee_adjustment"
      errors.add(:guaranteed_quantity, "is required for guarantee consequences") if guaranteed_quantity.blank?
    elsif capacity_quantity.blank?
      errors.add(:capacity_quantity, "is required for capacity consequences")
    end
  end

  def commitment_target_complete
    if commitment_action == "open"
      errors.add(:governing_term, "is required to open a commitment") if governing_term_id.blank?
    elsif %w[release satisfy cancel].include?(commitment_action)
      errors.add(:affected_commitment, "is required to change a commitment") if affected_commitment_id.blank?
    end
  end

  def guarantee_has_substance
    return unless clause_type == "guarantee"
    return if guaranteed_quantity.present? || amount_minor_units.present? || governing_term_id.present?

    errors.add(:base, "Guarantee clauses require quantity, amount, or a governing term")
  end
end
