# One work item a person must act on by a due instant (OPS-01, OPS-02).
# Every task uses this record whatever created it. Its status moves through
# the task lifecycle (OPS-03); overdue is derived from Clock.current and
# never stored. Completing it changes no other record.
class Task < ApplicationRecord
  SOURCES = %w[supplier_deadline schedule_line amount_due manual].freeze
  STATUSES = %w[open in_progress completed waived].freeze
  ACTIVE_STATUSES = %w[open in_progress].freeze
  NOTE_LIMIT = 2_000

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_deadline, optional: true
  belongs_to :schedule_line, optional: true
  belongs_to :amount_due, optional: true
  belongs_to :owner, class_name: "AgencyUser"

  enum :source, SOURCES.index_by(&:itself), validate: true, prefix: :from
  enum :status, STATUSES.index_by(&:itself), validate: true, default: "open"

  attr_readonly :agency_id, :departure_id, :source, :supplier_deadline_id, :schedule_line_id, :amount_due_id

  validates :action, presence: true, length: { maximum: 250 }
  validates :due_at, :due_on, :due_time_zone, presence: true
  validates :completion_note, :waiver_reason, length: { maximum: NOTE_LIMIT }, allow_nil: true
  validate :owner_is_agency_staff

  scope :active, -> { where(status: ACTIVE_STATUSES) }
  scope :by_due, -> { order(:due_at, :created_at) }

  def active? = status.in?(ACTIVE_STATUSES)

  # SMN-12: completing it records this trigger event, when its arrangement
  # is confirmed.
  def records_event_type
    return unless supplier_deadline&.supplier_arrangement&.confirmed?

    supplier_deadline.trigger_event_type
  end

  def overdue?(now = Clock.current.now)
    active? && due_at < now
  end

  private

  def owner_is_agency_staff
    return unless owner

    errors.add(:owner, "must belong to the same agency") if owner.agency_id != agency_id
    errors.add(:owner, "must be an Agency Admin or Staff user") if owner.reseller?
  end
end
