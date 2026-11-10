# The arrangement's Supplier reservations page (UX consolidation audit B1).
class ArrangementReservationsController < ApplicationController
  include ArrangementPage

  before_action -> { require_permission!(:view_supplier_reservations) }

  def show
  end
end
