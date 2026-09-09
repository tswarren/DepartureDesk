class SupplierReservation < ApplicationRecord
  STATUSES = %w[requested submitted confirmed declined unable_to_confirm cancelled].freeze
  NONTERMINAL_STATUSES = %w[requested submitted confirmed].freeze
  TERMINAL_STATUSES = %w[declined unable_to_confirm cancelled].freeze

  belongs_to :agency
  belongs_to :office
  belongs_to :departure
  belongs_to :arrangement, class_name: "SupplierArrangement", inverse_of: :supplier_reservations
  belongs_to :created_by_membership, class_name: "AgencyMembership", inverse_of: false
  belongs_to :status_changed_by_membership, class_name: "AgencyMembership", inverse_of: false
  belongs_to :confirmed_without_identifier_by_membership, class_name: "AgencyMembership", optional: true, inverse_of: false

  has_many :supplier_reservation_resources, foreign_key: :reservation_id, inverse_of: :reservation, dependent: :restrict_with_exception
  has_many :supplier_resources, through: :supplier_reservation_resources, source: :resource
  has_many :supplier_confirmations, foreign_key: :reservation_id, inverse_of: :reservation, dependent: :restrict_with_exception
  has_many :supplier_cost_terms, foreign_key: :reservation_id, inverse_of: :reservation, dependent: :restrict_with_exception
  has_many :supplier_commitments, foreign_key: :reservation_id, inverse_of: :reservation, dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :office_id, :departure_id, :arrangement_id, :created_by_membership_id

  normalizes :name, with: ->(value) { value&.strip }
  normalizes :operational_notes, :confirmed_without_identifier_reason, :status_reason, with: ->(value) { value&.strip.presence }

  validates :name, :status_changed_at, presence: true
  validate :same_agency_scope
  validate :confirmation_metadata
  validate :status_metadata

  scope :nonterminal, -> { where(status: NONTERMINAL_STATUSES) }
  scope :terminal, -> { where(status: TERMINAL_STATUSES) }

  def nonterminal?
    NONTERMINAL_STATUSES.include?(status)
  end

  private

  def same_agency_scope
    errors.add(:office, "must belong to the same agency") if office && agency_id && office.agency_id != agency_id
    errors.add(:departure, "must belong to the same agency") if departure && agency_id && departure.agency_id != agency_id
    errors.add(:departure, "must belong to the same office") if departure && office_id && departure.office_id != office_id
    errors.add(:arrangement, "must belong to the same departure") if arrangement && [ arrangement.agency_id, arrangement.office_id, arrangement.departure_id ] != [ agency_id, office_id, departure_id ]
  end

  def confirmation_metadata
    reason_path = confirmed_without_identifier_reason.present? || confirmed_without_identifier_at.present? || confirmed_without_identifier_by_membership_id.present?
    if confirmed?
      if reason_path && (confirmed_without_identifier_reason.blank? || confirmed_without_identifier_at.blank? || confirmed_without_identifier_by_membership_id.blank?)
        errors.add(:confirmed_without_identifier_reason, "must include reason, actor, and timestamp")
      end
    elsif reason_path
      errors.add(:confirmed_without_identifier_reason, "must be blank until confirmation")
    end
  end

  def status_metadata
    if TERMINAL_STATUSES.include?(status)
      errors.add(:status_reason, "is required") if status_reason.blank?
    elsif status_reason.present?
      errors.add(:status_reason, "must be blank until terminal")
    end
  end
end
