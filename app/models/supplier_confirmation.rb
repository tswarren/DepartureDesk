class SupplierConfirmation < ApplicationRecord
  STATUSES = %w[effective superseded].freeze

  belongs_to :agency
  belongs_to :office
  belongs_to :departure
  belongs_to :arrangement, class_name: "SupplierArrangement", optional: true, inverse_of: :supplier_confirmations
  belongs_to :reservation, class_name: "SupplierReservation", optional: true, inverse_of: :supplier_confirmations
  belongs_to :issuer_party, class_name: "Party", inverse_of: :supplier_confirmations_as_issuer
  belongs_to :entered_by_membership, class_name: "AgencyMembership", inverse_of: false
  belongs_to :superseded_by_membership, class_name: "AgencyMembership", optional: true, inverse_of: false

  enum :status, STATUSES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :office_id, :departure_id, :arrangement_id, :reservation_id, :issuer_party_id,
    :identifier_type, :context, :raw_value, :normalized_value, :entered_by_membership_id

  normalizes :identifier_type, :context, :raw_value, :normalized_value, :issuer_display_name_snapshot,
    :source_channel, :document_reference, :supersession_reason, with: ->(value) { value&.strip.presence }

  validates :issuer_display_name_snapshot, :identifier_type, :context, :raw_value, :normalized_value, presence: true
  validates :normalized_value, uniqueness: { scope: %i[agency_id issuer_party_id identifier_type context] }
  validate :exactly_one_owner
  validate :same_scope
  validate :status_metadata

  scope :effective, -> { where(status: "effective") }

  private

  def exactly_one_owner
    errors.add(:base, "choose exactly one confirmation owner") if arrangement_id.present? == reservation_id.present?
  end

  def same_scope
    errors.add(:issuer_party, "must belong to the same agency") if issuer_party && agency_id && issuer_party.agency_id != agency_id
    errors.add(:arrangement, "must belong to the same departure") if arrangement && [ arrangement.agency_id, arrangement.office_id, arrangement.departure_id ] != [ agency_id, office_id, departure_id ]
    errors.add(:reservation, "must belong to the same departure") if reservation && [ reservation.agency_id, reservation.office_id, reservation.departure_id ] != [ agency_id, office_id, departure_id ]
  end

  def status_metadata
    if superseded?
      if superseded_at.blank? || superseded_by_membership_id.blank? || supersession_reason.blank?
        errors.add(:supersession_reason, "is required when superseded")
      end
    elsif superseded_at.present? || superseded_by_membership_id.present? || supersession_reason.present?
      errors.add(:supersession_reason, "must be blank while effective")
    end
  end
end
