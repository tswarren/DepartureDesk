class SupplierCostParticipantCategoriesController < ApplicationController
  include SupplierCostAccess

  before_action :set_category, only: %i[update destroy]

  def create
    CreateSupplierCostParticipantCategory.new(
      agency: Current.agency, actor: Current.agency_user, arrangement_item: @arrangement_item,
      version_lock_version: params[:version_lock_version], attributes: category_params,
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to arrangement_location("item-#{@arrangement_item.id}"), notice: "Participant category saved."
  rescue AgencyCommand::Error => error
    handle_cost_error(error)
  end

  def update
    UpdateSupplierCostParticipantCategory.new(
      agency: Current.agency, actor: Current.agency_user, category: @category,
      lock_version: category_params[:lock_version], attributes: category_params
    ).call
    redirect_to arrangement_location("item-#{@arrangement_item.id}"), notice: "Participant category updated."
  rescue AgencyCommand::Error => error
    handle_cost_error(error)
  end

  def destroy
    RemoveSupplierCostParticipantCategory.new(
      agency: Current.agency, actor: Current.agency_user, category: @category,
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to arrangement_location("item-#{@arrangement_item.id}"), notice: "Participant category removed."
  rescue AgencyCommand::Error => error
    handle_cost_error(error)
  end

  def reorder
    ReorderSupplierCostParticipantCategories.new(
      agency: Current.agency, actor: Current.agency_user, arrangement_item: @arrangement_item,
      supplier_cost_participant_category_ids: params[:supplier_cost_participant_category_ids],
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to arrangement_location("item-#{@arrangement_item.id}"), notice: "Participant categories reordered."
  rescue AgencyCommand::Error => error
    handle_cost_error(error)
  end

  private

  def set_category
    @category = @supplier_arrangement_version.supplier_cost_participant_categories
      .where(arrangement_item_id: @arrangement_item.id).find(params[:id])
  end

  def category_params
    params.fetch(:supplier_cost_participant_category, {}).permit(:label, :lock_version)
  end
end
