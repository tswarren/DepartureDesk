class SupplierCostOccupancyProfilesController < ApplicationController
  include SupplierCostAccess

  before_action :set_assumption
  before_action :set_profile, only: %i[update destroy]

  def create
    result = CreateSupplierCostOccupancyProfile.new(
      agency: Current.agency, actor: Current.agency_user, assumption: @assumption,
      attributes: profile_params, positions: participant_category_ids,
      assumption_lock_version: params[:assumption_lock_version], idempotency_key: params[:idempotency_key]
    ).call
    redirect_to arrangement_location("profile-#{result.record.id}"), notice: "Occupancy profile saved."
  rescue AgencyCommand::Error => error
    handle_cost_error(error)
  end

  def update
    UpdateSupplierCostOccupancyProfile.new(
      agency: Current.agency, actor: Current.agency_user, profile: @profile,
      attributes: profile_params, positions: participant_category_ids,
      lock_version: profile_params[:lock_version]
    ).call
    redirect_to arrangement_location("profile-#{@profile.id}"), notice: "Occupancy profile updated."
  rescue AgencyCommand::Error => error
    handle_cost_error(error)
  end

  def destroy
    RemoveSupplierCostOccupancyProfile.new(
      agency: Current.agency, actor: Current.agency_user, profile: @profile,
      assumption_lock_version: params[:assumption_lock_version]
    ).call
    redirect_to arrangement_location("assumption-#{@assumption.id}"), notice: "Occupancy profile removed."
  rescue AgencyCommand::Error => error
    handle_cost_error(error)
  end

  def reorder
    ReorderSupplierCostOccupancyProfiles.new(
      agency: Current.agency, actor: Current.agency_user, assumption: @assumption,
      supplier_cost_occupancy_profile_ids: params[:supplier_cost_occupancy_profile_ids],
      assumption_lock_version: params[:assumption_lock_version]
    ).call
    redirect_to arrangement_location("assumption-#{@assumption.id}"), notice: "Occupancy profiles reordered."
  rescue AgencyCommand::Error => error
    handle_cost_error(error)
  end

  private

  def set_assumption
    @assumption = @supplier_arrangement_version.supplier_cost_usage_assumptions
      .where(arrangement_item_id: @arrangement_item.id).find(params[:cost_assumption_id])
  end

  def set_profile
    @profile = @assumption.supplier_cost_occupancy_profiles.find(params[:id])
  end

  def profile_params
    params.fetch(:supplier_cost_occupancy_profile, {}).permit(:label, :resource_unit_count, :lock_version)
  end

  def participant_category_ids
    Array(params[:participant_category_ids]).reject(&:blank?)
  end
end
