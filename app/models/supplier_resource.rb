class SupplierResource < ApplicationRecord
  STATUSES = %w[active inactive].freeze
  CAPACITY_UNITS = %w[seat room cabin vehicle policy unit].freeze

  belongs_to :agency
  belongs_to :office
  belongs_to :departure
  belongs_to :arrangement, class_name: "SupplierArrangement", inverse_of: :supplier_resources
  belongs_to :created_by_membership, class_name: "AgencyMembership", inverse_of: false
  belongs_to :status_changed_by_membership, class_name: "AgencyMembership", inverse_of: false

  has_many :supplier_reservation_resources, foreign_key: :resource_id, inverse_of: :resource, dependent: :restrict_with_exception
  has_many :supplier_reservations, through: :supplier_reservation_resources, source: :reservation
  has_many :supplier_service_occurrences, foreign_key: :resource_id, inverse_of: :resource, dependent: :restrict_with_exception
  has_many :supplier_cost_terms, foreign_key: :resource_id, inverse_of: :resource, dependent: :restrict_with_exception
  has_many :supplier_commitments, foreign_key: :resource_id, inverse_of: :resource, dependent: :restrict_with_exception
  has_many :supplier_capacity_positions, foreign_key: :resource_id, inverse_of: :resource, dependent: :restrict_with_exception
  has_many :supplier_capacity_events, foreign_key: :resource_id, inverse_of: :resource, dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :office_id, :departure_id, :arrangement_id, :created_by_membership_id

  normalizes :name, :resource_kind, :capacity_unit, with: ->(value) { value&.strip }
  normalizes :description, :status_reason, with: ->(value) { value&.strip.presence }

  validates :name, :resource_kind, :status_changed_at, presence: true
  validates :capacity_unit, presence: true, inclusion: { in: CAPACITY_UNITS }
  validate :same_agency_scope
  validate :status_metadata

  private

  def same_agency_scope
    errors.add(:office, "must belong to the same agency") if office && agency_id && office.agency_id != agency_id
    errors.add(:departure, "must belong to the same agency") if departure && agency_id && departure.agency_id != agency_id
    errors.add(:departure, "must belong to the same office") if departure && office_id && departure.office_id != office_id
    errors.add(:arrangement, "must belong to the same departure") if arrangement && [ arrangement.agency_id, arrangement.office_id, arrangement.departure_id ] != [ agency_id, office_id, departure_id ]
  end

  def status_metadata
    if inactive?
      errors.add(:status_reason, "is required") if status_reason.blank?
    elsif status_reason.present?
      errors.add(:status_reason, "must be blank while active")
    end
  end
end
