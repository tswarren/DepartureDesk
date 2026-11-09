# Hotel rooms by night on a draft arrangement: nights and room types first,
# then what the hotel holds each night (INV-01, INV-13).
class InventoryRoomNightsController < ApplicationController
  include ArrangementAccess

  MAX_NIGHTS = 31
  MAX_TYPES = 6

  before_action :require_arrangement_view!
  before_action :require_arrangement_management!
  before_action :set_departure
  before_action :set_arrangement

  def new
    @first = parse_date(params[:first_night]) || @departure.starts_on
    @last = parse_date(params[:last_night]) || @first
    @room_types = room_types
    @nights = nights
  end

  def create
    @first = parse_date(params[:first_night])
    @last = parse_date(params[:last_night])
    @room_types = room_types
    @nights = nights
    cells = @nights.product(@room_types).map do |night, type|
      key = "#{night.iso8601}|#{type[:name]}"
      cell = params.fetch(:cells, {}).fetch(key, {})
      AddRoomNights::Cell.new(night:, room_type: type[:name], guests: type[:guests], kind: cell[:kind].to_s.presence || "skip", count: cell[:count])
    end
    result = AddRoomNights.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement,
      cells:, time_zone: @departure.time_zone).call
    redirect_to departure_arrangement_inventory_path(@departure, @arrangement), notice: "#{helpers.pluralize(result.record.size, "group")} added."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @error = error.message
    render :new, status: :unprocessable_entity
  end

  private

  # Up to six room types, each with the guests a room holds.
  def room_types
    raw = params[:room_types]
    rows = raw.is_a?(Array) ? raw : (raw.respond_to?(:values) ? raw.values : [])
    rows.first(MAX_TYPES).filter_map do |row|
      next unless row.respond_to?(:permit)

      row = row.permit(:name, :guests)
      name = row[:name].to_s.squish
      guests = Integer(row[:guests].to_s, exception: false)
      { name:, guests: guests&.positive? ? guests : nil } if name.present?
    end.uniq { |type| type[:name].downcase }
  end

  def nights
    return [] unless @first && @last && @last >= @first

    (@first..@last).first(MAX_NIGHTS)
  end

  def parse_date(value)
    Date.iso8601(value.to_s)
  rescue Date::Error
    nil
  end
end
