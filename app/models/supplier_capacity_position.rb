class SupplierCapacityPosition < ApplicationRecord
  BUCKETS = %w[agency_held pending_request guaranteed consumed released_current].freeze

  belongs_to :agency
  belongs_to :office
  belongs_to :departure
  belongs_to :arrangement, class_name: "SupplierArrangement"
  belongs_to :resource, class_name: "SupplierResource", inverse_of: :supplier_capacity_positions
  belongs_to :service_occurrence, class_name: "SupplierServiceOccurrence", inverse_of: :supplier_capacity_positions

  has_many :supplier_capacity_events, inverse_of: :supplier_capacity_position, dependent: :restrict_with_exception

  attr_readonly :agency_id, :office_id, :departure_id, :arrangement_id, :resource_id, :service_occurrence_id, :capacity_unit

  normalizes :capacity_unit, with: ->(value) { value&.strip }

  validates :capacity_unit, presence: true, inclusion: { in: SupplierResource::CAPACITY_UNITS }
  validates :agency_held, :pending_request, :guaranteed, :consumed, :released_current,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :supplier_reported_total, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :same_scope
  validate :available_not_negative

  def available
    agency_held - consumed
  end

  def released_cumulative
    supplier_capacity_events.release.sum(:quantity)
  end

  def self.rebuild_buckets_from_events(events)
    events.each_with_object(BUCKETS.index_with(0)) do |event, buckets|
      buckets["agency_held"] += event.agency_held_delta
      buckets["pending_request"] += event.pending_request_delta
      buckets["guaranteed"] += event.guaranteed_delta
      buckets["consumed"] += event.consumed_delta
      buckets["released_current"] += event.released_current_delta
      raise ActiveRecord::RecordInvalid, new if BUCKETS.any? { |bucket| buckets[bucket].negative? }
    end
  end

  private

  def same_scope
    expected = [ agency_id, office_id, departure_id, arrangement_id ]
    errors.add(:resource, "must belong to the same arrangement") if resource && [ resource.agency_id, resource.office_id, resource.departure_id, resource.arrangement_id ] != expected
    errors.add(:service_occurrence, "must belong to the same resource") if service_occurrence && [ service_occurrence.agency_id, service_occurrence.office_id, service_occurrence.departure_id, service_occurrence.arrangement_id, service_occurrence.resource_id ] != [ *expected, resource_id ]
  end

  def available_not_negative
    errors.add(:consumed, "cannot exceed held capacity") if agency_held && consumed && consumed > agency_held
  end
end
