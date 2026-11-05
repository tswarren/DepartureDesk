# One operating decision on a Departure (DEP-16, DEP-19). Rows are never
# changed; a new decision is a new row and earlier ones stay as history
# (DEP-20).
class DepartureDecision < ApplicationRecord
  DECISIONS = %w[proceed postpone cancel].freeze
  NOTE_LIMIT = 2_000

  belongs_to :agency
  belongs_to :departure
  belongs_to :decided_by, class_name: "AgencyUser"

  normalizes :note, with: ->(value) { value.to_s.strip.presence }

  validates :decision, inclusion: { in: DECISIONS }
  validates :note, length: { maximum: NOTE_LIMIT }
  validates :note, presence: true, unless: -> { decision == "proceed" }
  validates :decided_at, presence: true

  before_update :reject_mutation
  before_destroy :reject_mutation

  private

  def reject_mutation
    errors.add(:base, "departure decisions are append-only")
    throw :abort
  end
end
