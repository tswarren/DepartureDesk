# A rebuildable cache of a group's supplier capacity now and the next event
# due (ADR 0018). Full replay must reproduce it.
class CapacityProjection < ApplicationRecord
  belongs_to :agency
  belongs_to :inventory_group
  belongs_to :last_event, class_name: "CapacityEvent", optional: true
  belongs_to :next_event, class_name: "CapacityEvent", optional: true
end
