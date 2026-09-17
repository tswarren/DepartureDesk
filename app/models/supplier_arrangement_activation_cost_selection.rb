class SupplierArrangementActivationCostSelection < ApplicationRecord
  include AppendOnlyRecord

  SELECTION_KINDS = %w[contracted provisional_estimate].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_arrangement_activation
  belongs_to :supplier_cost_source
  belongs_to :supplier_cost_definition

  enum :selection_kind, SELECTION_KINDS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :supplier_arrangement_activation_id
end
