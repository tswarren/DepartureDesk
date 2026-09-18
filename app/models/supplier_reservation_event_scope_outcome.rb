class SupplierReservationEventScopeOutcome < ApplicationRecord
  include AppendOnlyRecord

  OUTCOME_KINDS = %w[requested withdrawn cancelled confirmed declined counterproposed].freeze
  QUANTITY_BASES = %w[resource_units traveler_positions].freeze
  TEXT_LIMIT = 500

  COMPATIBLE_OUTCOME_KINDS = {
    "request" => %w[requested].freeze,
    "withdrawal" => %w[withdrawn].freeze,
    "cancellation" => %w[cancelled].freeze,
    "response" => %w[confirmed declined counterproposed].freeze,
    "revision" => [].freeze
  }.freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_reservation
  belongs_to :supplier_reservation_revision
  belongs_to :supplier_reservation_event
  belongs_to :supplier_reservation_scope

  enum :outcome_kind, OUTCOME_KINDS.index_by(&:itself), validate: true
  enum :quantity_basis, QUANTITY_BASES.index_by(&:itself), validate: { allow_nil: true }

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :supplier_reservation_id,
    :supplier_reservation_revision_id, :supplier_reservation_event_id,
    :supplier_reservation_scope_id, :outcome_kind, :quantity, :quantity_basis,
    :supplier_note, :decline_reason

  normalizes :supplier_note, :decline_reason, with: ->(value) { value.to_s.strip.presence }

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :supplier_note, :decline_reason, length: { maximum: TEXT_LIMIT }, allow_nil: true
  validate :quantity_shape
  validate :decline_reason_shape
  validate :outcome_compatible_with_event

  private

  def quantity_shape
    errors.add(:quantity_basis, "must be present with quantity") if quantity.present? && quantity_basis.blank?
    errors.add(:quantity_basis, "must be blank without quantity") if quantity.blank? && quantity_basis.present?
  end

  def decline_reason_shape
    errors.add(:decline_reason, "must match outcome") unless declined? == decline_reason.present?
  end

  def outcome_compatible_with_event
    event = supplier_reservation_event
    return if event.nil?

    allowed = COMPATIBLE_OUTCOME_KINDS.fetch(event.event_kind, [])
    return if allowed.include?(outcome_kind)

    errors.add(:outcome_kind, "is not compatible with the parent event")
  end
end
