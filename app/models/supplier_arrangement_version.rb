class SupplierArrangementVersion < ApplicationRecord
  STATUSES = %w[draft activated superseded abandoned].freeze
  ABANDONED_REASON_LIMIT = 500

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement

  has_many :arrangement_item_definitions, dependent: :restrict_with_exception
  has_many :service_occurrence_definitions, dependent: :restrict_with_exception
  has_many :supplier_resource_definitions, dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true, default: "draft"

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id, :version_number

  normalizes :abandoned_reason, with: ->(value) { value.to_s.strip.presence }

  validates :version_number, numericality: { only_integer: true, greater_than: 0 }
  validates :abandoned_reason, length: { maximum: ABANDONED_REASON_LIMIT }, allow_nil: true
  validate :abandonment_fields_match_status

  private

  def abandonment_fields_match_status
    if abandoned?
      errors.add(:abandoned_at, "can't be blank") if abandoned_at.blank?
      errors.add(:abandoned_reason, "can't be blank") if abandoned_reason.blank?
    else
      errors.add(:abandoned_at, "must be blank unless abandoned") if abandoned_at.present?
      errors.add(:abandoned_reason, "must be blank unless abandoned") if abandoned_reason.present?
    end
  end
end
