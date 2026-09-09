class SupplierArrangement < ApplicationRecord
  STATUSES = %w[draft active cancelled].freeze
  NONTERMINAL_STATUSES = %w[draft active].freeze

  belongs_to :agency
  belongs_to :office
  belongs_to :departure, inverse_of: :supplier_arrangements
  belongs_to :parent_arrangement, class_name: "SupplierArrangement", optional: true, inverse_of: :child_arrangements
  belongs_to :supplier_party, class_name: "Party", inverse_of: :supplier_arrangements_as_supplier
  belongs_to :service_provider_party, class_name: "Party", optional: true, inverse_of: :supplier_arrangements_as_service_provider
  belongs_to :created_by_membership, class_name: "AgencyMembership", inverse_of: false
  belongs_to :status_changed_by_membership, class_name: "AgencyMembership", inverse_of: false

  has_many :child_arrangements, class_name: "SupplierArrangement", foreign_key: :parent_arrangement_id, inverse_of: :parent_arrangement, dependent: :restrict_with_exception
  has_many :supplier_reservations, foreign_key: :arrangement_id, inverse_of: :arrangement, dependent: :restrict_with_exception
  has_many :supplier_resources, foreign_key: :arrangement_id, inverse_of: :arrangement, dependent: :restrict_with_exception
  has_many :supplier_confirmations, foreign_key: :arrangement_id, inverse_of: :arrangement, dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :office_id, :departure_id, :supplier_party_id, :created_by_membership_id

  normalizes :name, with: ->(value) { value&.strip }
  normalizes :description, :client_facing_description, :status_reason, with: ->(value) { value&.strip.presence }
  normalizes :supplier_display_name_snapshot, :service_provider_display_name_snapshot, with: ->(value) { value&.strip.presence }

  validates :name, :supplier_display_name_snapshot, :status_changed_at, presence: true
  validate :same_agency_scope
  validate :same_departure_parent
  validate :status_metadata

  scope :nonterminal, -> { where(status: NONTERMINAL_STATUSES) }
  scope :terminal, -> { where(status: "cancelled") }

  def nonterminal?
    NONTERMINAL_STATUSES.include?(status)
  end

  private

  def same_agency_scope
    errors.add(:office, "must belong to the same agency") if office && agency_id && office.agency_id != agency_id
    errors.add(:departure, "must belong to the same agency") if departure && agency_id && departure.agency_id != agency_id
    errors.add(:departure, "must belong to the same office") if departure && office_id && departure.office_id != office_id
    errors.add(:supplier_party, "must belong to the same agency") if supplier_party && agency_id && supplier_party.agency_id != agency_id
    errors.add(:service_provider_party, "must belong to the same agency") if service_provider_party && agency_id && service_provider_party.agency_id != agency_id
  end

  def same_departure_parent
    return if parent_arrangement.blank?

    if parent_arrangement_id == id
      errors.add(:parent_arrangement, "cannot be itself")
    elsif parent_arrangement.agency_id != agency_id || parent_arrangement.office_id != office_id || parent_arrangement.departure_id != departure_id
      errors.add(:parent_arrangement, "must belong to the same departure")
    end
  end

  def status_metadata
    if cancelled?
      errors.add(:status_reason, "is required") if status_reason.blank?
    elsif status_reason.present?
      errors.add(:status_reason, "must be blank until cancellation")
    end
  end
end
