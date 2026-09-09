class SupplierServiceOccurrence < ApplicationRecord
  KINDS = %w[night_slice typed_segment].freeze

  belongs_to :agency
  belongs_to :office
  belongs_to :departure
  belongs_to :arrangement, class_name: "SupplierArrangement"
  belongs_to :resource, class_name: "SupplierResource", inverse_of: :supplier_service_occurrences
  belongs_to :created_by_membership, class_name: "AgencyMembership", inverse_of: false
  has_many :supplier_cost_terms, foreign_key: :service_occurrence_id, inverse_of: :service_occurrence, dependent: :restrict_with_exception
  has_many :supplier_commitments, foreign_key: :service_occurrence_id, inverse_of: :service_occurrence, dependent: :restrict_with_exception
  has_many :supplier_capacity_positions, foreign_key: :service_occurrence_id, inverse_of: :service_occurrence, dependent: :restrict_with_exception
  has_many :supplier_capacity_events, foreign_key: :service_occurrence_id, inverse_of: :service_occurrence, dependent: :restrict_with_exception

  enum :occurrence_kind, KINDS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :office_id, :departure_id, :arrangement_id, :resource_id, :created_by_membership_id

  normalizes :segment_type, :segment_identifier, :label, with: ->(value) { value&.strip.presence }

  validates :occurrence_kind, presence: true
  validate :same_scope
  validate :kind_identity

  private

  def same_scope
    errors.add(:resource, "must belong to the same arrangement") if resource && [ resource.agency_id, resource.office_id, resource.departure_id, resource.arrangement_id ] != [ agency_id, office_id, departure_id, arrangement_id ]
  end

  def kind_identity
    if night_slice?
      errors.add(:service_date, "is required") if service_date.blank?
      errors.add(:segment_identifier, "must be blank for night slices") if segment_type.present? || segment_identifier.present?
    elsif typed_segment?
      errors.add(:service_date, "must be blank for typed segments") if service_date.present?
      errors.add(:segment_type, "is required") if segment_type.blank?
      errors.add(:segment_identifier, "is required") if segment_identifier.blank?
    end
  end
end
