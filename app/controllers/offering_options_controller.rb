# An option's form, and on its edit page, its client prices (BKG-21), set
# in the choice's price grid or one at a time (UX audit A4).
class OfferingOptionsController < ApplicationController
  include PackageAccess

  before_action :require_departure_view!
  before_action :require_package_management!
  before_action :set_departure
  before_action :set_offering
  before_action :set_choice
  before_action :set_option, only: %i[edit update destroy]

  def new
    @option = @choice.options.new
  end

  def create
    result = SaveOfferingOption.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, offering: @offering, choice: @choice,
      attributes: option_params).call
    redirect_to edit_departure_offering_choice_option_path(@departure, @offering, @choice, result.record), notice: "Option added. Set its prices."
  rescue AgencyCommand::Error => error
    @option = @choice.options.new(option_params.slice("label", "description"))
    render_form_error(error, @option, :new, [ [ :label, "Label" ], [ :inventory_group_id, "Choose an inventory group" ] ])
  end

  def edit
    @price = OfferingPrice.new
  end

  def update
    SaveOfferingOption.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, offering: @offering, choice: @choice, option: @option,
      attributes: option_params, lock_version: params.dig(:offering_option, :lock_version)).call
    redirect_to edit_departure_offering_choice_option_path(@departure, @offering, @choice, @option), notice: "Option updated."
  rescue AgencyCommand::Error => error
    @price = OfferingPrice.new
    render_form_error(error, @option, :edit, [ [ :label, "Label" ], [ :inventory_group_id, "Choose an inventory group" ] ])
  end

  def destroy
    RemoveOfferingOption.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, offering: @offering, option: @option).call
    redirect_to departure_offerings_path(@departure), notice: "Option removed."
  end

  private

  def set_choice
    @choice = @offering.choices.find(params[:choice_id])
  end

  def set_option
    @option = @choice.options.includes(prices: :traveler_type).find(params[:id])
  end

  def option_params = form_params(:offering_option, %i[label description inventory_group_id])
end
