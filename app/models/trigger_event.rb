# Something that happened that a schedule line can fall due on (SMN-11).
# Its date is when it happened, which may be before it was recorded
# (SMN-13); a count recorded with it drives count-based amounts (SMN-14).
# Append-only: an event is never undone automatically (SMN-15).
class TriggerEvent < ApplicationRecord
  TYPES = %w[
    arrangement_confirmed names_submitted client_booking_confirmed rooming_list_submitted final_count_submitted
    tickets_issued supplier_invoice_received service_date other
  ].freeze
  # Recorded by staff on the arrangement in step 4. Arrangement confirmed and
  # service date are recorded by the system, client booking confirmed in step
  # 6, and names submitted stays outside the first slice (D-81).
  STAFF_TYPES = %w[rooming_list_submitted final_count_submitted tickets_issued supplier_invoice_received other].freeze

  belongs_to :agency
  belongs_to :supplier_arrangement
  belongs_to :recorded_by, class_name: "AgencyUser", optional: true

  enum :event_type, TYPES.index_by(&:itself), validate: true

  validates :occurred_on, :recorded_at, presence: true
  validates :count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :reference, length: { maximum: 120 }, allow_nil: true

  before_update { raise ActiveRecord::ReadOnlyRecord }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }
end
