# frozen_string_literal: true

class HotelArrangementsController < ApplicationController
  include HotelArrangementAccess

  before_action :require_departure_view!
  before_action :set_departure
  before_action :ensure_composable_departure!
  before_action :set_supplier_arrangement
  before_action :set_hotel_version
  before_action :assign_hotel_composition_context

  def show
    @editable = hotel_editable?
    @lodging_items = DetectHotelInventoryShape.lodging_items(@supplier_arrangement_version)
    @shapes = @lodging_items.index_with do |item|
      DetectHotelInventoryShape.new(
        agency: Current.agency,
        arrangement: @supplier_arrangement,
        version: @supplier_arrangement_version,
        item: item
      ).call
    end
  end
end
