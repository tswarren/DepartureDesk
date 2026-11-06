# A unit shell a cost line covers, such as a commitment for unsold space
# naming its shells (D-75).
class CostLineShell < ApplicationRecord
  belongs_to :agency
  belongs_to :cost_line
  belongs_to :unit_shell
end
