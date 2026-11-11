# A traveler's details as they appear on the reseller's bookings: legal
# name and date of birth, which confirming needs (CLT-15, CLT-25).
class Reseller::TravelersController < ApplicationController
  include ResellerArea

  FIELDS = %i[given_names middle_name surname date_of_birth].freeze
  ERROR_FIELDS = [ [ :given_names, /given names/i ], [ :surname, /surname/i ], [ :date_of_birth, /date of birth/i ] ].freeze

  before_action -> { require_permission!(:reseller_manage_bookings) }
  before_action :set_traveler

  def edit
  end

  def update
    SaveTraveler.new(agency: Current.agency, actor: Current.agency_user, traveler: @traveler,
      attributes: traveler_params, lock_version: params.dig(:traveler, :lock_version)).call
    redirect_to return_path, notice: "#{@traveler.reload.display_name} updated."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @traveler.assign_attributes(traveler_params.except(:date_of_birth))
    render_form_error(error, @traveler, :edit, ERROR_FIELDS)
  end

  private

  def set_traveler
    @traveler = reseller_scope.travelers.find(params[:id])
    @booking = reseller_scope.bookings.find_by(id: params[:booking_id])
  end

  def return_path
    @booking ? reseller_client_booking_path(@booking, step: "travelers") : reseller_root_path
  end

  def traveler_params
    params.fetch(:traveler, {}).permit(*FIELDS).to_h.symbolize_keys
  end
end
