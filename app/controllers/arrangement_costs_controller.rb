# The arrangement's Rates and cost page (UX consolidation audit B1).
class ArrangementCostsController < ApplicationController
  include ArrangementPage

  before_action -> { require_permission!(:view_supplier_costs) }

  def show
  end
end
