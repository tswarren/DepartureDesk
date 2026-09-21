# frozen_string_literal: true

class PackagePricesController < ApplicationController
  include DepartureAccess

  before_action :require_unpublished_package_access!
  before_action :set_departure
  before_action :set_package

  def create
    CreatePackagePriceDefinition.new(
      agency: Current.agency, actor: Current.agency_user, package: @package,
      attributes: price_params.merge(idempotency_key: params[:idempotency_key]),
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_package_path(@departure, @package), notice: "Package price saved."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    flash[:alert] = error.message
    redirect_to departure_package_path(@departure, @package)
  end

  def update
    UpdatePackagePriceDefinition.new(
      agency: Current.agency, actor: Current.agency_user, package: @package,
      attributes: price_params,
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_package_path(@departure, @package), notice: "Package price updated."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    flash[:alert] = error.message
    redirect_to departure_package_path(@departure, @package)
  end

  def destroy
    RemovePackagePriceDefinition.new(
      agency: Current.agency, actor: Current.agency_user, package: @package,
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_package_path(@departure, @package), notice: "Package price removed."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    flash[:alert] = error.message
    redirect_to departure_package_path(@departure, @package)
  end

  private

  def require_unpublished_package_access!
    raise ActiveRecord::RecordNotFound unless Current.agency_user&.permitted?(:manage_departures)
  end

  def set_package
    @package = @departure.packages.find(params[:package_id])
  end

  def price_params
    params.fetch(:price, {}).permit(
      :mode, :single_occupancy_supplement_rate,
      components: [ :label, :client_role, :calculation_kind, :amount, :amount_minor_units, :rate,
                    :quantity_basis, :percentage_treatment, :position, { bases: [ :base_position, :direction ] } ]
    )
  end
end
