# What a supplier commitment will cost in total (SMN-01, SMN-02). Scope is
# the arrangement, one inventory group, named unit shells (D-75), or a client
# booking, proposed at its confirmation from the rate table (SUP-35); the
# basis is a fixed amount, a fixed amount per unit, person or night, or a
# percentage of another cost line. Committed lines make up committed cost
# exposure (SUP-13); estimated lines stay separate as forecasts.
class CostLine < ApplicationRecord
  SCOPES = %w[arrangement inventory_group unit_shells client_booking].freeze
  BASES = %w[fixed per_unit per_person per_night percentage].freeze
  QUANTITY_BASES = %w[per_unit per_person per_night].freeze
  STAGES = %w[estimated committed].freeze
  DESCRIPTION_LIMIT = 200

  belongs_to :agency
  belongs_to :supplier_arrangement
  belongs_to :inventory_group, optional: true
  belongs_to :base_cost_line, class_name: "CostLine", optional: true
  belongs_to :client_booking, optional: true
  has_many :cost_line_shells, dependent: :restrict_with_exception
  has_many :unit_shells, through: :cost_line_shells
  has_many :schedule_lines, dependent: :restrict_with_exception
  has_many :dependent_cost_lines, class_name: "CostLine", foreign_key: :base_cost_line_id, inverse_of: :base_cost_line, dependent: :restrict_with_exception

  enum :scope, SCOPES.index_by(&:itself), validate: true, prefix: :scoped_to
  enum :basis, BASES.index_by(&:itself), validate: true, prefix: :basis
  enum :stage, STAGES.index_by(&:itself), validate: true, prefix: :stage

  attr_readonly :agency_id, :supplier_arrangement_id, :currency

  normalizes :description, with: ->(value) { value.to_s.squish }

  validates :description, presence: true, length: { maximum: DESCRIPTION_LIMIT }
  validates :amount_minor_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # An amount due posted against it fixes it.
  def posted?
    AmountDue.where(schedule_line_id: schedule_lines.select(:id)).exists?
  end
end
