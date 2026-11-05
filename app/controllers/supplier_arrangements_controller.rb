class SupplierArrangementsController < ApplicationController
  include ArrangementAccess

  before_action :require_arrangement_view!
  before_action :require_arrangement_management!, except: %i[index show]
  before_action :set_departure
  before_action :set_arrangement, only: %i[show edit update]

  def index
    @arrangements = @departure.supplier_arrangements.includes(:supplier)
  end

  def show
  end

  def new
    @arrangement = @departure.supplier_arrangements.new(currency: @departure.operating_currency)
  end

  def create
    result = CreateSupplierArrangement.new(
      agency: Current.agency, actor: Current.agency_user, departure: @departure,
      supplier_id: arrangement_params[:supplier_id], attributes: arrangement_params.except(:supplier_id, :lock_version)
    ).call
    redirect_to departure_arrangement_path(@departure, result.record), notice: "Arrangement saved as Draft."
  rescue AgencyCommand::Error => error
    @arrangement = @departure.supplier_arrangements.new(arrangement_params.except(:lock_version))
    render_error(error, :new)
  end

  def edit
    redirect_to departure_arrangement_path(@departure, @arrangement), alert: "Only a draft arrangement can be edited." unless @arrangement.draft?
  end

  def update
    UpdateSupplierArrangement.new(
      agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement,
      attributes: arrangement_params.except(:supplier_id, :lock_version), lock_version: arrangement_params[:lock_version]
    ).call
    redirect_to departure_arrangement_path(@departure, @arrangement), notice: "Arrangement updated."
  rescue AgencyCommand::Error => error
    @arrangement.assign_attributes(arrangement_params.except(:supplier_id, :lock_version))
    render_error(error, :edit)
  end

  private

  def render_error(error, template)
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @arrangement.errors.add(arrangement_error_attribute(error.message), error.message)
    render template, status: :unprocessable_entity
  end
end
