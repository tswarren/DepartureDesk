# frozen_string_literal: true

class CompositionFamilySetupsController < ApplicationController
  include DepartureAccess
  include CompositionAccess
  include SupplierArrangementAccess

  before_action :require_composition_access!
  before_action :set_departure
  before_action :ensure_composable_departure!

  def new
    @family = family
    @idempotency_key = SecureRandom.uuid
    @arrangement_attributes = {}
    @item_attributes = {}
    @occurrence_attributes = { time_zone: @departure.time_zone }
    render :new
  end

  def create
    @family = family
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    @arrangement_attributes = params.fetch(:arrangement, {}).permit(:name, :contracting_supplier_id).to_h
    @item_attributes = params.fetch(:item, {}).permit(:name).to_h
    @occurrence_attributes = params.fetch(:occurrence, {}).permit(:name, :starts_on, :ends_on, :time_zone, :pickup, :dropoff).to_h
    result = build_command.call
    redirect_to workspace_path(result.record.arrangement), status: :see_other, notice: "#{family_title} saved."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @form_error = error.message
    render :new, status: :unprocessable_entity
  end

  private

  def family
    return "transportation" if request.path.include?("/transportation")
    return "activities" if request.path.include?("/activities")

    "hotels"
  end

  def family_title
    { "hotels" => "Hotel", "transportation" => "Transportation", "activities" => "Activity" }.fetch(@family)
  end
  helper_method :family_title

  def build_command
    case @family
    when "transportation"
      CreateTransportationSegment.new(
        agency: Current.agency, actor: Current.agency_user, departure: @departure,
        idempotency_key: @idempotency_key, seat_count: params[:seat_count],
        arrangement_attributes: @arrangement_attributes, item_attributes: @item_attributes,
        occurrence_attributes: @occurrence_attributes
      )
    when "activities"
      CreateActivityOffering.new(
        agency: Current.agency, actor: Current.agency_user, departure: @departure, template: params[:template].presence || "activity",
        idempotency_key: @idempotency_key, arrangement_attributes: @arrangement_attributes,
        item_attributes: @item_attributes, occurrence_attributes: @occurrence_attributes
      )
    else
      CreateHotelStaySetup.new(
        agency: Current.agency, actor: Current.agency_user, departure: @departure,
        idempotency_key: @idempotency_key, arrangement_attributes: @arrangement_attributes,
        item_attributes: @item_attributes, occurrence_attributes: @occurrence_attributes
      )
    end
  end

  def workspace_path(arrangement)
    case @family
    when "transportation"
      departure_arrangement_transportation_path(@departure, arrangement)
    when "activities"
      departure_arrangement_activities_path(@departure, arrangement)
    else
      departure_arrangement_hotel_path(@departure, arrangement)
    end
  end
end
