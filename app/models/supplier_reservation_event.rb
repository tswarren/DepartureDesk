class SupplierReservationEvent < ApplicationRecord
  include AppendOnlyRecord

  EVENT_KINDS = %w[request withdrawal cancellation response revision].freeze
  TEXT_LIMIT = 500

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_reservation
  belongs_to :supplier_reservation_revision
  belongs_to :actor, class_name: "AgencyUser"
  belongs_to :supplier_contact, optional: true
  belongs_to :agency_command_idempotency_key, optional: true

  has_many :scope_outcomes, class_name: "SupplierReservationEventScopeOutcome",
    dependent: :restrict_with_exception

  enum :event_kind, EVENT_KINDS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :supplier_reservation_id,
    :supplier_reservation_revision_id, :event_kind, :occurred_at, :recorded_at,
    :actor_id, :supplier_contact_id, :channel, :safe_contact_snapshot,
    :reference_note, :reason, :scope_fingerprint, :agency_command_idempotency_key_id

  normalizes :channel, :safe_contact_snapshot, :reference_note, :reason,
    :scope_fingerprint, with: ->(value) { value.to_s.strip.presence }

  validates :occurred_at, :recorded_at, presence: true
  validates :channel, length: { maximum: 80 }, allow_nil: true
  validates :safe_contact_snapshot, :reference_note, :reason, length: { maximum: TEXT_LIMIT }, allow_nil: true
  validates :scope_fingerprint, length: { maximum: 128 }, allow_nil: true
  validate :required_context

  private

  def required_context
    if request? || response?
      errors.add(:channel, "can't be blank") if channel.blank?
      errors.add(:reference_note, "can't be blank") if reference_note.blank?
    elsif withdrawal? || cancellation?
      errors.add(:reason, "can't be blank") if reason.blank?
    end
  end
end
