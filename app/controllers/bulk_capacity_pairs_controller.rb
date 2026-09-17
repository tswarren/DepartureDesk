class BulkCapacityPairsController < ApplicationController
  include ItemCapacityAccess

  COMMAND = BulkClassifyCapacityPairs

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_capacity_context

  def update
    decisions = bulk_capacity_pair_params.fetch(:decisions, {}).values
      .select { |decision| ActiveModel::Type::Boolean.new.cast(decision[:selected]) }
    BulkClassifyCapacityPairs.new(
      agency: Current.agency,
      actor: Current.agency_user,
      item: @arrangement_item,
      decisions: decisions,
      version_lock_version: bulk_capacity_pair_params[:version_lock_version],
      idempotency_key: bulk_capacity_pair_params[:idempotency_key]
    ).call
    redirect_to departure_arrangement_item_capacity_path(
      @departure, @supplier_arrangement, @arrangement_item
    ), notice: "Reviewed capacity pairs updated."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @submitted_bulk_decisions = bulk_capacity_pair_params.fetch(:decisions, {}).to_h
    @bulk_idempotency_key = bulk_capacity_pair_params[:idempotency_key]
    flash.now[:alert] = error.message
    render_capacity_show
  end

  private

  def bulk_capacity_pair_params
    params.permit(:version_lock_version, :idempotency_key, decisions: {})
  end
end
