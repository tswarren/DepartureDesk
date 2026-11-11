# S-04: reseller relationships (ACC-13, DOC-08). An Agency Admin, or staff
# with Reseller relationships, authorizes one and sets its name and
# direct-contact setting. Each shows what is published to its channel and
# the bookings it owns (ACC-14).
class ResellersController < ApplicationController
  ERROR_FIELDS = [ [ :name, /name/i ] ].freeze

  before_action -> { require_permission!(:manage_reseller_relationships) }
  before_action :set_reseller, only: %i[show edit update]

  def index
    @resellers = Current.agency.resellers.order(:name)
    @counts = {
      publications: OfferingPublication.open.where(agency: Current.agency).group(:reseller_id).count,
      bookings: Current.agency.client_bookings.where.not(status: "discarded").group(:owner_reseller_id).count
    }
  end

  def show
    @publications = @reseller.offering_publications.open.includes(offering: :departure).order(:published_at)
    @bookings = @reseller.owned_bookings.where.not(status: "discarded")
      .includes(:price_lines, :offering, client_trip: [ :departure, { client: %i[client_person client_organization] } ])
      .order(:booking_reference)
  end

  def new
    @reseller = Current.agency.resellers.new
  end

  def create
    result = SaveReseller.new(agency: Current.agency, actor: Current.agency_user, attributes: reseller_params).call
    redirect_to reseller_path(result.record), notice: "#{result.record.name} authorized."
  rescue AgencyCommand::Error => error
    @reseller = Current.agency.resellers.new(reseller_params)
    render_form_error(error, @reseller, :new, ERROR_FIELDS)
  end

  def edit
  end

  def update
    SaveReseller.new(agency: Current.agency, actor: Current.agency_user, reseller: @reseller, attributes: reseller_params,
      lock_version: params.dig(:reseller, :lock_version)).call
    redirect_to reseller_path(@reseller), notice: "Reseller updated."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @reseller.assign_attributes(reseller_params)
    render_form_error(error, @reseller, :edit, ERROR_FIELDS)
  end

  private

  def set_reseller
    @reseller = Current.agency.resellers.find(params[:id])
  end

  def reseller_params
    params.require(:reseller).permit(:name, :direct_contact_allowed).to_h
  end
end
