# What is payable to a supplier now: the only supplier payable (SMN-05).
# Posted when a schedule line's date arrives or its event is recorded, or
# recorded directly by staff. Its amount is calculated and snapshotted when
# posted, with the facts used (SMN-06, SMN-14). A per-shell amount links its
# shell, at most one per shell per schedule line (SMN-10, D-81). Paid status
# is derived once payments exist (build step 8). Append-only.
class AmountDue < ApplicationRecord
  DESCRIPTION_LIMIT = 200

  belongs_to :agency
  belongs_to :supplier_arrangement
  belongs_to :schedule_line, optional: true
  belongs_to :unit_shell, optional: true
  belongs_to :trigger_event, optional: true
  belongs_to :posted_by, class_name: "AgencyUser", optional: true
  has_one :task, dependent: :restrict_with_exception

  validates :description, presence: true, length: { maximum: DESCRIPTION_LIMIT }
  validates :amount_minor_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :due_on, :posted_at, presence: true

  scope :by_due, -> { order(:due_on, :posted_at) }

  def direct? = schedule_line_id.nil?

  before_update { raise ActiveRecord::ReadOnlyRecord }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }
end
