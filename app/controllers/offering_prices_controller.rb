# Sets or removes one client price on an option (BKG-21).
class OfferingPricesController < ApplicationController
  include PackageAccess

  before_action :require_departure_view!
  before_action :require_package_management!
  before_action :set_departure
  before_action :set_offering

  def create
    option = OfferingOption.joins(:choice).where(offering_choices: { offering_id: @offering.id }).find(params.dig(:offering_price, :offering_option_id))
    SaveOfferingPrice.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, offering: @offering, option:,
      attributes: form_params(:offering_price, %i[occupancy_position traveler_type_id amount])).call
    redirect_to edit_departure_offering_choice_option_path(@departure, @offering, option.choice, option, anchor: "prices"), notice: "Price saved."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to edit_departure_offering_choice_option_path(@departure, @offering, option.choice, option, anchor: "prices"), alert: error.message
  end

  def destroy
    price = OfferingPrice.joins(option: :choice).where(offering_choices: { offering_id: @offering.id }).find(params[:id])
    RemoveOfferingPrice.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, offering: @offering, price:).call
    redirect_to edit_departure_offering_choice_option_path(@departure, @offering, price.option.choice, price.option, anchor: "prices"), notice: "Price removed."
  end
end
