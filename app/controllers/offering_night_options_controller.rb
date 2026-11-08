# S-20: extra hotel nights as a package add-on, one option per night and
# room type (BKG-14 to BKG-16, INV-13).
class OfferingNightOptionsController < ApplicationController
  include PackageAccess

  before_action :require_departure_view!
  before_action :require_package_management!
  before_action :set_departure
  before_action :set_offering
  before_action :load_nights

  def new
    @name = "Extension nights"
    @from = @nights.first
    @through = @nights.last
    @chosen_kinds = @kinds
  end

  def create
    @name = params[:name].to_s.squish.presence || "Extension nights"
    @from = parse_date(params[:from])
    @through = parse_date(params[:through])
    @chosen_kinds = Array(params[:kinds]) & @kinds
    groups = @groups.select { |group| @chosen_kinds.include?(group.night_kind) && @from && @through && (@from..@through).cover?(group.starts_on) }
    price_from = @offering.choices.find_by(id: params[:price_from_choice_id]) if params[:price_from_choice_id].present?
    AddNightOptions.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, offering: @offering,
      name: @name, groups:, price_from:).call
    redirect_to departure_offerings_path(@departure), notice: "#{@name} added with #{helpers.pluralize(groups.size, "option")}."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @error = error.message
    render :new, status: :unprocessable_entity
  end

  private

  # The Departure's one-night hotel groups not yet offered, by night and room type.
  def load_nights
    offered = @offering.choices.flat_map(&:options).map(&:inventory_group_id)
    @groups = InventoryGroup.joins(:supplier_arrangement).where(supplier_arrangements: { departure_id: @departure.id, status: %w[draft confirmed] })
      .where(service_category: %w[hotel all_inclusive_resort]).order(:starts_on, :label).to_a
      .select(&:night_kind).reject { |group| offered.include?(group.id) }
    @nights = @groups.map(&:starts_on).uniq.sort
    @kinds = @groups.map(&:night_kind).uniq
    @room_choices = @offering.choices.select { |choice| choice.included? && choice.made_per_unit? && choice.options.any? { |option| option.inventory_group.night_kind } }
  end

  def parse_date(value)
    Date.iso8601(value.to_s)
  rescue Date::Error
    nil
  end
end
