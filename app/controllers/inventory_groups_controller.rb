class InventoryGroupsController < ApplicationController
  include ArrangementAccess

  ERROR_FIELDS = [ [ :label, /label/i ], [ :quantity, /quantity/i ], [ :positions_per_unit, /positions/i ], [ :ends_on, /end date|start date/i ], [ :time_zone, /time ?zone/i ] ].freeze

  before_action :require_arrangement_view!
  before_action :require_arrangement_management!, except: :show
  before_action :set_departure
  before_action :set_arrangement
  before_action :set_group, only: %i[show edit update destroy]

  def show
  end

  def new
    @group = @arrangement.inventory_groups.new(service_category: "cruise", availability_promise: @arrangement.default_availability_promise, time_zone: @departure.time_zone)
  end

  def create
    result = SaveInventoryGroup.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement, attributes: group_params.except(:lock_version)).call
    redirect_to departure_arrangement_inventory_path(@departure, @arrangement), notice: "#{result.record.label} added."
  rescue AgencyCommand::Error => error
    @group = @arrangement.inventory_groups.new(group_params.except(:lock_version))
    render_form_error(error, @group, :new, ERROR_FIELDS)
  end

  def edit
  end

  def update
    SaveInventoryGroup.new(
      agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement, group: @group,
      attributes: group_params.except(:lock_version), lock_version: group_params[:lock_version]
    ).call
    redirect_to departure_arrangement_group_path(@departure, @arrangement, @group), notice: "Inventory group updated."
  rescue AgencyCommand::Error => error
    @group.assign_attributes(group_params.except(:lock_version))
    render_form_error(error, @group, :edit, ERROR_FIELDS)
  end

  def destroy
    RemoveInventoryGroup.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement, group: @group).call
    redirect_to departure_arrangement_inventory_path(@departure, @arrangement), notice: "Inventory group removed."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to departure_arrangement_group_path(@departure, @arrangement, @group), alert: error.message
  end

  private

  def set_group
    @group = @arrangement.inventory_groups.find(params[:group_id] || params[:id])
  end

  def group_params
    params.require(:inventory_group).permit(
      :label, :service_category, :representation, :availability_promise, :quantity, :positions_per_unit,
      :starts_on, :starts_at_time, :ends_on, :ends_at_time, :time_zone, :lock_version
    )
  end
end
