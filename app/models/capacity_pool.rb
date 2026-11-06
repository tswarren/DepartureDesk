# Interchangeable places for a capacity-pool inventory group (INV-10),
# created at confirmation (SUP-12). It carries the group's availability
# promise instead of the shipped pool modes (ADR 0018).
class CapacityPool < ApplicationRecord
  belongs_to :agency
  belongs_to :inventory_group

  attr_readonly :agency_id, :inventory_group_id
end
