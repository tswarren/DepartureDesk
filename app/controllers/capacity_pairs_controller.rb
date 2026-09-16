class CapacityPairsController < ApplicationController
  include ItemCapacityAccess

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_capacity_context
  before_action :set_service_occurrence, only: %i[create update]
  before_action :set_supplier_resource, only: %i[create update]
  before_action :set_capacity_pair, only: :destroy

  def create
    classify_pair
  end

  def update
    classify_pair
  end

  def destroy
    RemoveCapacityPairClassification.new(
      agency: Current.agency,
      actor: Current.agency_user,
      pair: @capacity_pair,
      version_lock_version: params[:version_lock_version],
      lock_version: params[:lock_version]
    ).call
    redirect_to departure_arrangement_item_capacity_path(@departure, @supplier_arrangement, @arrangement_item), notice: "Capacity pair removed."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    flash.now[:alert] = error.message
    render_capacity_show
  end

  private

  def classify_pair
    ClassifyCapacityPair.new(
      agency: Current.agency,
      actor: Current.agency_user,
      item: @arrangement_item,
      service_occurrence: @service_occurrence,
      supplier_resource: @supplier_resource,
      classification: pair_params[:classification],
      version_lock_version: pair_params[:version_lock_version]
    ).call
    redirect_to departure_arrangement_item_capacity_path(@departure, @supplier_arrangement, @arrangement_item), notice: "Capacity pair updated."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    flash.now[:alert] = error.message
    render_capacity_show
  end

  def pair_params
    params.permit(:classification, :version_lock_version)
  end
end
