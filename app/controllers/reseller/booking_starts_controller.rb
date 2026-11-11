# Starts a booking on a published offer (D-99 (1), CLT-25): a new client,
# who may also travel, with a trip and a Draft booking owned by the
# reseller's relationship.
class Reseller::BookingStartsController < ApplicationController
  include ResellerArea

  ERROR_FIELDS = [ [ :first_name, /\AFirst name/ ], [ :date_of_birth, /date of birth/i ] ].freeze

  before_action -> { require_permission!(:reseller_manage_bookings) }
  before_action :set_offering

  def new
    @start = ResellerBookingStart.new
  end

  def create
    @start = ResellerBookingStart.new(start_params)
    result = StartResellerBooking.new(agency: Current.agency, actor: Current.agency_user, offering: @offering,
      person: { first_name: @start.first_name, last_name: @start.last_name }, traveling: @start.traveling, date_of_birth: (@start.date_of_birth if @start.traveling)).call
    redirect_to reseller_client_booking_path(result.record, step: "travelers"), notice: "Booking #{result.record.booking_reference} created as a draft."
  rescue AgencyCommand::Error => error
    render_form_error(error, @start, :new, ERROR_FIELDS)
  end

  private

  def set_offering
    @offering = reseller_scope.offerings.includes(:departure).find(params[:offer_id])
  end

  def start_params
    params.fetch(:booking_start, {}).permit(:first_name, :last_name, :traveling, :date_of_birth).to_h
  end
end
