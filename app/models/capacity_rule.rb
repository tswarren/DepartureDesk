# A supplier rule naming a traveler type that takes part in a group without
# using capacity, such as children 0–4 on an activity (INV-39). They count
# in headcount but not in positions used.
class CapacityRule < ApplicationRecord
  belongs_to :agency
  belongs_to :inventory_group
  belongs_to :traveler_type

  validates :traveler_type_id, uniqueness: { scope: :inventory_group_id }
end
