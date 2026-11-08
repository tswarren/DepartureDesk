# S-20: the Departure's Package tab and the offering form.
class OfferingsController < ApplicationController
  include PackageAccess

  before_action :require_departure_view!
  before_action :require_package_management!, except: :index
  before_action :set_departure
  before_action :set_offering, only: %i[edit update]

  def index
    @offerings = @departure.offerings.includes(choices: { options: [ { inventory_group: { supplier_arrangement: [ :supplier, { rate_bands: :traveler_type } ] } }, { prices: :traveler_type } ] })
  end

  def new
    @offering = @departure.offerings.new
  end

  def create
    SaveOffering.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, attributes: offering_params).call
    redirect_to departure_offerings_path(@departure), notice: "Package added."
  rescue AgencyCommand::Error => error
    @offering = @departure.offerings.new(offering_params)
    render_form_error(error, @offering, :new, [ [ :name, "Name" ] ])
  end

  def edit
  end

  def update
    SaveOffering.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, offering: @offering,
      attributes: offering_params, lock_version: params.dig(:offering, :lock_version)).call
    redirect_to departure_offerings_path(@departure), notice: "Package updated."
  rescue AgencyCommand::Error => error
    @offering.assign_attributes(offering_params)
    render_form_error(error, @offering, :edit, [ [ :name, "Name" ] ])
  end

  private

  def offering_params = form_params(:offering, %i[name description])
end
