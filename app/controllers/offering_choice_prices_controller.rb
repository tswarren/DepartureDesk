# S-20: one choice's client prices as a grid (BKG-21). Staff who can see
# supplier cost see it under each price (ACC-31).
class OfferingChoicePricesController < ApplicationController
  include PackageAccess

  KEY_FORMAT = /\A((?:single|any|guest_[1-9])(?:\+(?:single|any|guest_[1-9]))*)\|([0-9a-f-]{36})?\z/

  before_action :require_departure_view!
  before_action :require_package_management!
  before_action :set_departure
  before_action :set_offering
  before_action :set_choice

  def edit
    @grid = grid
  end

  def update
    @grid = grid
    SaveOfferingPrices.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, offering: @offering, choice: @choice, cells: changed_cells).call
    redirect_to departure_offerings_path(@departure, anchor: "choice-#{@choice.id}"), notice: "#{@choice.name} prices saved."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @error = error.message
    @grid = grid(submitted: { "prices" => submitted(:prices), "original" => submitted(:original) })
    render :edit, status: :unprocessable_entity
  end

  private

  def set_choice
    @choice = @offering.choices.find(params[:choice_id])
  end

  def grid(submitted: nil)
    extra = params[:traveler_type_id].presence && Current.agency.traveler_types.find_by(id: params[:traveler_type_id])
    split = Array(params.permit(split: [])[:split]).grep(KEY_FORMAT)
    ClientPriceGrid.new(@choice, extra_type: extra, split:, submitted:, show_cost: Current.agency_user.permitted?(:view_supplier_costs))
  end

  # Only the grid's own options and columns are read.
  def submitted(scope)
    params.fetch(scope, {}).permit(@grid.options.to_h { |option| [ option.id, @grid.columns.map(&:key) ] }).to_h
  end

  def changed_cells
    prices = submitted(:prices)
    originals = submitted(:original)
    @grid.options.flat_map do |option|
      @grid.columns.filter_map do |column|
        value = prices.dig(option.id, column.key)
        next if value.nil? || value.to_s.strip == originals.dig(option.id, column.key).to_s.strip

        match = KEY_FORMAT.match(column.key) or next
        SaveOfferingPrices::Cell.new(option_id: option.id, positions: match[1].split("+"), traveler_type_id: match[2],
          amount: value, label: "#{option.label}, #{column.label}")
      end
    end
  end
end
