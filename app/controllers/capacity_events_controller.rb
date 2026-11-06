# Supply changes on a confirmed group (INV-26): an increase, a supplier
# release, or a correction. Each form carries an idempotency key.
class CapacityEventsController < ApplicationController
  include ArrangementAccess

  before_action :require_arrangement_view!
  before_action :require_arrangement_management!
  before_action :set_departure
  before_action :set_arrangement

  def create
    group = @arrangement.inventory_groups.find(params[:group_id])
    context = { agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement, group:,
                effective_on: params[:effective_on], evidence_note: params[:evidence_note], idempotency_key: params[:idempotency_key] }
    case params[:kind]
    when "increase" then IncreaseCapacity.new(**context, quantity: params[:quantity]).call
    when "supplier_release" then RecordSupplierRelease.new(**context, quantity: params[:quantity], unit_shell_id: params[:unit_shell_id]).call
    when "correction" then CorrectCapacity.new(**context, direction: params[:direction], quantity: params[:quantity], corrects_event_id: params[:corrects_event_id]).call
    else raise AgencyCommand::Error.new("Choose a change to record.", code: :invalid)
    end
    redirect_to departure_arrangement_group_path(@departure, @arrangement, group, anchor: "capacity"), notice: "Capacity change recorded."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to departure_arrangement_group_path(@departure, @arrangement, params[:group_id], anchor: "capacity"), alert: error.message
  end
end
