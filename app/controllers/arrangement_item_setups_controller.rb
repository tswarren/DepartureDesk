class ArrangementItemSetupsController < ApplicationController
  include SupplierArrangementAccess

  COMMAND = CreateArrangementItemSetup

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :set_initial_version

  def new
    render plain: "Guided item setup is coming in a later M3D.0 phase.", status: :not_implemented
  end

  def create
    render plain: "Guided item setup is coming in a later M3D.0 phase.", status: :not_implemented
  end
end
