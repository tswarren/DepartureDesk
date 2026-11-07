# A shell a Client booking confirmed event names (D-81): a per-shell
# schedule line falls due for that shell only.
class TriggerEventShell < ApplicationRecord
  belongs_to :agency
  belongs_to :trigger_event
  belongs_to :unit_shell

  before_update { raise ActiveRecord::ReadOnlyRecord }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }
end
