# When a portion of a supplier cost falls due (SMN-04): an amount or basis
# and a due rule. It pays toward its cost line or the arrangement and never
# adds to cost (SMN-03). It may name the supplier deadline it pays, whose
# task it then uses (SMN-17).
class ScheduleLine < ApplicationRecord
  AMOUNT_KINDS = %w[fixed percentage_of_cost_line per_unit_count per_shell].freeze
  DUE_RULES = %w[fixed_date event event_plus_days earlier_of].freeze
  EVENT_RULES = %w[event event_plus_days earlier_of].freeze
  DESCRIPTION_LIMIT = 200

  belongs_to :agency
  belongs_to :supplier_arrangement
  belongs_to :cost_line, optional: true
  belongs_to :supplier_deadline, optional: true
  belongs_to :inventory_group, optional: true
  has_many :amounts_due, class_name: "AmountDue", dependent: :restrict_with_exception
  has_one :task, dependent: :restrict_with_exception

  enum :amount_kind, AMOUNT_KINDS.index_by(&:itself), validate: true
  enum :due_rule, DUE_RULES.index_by(&:itself), validate: true, prefix: :due
  enum :trigger_type, TriggerEvent::TYPES.index_by(&:itself), validate: { allow_nil: true }, prefix: :triggered_by

  attr_readonly :agency_id, :supplier_arrangement_id, :currency

  normalizes :description, with: ->(value) { value.to_s.squish }

  validates :description, presence: true, length: { maximum: DESCRIPTION_LIMIT }

  def event_driven? = due_rule.in?(EVENT_RULES)
  def dated? = due_on.present?
end
