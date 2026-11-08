# S-14: the supplier rate grid. One form saves the values every fare
# shares and every group's fares; a refused save re-renders what was typed.
class SupplierRatesController < ApplicationController
  include SupplierRateAccess

  def edit
    @grid = SupplierRateGrid.new(@arrangement)
    @sources = CopySupplierRates.sources(Current.agency, @arrangement).includes(:departure).order(:created_at)
  end

  def update
    SaveSupplierRates.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement,
      defaults: rate_params.fetch("defaults", {}), cells: rate_params.fetch("cells", {})).call
    redirect_to departure_arrangement_path(@departure, @arrangement, anchor: "rate-table"), notice: "Supplier rates saved."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @grid = SupplierRateGrid.new(@arrangement, submitted: rate_params)
    @sources = CopySupplierRates.sources(Current.agency, @arrangement).includes(:departure).order(:created_at)
    flash.now[:alert] = error.message
    render :edit, status: :unprocessable_entity
  end

  private

  CELL_FIELDS = [ :fare, :discount, { override: %i[non_commissionable_fees taxes commission_method commission_rate commission_base commission_amount] } ].freeze

  # The cell keys are "<group id>:<band id>"; each cell's own fields are fixed.
  def rate_params
    @rate_params ||= begin
      rates = params.fetch(:rates, ActionController::Parameters.new)
      cells = rates.fetch(:cells, ActionController::Parameters.new)
      {
        "defaults" => rates.fetch(:defaults, ActionController::Parameters.new).permit(*SupplierRateGrid::DEFAULT_FIELDS).to_h,
        "cells" => cells.keys.grep(/\A[0-9a-f-]{36}:[0-9a-f-]{36}\z/).to_h { |key| [ key, cells.fetch(key).permit(*CELL_FIELDS).to_h ] }
      }
    end
  end
end
