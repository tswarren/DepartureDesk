# S-23 Traveler form and the traveler's own page (CLT-05, CLT-06, CLT-28).
# Created from a client's profile, the traveler is linked to that client.
class TravelersController < ApplicationController
  include DirectoryAccess
  include TripAccess

  FIELD_LABELS = [ [ :surname, "Surname" ], [ :given_names, "Given names" ], [ :date_of_birth, "Date of birth" ],
                   [ :email_address, "Email address" ], [ :phone, "Phone" ] ].freeze

  before_action :require_directory_view!
  before_action :require_directory_management!, except: :show
  before_action :set_traveler, only: %i[show edit update]
  before_action :set_link_client, only: %i[new create]

  def show
    @links = @traveler.links.includes(client: %i[client_person client_organization]).order(:created_at)
  end

  def new
    @traveler = Current.agency.travelers.new(surname: @client&.client_person&.last_name)
    @relationship = "family_member"
  end

  def create
    @relationship = params[:relationship].presence_in(TravelerLink::RELATIONSHIPS) || "other"
    result = SaveTraveler.new(agency: Current.agency, actor: Current.agency_user, attributes: traveler_params,
      link_client: @client, relationship: @relationship).call
    redirect_to(@client ? client_profile_path_for(@client) : traveler_path(result.record), notice: "Traveler saved.")
  rescue AgencyCommand::Error => error
    @traveler = Current.agency.travelers.new(traveler_params.except("date_of_birth"))
    render_form_error(error, @traveler, :new, FIELD_LABELS)
  end

  def edit
  end

  def update
    SaveTraveler.new(agency: Current.agency, actor: Current.agency_user, traveler: @traveler, attributes: traveler_params,
      lock_version: params.dig(:traveler, :lock_version)).call
    redirect_to traveler_path(@traveler), notice: "Traveler updated."
  rescue AgencyCommand::Error => error
    @traveler.assign_attributes(traveler_params.except("date_of_birth"))
    render_form_error(error, @traveler, :edit, FIELD_LABELS)
  end

  private

  def set_traveler
    @traveler = Current.agency.travelers.find(params[:id])
  end

  def set_link_client
    @client = Current.agency.clients.find(params[:client_id]) if params[:client_id].present?
  end

  def traveler_params = form_params(:traveler, TravelerCommandSupport::TRAVELER_FIELDS)
end
