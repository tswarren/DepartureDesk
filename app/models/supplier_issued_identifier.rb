class SupplierIssuedIdentifier < ApplicationRecord
  include AppendOnlyRecord

  IDENTIFIER_TYPES = %w[
    group_number reservation_number confirmation_number policy_number other
  ].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier
  belongs_to :first_supplier_confirmation, class_name: "SupplierConfirmation"
  belongs_to :supersedes, class_name: "SupplierIssuedIdentifier", optional: true
  belongs_to :supplier_reservation, optional: true
  has_one :successor, class_name: "SupplierIssuedIdentifier", foreign_key: :supersedes_id,
    inverse_of: :supersedes, dependent: :restrict_with_exception

  scope :current, -> { where(superseded_at: nil) }

  enum :identifier_type, IDENTIFIER_TYPES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id, :supplier_id, :supplier_reservation_id

  normalizes :issuer_context, :other_type_label, :display_value,
    with: ->(value) { value.to_s.strip.presence }
  normalizes :normalized_value, with: ->(value) { value.to_s.strip.downcase.presence }

  validates :issuer_context, :display_value, :normalized_value, presence: true
  validates :issuer_context, :other_type_label, length: { maximum: 80 }, allow_nil: true
  validates :display_value, :normalized_value, length: { maximum: 160 }
  validate :other_label_matches_type
  validate :supersession_fields_pair

  private

  def other_label_matches_type
    errors.add(:other_type_label, "must match identifier type") unless
      other? == other_type_label.present?
  end

  def supersession_fields_pair
    # Replacement rows carry supersedes_id without their own superseded_at.
    # Prior rows may later receive superseded_at via the successor-insert stamp trigger.
    return if supersedes_id.blank? && superseded_at.blank?
    return if supersedes_id.present? && superseded_at.blank?
    return if supersedes_id.blank? && superseded_at.present?

    errors.add(:base, "Supersession fields cannot both be set on one identifier row")
  end
end
