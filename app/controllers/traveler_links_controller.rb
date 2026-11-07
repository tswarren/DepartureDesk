# Links an existing traveler to a client, or removes a link (CLT-09, CLT-10).
class TravelerLinksController < ApplicationController
  include DirectoryAccess
  include TripAccess

  SEARCH_LIMIT = 20

  before_action :require_directory_view!
  before_action :require_directory_management!

  def new
    @client = Current.agency.clients.find(params[:client_id])
    @query = params[:q].to_s.squish
    @travelers = matching_travelers
  end

  def create
    @client = Current.agency.clients.find(params[:client_id])
    LinkTraveler.new(agency: Current.agency, actor: Current.agency_user, client: @client,
      traveler_id: params[:traveler_id], relationship: params[:relationship]).call
    redirect_to client_profile_path_for(@client), notice: "Traveler linked."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to new_traveler_link_path(client_id: @client.id, q: params[:q]), alert: error.message
  end

  def destroy
    link = Current.agency.traveler_links.find(params[:id])
    UnlinkTraveler.new(agency: Current.agency, actor: Current.agency_user, link:).call
    redirect_to client_profile_path_for(link.client), notice: "Link removed. The traveler is unchanged."
  end

  private

  def matching_travelers
    return Traveler.none if @query.blank?

    pattern = "%#{Traveler.sanitize_sql_like(@query)}%"
    Current.agency.travelers
      .where("concat_ws(' ', given_names, middle_name, surname, preferred_name) ILIKE ?", pattern)
      .where.not(id: @client.traveler_links.select(:traveler_id))
      .ordered.limit(SEARCH_LIMIT)
  end
end
