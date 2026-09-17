class SupplierArrangement < ApplicationRecord
  STATUSES = %w[draft active ended abandoned].freeze
  NAME_LIMIT = 160

  belongs_to :agency
  belongs_to :departure
  belongs_to :contracting_supplier, class_name: "Supplier"
  belongs_to :supplier_contact, optional: true

  has_many :versions, class_name: "SupplierArrangementVersion", dependent: :restrict_with_exception
  has_many :arrangement_items, dependent: :restrict_with_exception
  has_many :service_occurrences, dependent: :restrict_with_exception
  has_many :supplier_resources, dependent: :restrict_with_exception
  has_many :capacity_pair_definitions, dependent: :restrict_with_exception
  has_many :capacity_pools, dependent: :restrict_with_exception
  has_many :capacity_pool_definitions, dependent: :restrict_with_exception
  has_many :capacity_events, dependent: :restrict_with_exception
  has_many :capacity_projections, dependent: :restrict_with_exception
  has_many :capacity_reconciliations, dependent: :restrict_with_exception
  has_many :capacity_reconciliation_resolutions, dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true, default: "draft"

  attr_readonly :agency_id, :departure_id, :contracting_supplier_id

  normalizes :name, with: ->(value) { value.to_s.strip }

  validates :name, presence: true, length: { maximum: NAME_LIMIT }
  validate :abandoned_time_matches_status
  validate :contact_belongs_to_contractor

  private

  def abandoned_time_matches_status
    if abandoned?
      errors.add(:abandoned_at, "can't be blank") if abandoned_at.blank?
    elsif abandoned_at.present?
      errors.add(:abandoned_at, "must be blank unless abandoned")
    end
  end

  def contact_belongs_to_contractor
    return if supplier_contact.blank? || contracting_supplier.blank?
    return if supplier_contact.agency_id == agency_id &&
      supplier_contact.supplier_id == contracting_supplier_id

    errors.add(:supplier_contact, "must belong to the contracting supplier")
  end
end
