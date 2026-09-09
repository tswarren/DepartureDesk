class SupplierCostTerm < ApplicationRecord
  SHAPES = %w[
    fixed per_resource per_person per_night minimum_guarantee
    tiered stepped percentage complimentary_ratio pass_through
    manual_estimate
  ].freeze
  BASES = %w[estimate contracted].freeze
  STATUSES = %w[draft active superseded void].freeze
  ROUNDING_METHODS = %w[nearest_minor_unit].freeze
  TAX_FEE_TREATMENTS = %w[included excluded separate].freeze

  belongs_to :agency
  belongs_to :office
  belongs_to :departure
  belongs_to :arrangement, class_name: "SupplierArrangement", inverse_of: :supplier_cost_terms
  belongs_to :reservation, class_name: "SupplierReservation", optional: true, inverse_of: :supplier_cost_terms
  belongs_to :resource, class_name: "SupplierResource", optional: true, inverse_of: :supplier_cost_terms
  belongs_to :service_occurrence, class_name: "SupplierServiceOccurrence", optional: true, inverse_of: :supplier_cost_terms
  belongs_to :supersedes_term, class_name: "SupplierCostTerm", optional: true, inverse_of: :superseding_terms
  belongs_to :created_by_membership, class_name: "AgencyMembership", inverse_of: false
  belongs_to :status_changed_by_membership, class_name: "AgencyMembership", inverse_of: false

  has_many :superseding_terms, class_name: "SupplierCostTerm", foreign_key: :supersedes_term_id, inverse_of: :supersedes_term, dependent: :restrict_with_exception
  has_many :supplier_commitments, foreign_key: :governing_term_id, inverse_of: :governing_term, dependent: :restrict_with_exception
  has_many :supplier_deposit_requirements, dependent: :restrict_with_exception

  has_one :fixed_detail, class_name: "SupplierCostTermFixedDetail", dependent: :restrict_with_exception
  has_one :per_resource_detail, class_name: "SupplierCostTermPerResourceDetail", dependent: :restrict_with_exception
  has_one :per_person_detail, class_name: "SupplierCostTermPerPersonDetail", dependent: :restrict_with_exception
  has_one :per_night_detail, class_name: "SupplierCostTermPerNightDetail", dependent: :restrict_with_exception
  has_one :minimum_guarantee_detail, class_name: "SupplierCostTermMinimumGuaranteeDetail", dependent: :restrict_with_exception
  has_many :tiers, class_name: "SupplierCostTermTier", dependent: :restrict_with_exception
  has_many :steps, class_name: "SupplierCostTermStep", dependent: :restrict_with_exception
  has_one :percentage_base_ref, class_name: "SupplierCostTermPercentageBaseRef", dependent: :restrict_with_exception
  has_many :complimentary_ratio_rules, class_name: "SupplierCostTermComplimentaryRatioRule", dependent: :restrict_with_exception
  has_one :pass_through_provenance, class_name: "SupplierCostTermPassThroughProvenance", dependent: :restrict_with_exception
  has_one :manual_estimate_detail, class_name: "SupplierCostTermManualEstimateDetail", dependent: :restrict_with_exception

  enum :shape, SHAPES.index_by(&:itself), validate: true
  enum :basis, BASES.index_by(&:itself), validate: true
  enum :status, STATUSES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :office_id, :departure_id, :arrangement_id, :reservation_id, :resource_id,
    :service_occurrence_id, :economic_item_id, :economic_item_key, :basis, :created_by_membership_id

  normalizes :economic_item_key, :cost_category, :quantity_basis, :quantity_unit, :currency, :rounding_method,
    :tax_fee_treatment, with: ->(value) { value&.strip }
  normalizes :source_reference, :provenance, :status_reason, with: ->(value) { value&.strip.presence }

  validates :economic_item_id, :economic_item_key, :cost_category, :quantity_basis, :quantity_unit, :currency,
    :rounding_method, :tax_fee_treatment, :provenance, :status_changed_at, presence: true
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validates :rounding_method, inclusion: { in: ROUNDING_METHODS }
  validates :tax_fee_treatment, inclusion: { in: TAX_FEE_TREATMENTS }
  validates :term_version, numericality: { only_integer: true, greater_than: 0 }
  validate :currency_is_known
  validate :same_scope
  validate :effective_interval
  validate :status_metadata
  validate :active_term_immutable, on: :update
  before_validation :assign_economic_item_id, on: :create

  scope :active, -> { where(status: "active") }

  def self.economic_item_key_for(arrangement:, reservation: nil, resource: nil, service_occurrence: nil, cost_category:, quantity_basis:, quantity_unit:, currency:)
    [
      "arrangement:#{arrangement.id}",
      "reservation:#{reservation&.id || '-'}",
      "resource:#{resource&.id || '-'}",
      "occurrence:#{service_occurrence&.id || '-'}",
      "category:#{cost_category.to_s.strip}",
      "basis:#{quantity_basis.to_s.strip}",
      "unit:#{quantity_unit.to_s.strip}",
      "currency:#{currency.to_s.strip.upcase}"
    ].join("|")
  end

  def detail_record
    public_send("#{shape}_detail")
  end

  def display_snapshot
    "#{basis} #{shape} #{cost_category} #{term_version}"
  end

  private

  def assign_economic_item_id
    self.economic_item_id ||= SecureRandom.uuid_v7(extra_timestamp_bits: 12)
  end

  def currency_is_known
    return if currency.blank?

    Money::Currency.find(currency)
  rescue Money::Currency::UnknownCurrency
    errors.add(:currency, "is not a supported currency")
  end

  def same_scope
    errors.add(:office, "must belong to the same agency") if office && agency_id && office.agency_id != agency_id
    errors.add(:departure, "must belong to the same office") if departure && [ departure.agency_id, departure.office_id ] != [ agency_id, office_id ]
    if arrangement && [ arrangement.agency_id, arrangement.office_id, arrangement.departure_id ] != [ agency_id, office_id, departure_id ]
      errors.add(:arrangement, "must belong to the same departure")
    end
    if reservation && [ reservation.agency_id, reservation.office_id, reservation.departure_id, reservation.arrangement_id ] != [ agency_id, office_id, departure_id, arrangement_id ]
      errors.add(:reservation, "must belong to the same arrangement")
    end
    if resource && [ resource.agency_id, resource.office_id, resource.departure_id, resource.arrangement_id ] != [ agency_id, office_id, departure_id, arrangement_id ]
      errors.add(:resource, "must belong to the same arrangement")
    end
    if service_occurrence && [ service_occurrence.agency_id, service_occurrence.office_id, service_occurrence.departure_id, service_occurrence.arrangement_id ] != [ agency_id, office_id, departure_id, arrangement_id ]
      errors.add(:service_occurrence, "must belong to the same arrangement")
    end
  end

  def effective_interval
    return if effective_on.blank? || effective_until.blank? || effective_until > effective_on

    errors.add(:effective_until, "must be after the effective date")
  end

  def status_metadata
    if superseded? || void?
      errors.add(:status_reason, "is required") if status_reason.blank?
    elsif status_reason.present?
      errors.add(:status_reason, "must be blank while draft or active")
    end
  end

  def active_term_immutable
    return unless status_was == "active"

    permitted = %w[status status_changed_at status_changed_by_membership_id status_reason lock_version updated_at]
    forbidden = changed - permitted
    errors.add(:base, "active cost terms must be superseded or voided") if forbidden.any?
  end
end
