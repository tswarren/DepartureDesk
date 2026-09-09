class SupplierCapacityEvent < ApplicationRecord
  EVENT_TYPES = %w[
    initial_hold
    request
    confirm_request
    increase
    reduction
    release
    reinstatement
    consumption
    restoration
    correction
    expiration
  ].freeze
  ACTOR_KINDS = %w[membership system].freeze

  belongs_to :agency
  belongs_to :office
  belongs_to :departure
  belongs_to :arrangement, class_name: "SupplierArrangement"
  belongs_to :resource, class_name: "SupplierResource", inverse_of: :supplier_capacity_events
  belongs_to :service_occurrence, class_name: "SupplierServiceOccurrence", inverse_of: :supplier_capacity_events
  belongs_to :supplier_capacity_position, inverse_of: :supplier_capacity_events
  belongs_to :reservation, class_name: "SupplierReservation", optional: true, inverse_of: :supplier_capacity_events
  belongs_to :actor_membership, class_name: "AgencyMembership", optional: true, inverse_of: false
  belongs_to :causation_event, class_name: "SupplierCapacityEvent", optional: true, inverse_of: false
  belongs_to :corrected_event, class_name: "SupplierCapacityEvent", optional: true, inverse_of: false

  enum :event_type, EVENT_TYPES.index_by(&:itself), validate: true
  enum :actor_kind, ACTOR_KINDS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :office_id, :departure_id, :arrangement_id, :resource_id, :service_occurrence_id,
    :supplier_capacity_position_id, :reservation_id, :capacity_unit, :event_type, :quantity, :agency_held_delta,
    :pending_request_delta, :guaranteed_delta, :consumed_delta, :released_current_delta, :commanded_at,
    :effective_on, :actor_kind, :actor_membership_id, :actor_identifier, :reason, :idempotency_key,
    :causation_event_id, :corrected_event_id, :supplier_approval_reference, :supplier_approval_received_at

  normalizes :capacity_unit, :supplier_approval_reference, :actor_identifier, :idempotency_key, with: ->(value) { value&.strip.presence }
  normalizes :reason, with: ->(value) { value&.strip }

  validates :capacity_unit, presence: true, inclusion: { in: SupplierResource::CAPACITY_UNITS }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :commanded_at, :effective_on, :reason, :idempotency_key, presence: true
  validate :same_scope
  validate :actor_metadata
  validate :event_metadata

  before_update :reject_mutation
  before_destroy :reject_mutation

  private

  def same_scope
    expected = [ agency_id, office_id, departure_id, arrangement_id ]
    errors.add(:resource, "must belong to the same arrangement") if resource && [ resource.agency_id, resource.office_id, resource.departure_id, resource.arrangement_id ] != expected
    errors.add(:service_occurrence, "must belong to the same resource") if service_occurrence && [ service_occurrence.agency_id, service_occurrence.office_id, service_occurrence.departure_id, service_occurrence.arrangement_id, service_occurrence.resource_id ] != [ *expected, resource_id ]
    errors.add(:supplier_capacity_position, "must belong to the same occurrence") if supplier_capacity_position && [ supplier_capacity_position.agency_id, supplier_capacity_position.office_id, supplier_capacity_position.departure_id, supplier_capacity_position.arrangement_id, supplier_capacity_position.resource_id, supplier_capacity_position.service_occurrence_id, supplier_capacity_position.capacity_unit ] != [ *expected, resource_id, service_occurrence_id, capacity_unit ]
    errors.add(:reservation, "must belong to the same arrangement") if reservation && [ reservation.agency_id, reservation.office_id, reservation.departure_id, reservation.arrangement_id ] != expected
  end

  def actor_metadata
    if membership?
      errors.add(:actor_membership, "is required") if actor_membership.blank?
      errors.add(:actor_identifier, "must be blank") if actor_identifier.present?
    elsif system?
      errors.add(:actor_membership, "must be blank") if actor_membership.present?
      errors.add(:actor_identifier, "is required") if actor_identifier.blank?
    end
  end

  def event_metadata
    if consumption? || restoration?
      errors.add(:reservation, "is required") if reservation.blank?
    elsif reservation.present?
      errors.add(:reservation, "is only supported for consumption events")
    end

    if reinstatement?
      errors.add(:supplier_approval_reference, "is required") if supplier_approval_reference.blank?
      errors.add(:supplier_approval_received_at, "is required") if supplier_approval_received_at.blank?
    elsif supplier_approval_reference.present? || supplier_approval_received_at.present?
      errors.add(:supplier_approval_reference, "is only supported for reinstatement")
    end
  end

  def reject_mutation
    errors.add(:base, "supplier capacity events are append-only")
    throw :abort
  end
end
