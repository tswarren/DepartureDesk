class SupplierConfirmation < ApplicationRecord
  include AppendOnlyRecord

  EVIDENCE_KINDS = %w[
    contract supplier_confirmation supplier_message supplier_portal verbal_confirmation other
  ].freeze
  TEXT_LIMIT = 500

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :confirming_supplier, class_name: "Supplier"
  belongs_to :actor, class_name: "AgencyUser"

  has_many :supplier_confirmation_activation_links, dependent: :restrict_with_exception
  has_many :supplier_arrangement_activations,
    through: :supplier_confirmation_activation_links
  has_many :supplier_confirmation_identifier_links, dependent: :restrict_with_exception
  has_many :supplier_issued_identifiers, through: :supplier_confirmation_identifier_links
  has_many :supplier_confirmation_capacity_event_links, dependent: :restrict_with_exception
  has_many :capacity_events, through: :supplier_confirmation_capacity_event_links
  has_many :supplier_confirmation_commitment_links, dependent: :restrict_with_exception
  has_many :supplier_commitments, through: :supplier_confirmation_commitment_links

  enum :evidence_kind, EVIDENCE_KINDS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id

  normalizes :other_evidence_label, :channel, :reference_note,
    :confirmed_without_identifier_reason, with: ->(value) { value.to_s.strip.presence }

  validates :evidence_on, :channel, :reference_note, :recorded_at, presence: true
  validates :reference_note, :confirmed_without_identifier_reason,
    length: { maximum: TEXT_LIMIT }, allow_nil: true
  validates :other_evidence_label, length: { maximum: 80 }, allow_nil: true
  validate :other_label_matches_kind

  private

  def other_label_matches_kind
    if other?
      errors.add(:other_evidence_label, "can't be blank") if other_evidence_label.blank?
    elsif other_evidence_label.present?
      errors.add(:other_evidence_label, "must be blank unless evidence kind is other")
    end
  end
end
