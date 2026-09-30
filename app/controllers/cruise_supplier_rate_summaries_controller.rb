# frozen_string_literal: true

class CruiseSupplierRateSummariesController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :require_compatible_cruise_shape!

  def show
    @workspace = CompileCruiseSupplierRatesWorkspace.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement,
      shape: @shape
    ).call
    @editable = @supplier_arrangement_version&.draft?
    @item = @shape.item
  end

  private

  def require_compatible_cruise_shape!
    @shape = DetectCruiseArrangementShape.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement
    ).call
    @supplier_arrangement_version = @shape.version
    return if @shape.compatible?

    redirect_to departure_arrangement_cruise_path(@departure, @supplier_arrangement),
      alert: "This Arrangement uses an advanced structure. Open advanced Supplier planning."
  end
end
