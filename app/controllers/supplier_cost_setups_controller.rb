class SupplierCostSetupsController < ApplicationController
  include SupplierCostAccess

  COMMAND = CreateSupplierCostSetup

  def new
    render plain: "Guided cost setup is coming in a later M3D.0 phase.", status: :not_implemented
  end

  def create
    render plain: "Guided cost setup is coming in a later M3D.0 phase.", status: :not_implemented
  end
end
