class ClientsController < ApplicationController
  include DirectoryAccess

  before_action :require_directory_view!
  before_action :require_directory_management!, only: %i[new create]

  def index
    @status = directory_status_filter
    if params[:q].present?
      @search = SearchClientDirectory.call(
        agency: Current.agency,
        actor: Current.agency_user,
        query: params[:q],
        status: @status
      )
    else
      @people = filtered_people
    end
  rescue AgencyCommand::Error => error
    @people = []
    flash.now[:alert] = error.message
    render :index, status: :unprocessable_entity
  end

  def new
    @client_person = directory_people.new
  end

  def create
    if params[:client_person_id].present?
      person = directory_people.find(params[:client_person_id])
      result = CreateClientForPerson.new(agency: Current.agency, actor: Current.agency_user, client_person: person).call
      redirect_to client_person_path(result.record.client_person), notice: "Client created."
      return
    end

    result = CreateIndividualClient.new(
      agency: Current.agency,
      actor: Current.agency_user,
      names: person_params,
      acknowledgement_token: acknowledgement_params[:acknowledgement_token],
      acknowledgement_reason: acknowledgement_params[:acknowledgement_reason]
    ).call
    redirect_to client_person_path(result.record.client_person), notice: "Client created."
  rescue AgencyCommand::DuplicateReviewRequired => error
    @client_person = directory_people.new(person_params)
    rescue_duplicate_review(error, :new)
  rescue AgencyCommand::Error => error
    @client_person = directory_people.new(person_params.except(:lock_version))
    rescue_directory_error(error, :new)
  end

  private

  def directory_status_filter
    SearchClientDirectory::STATUSES.include?(params[:status]) ? params[:status] : "active"
  end

  def filtered_people
    scope = directory_people.left_outer_joins(:client).includes(:client)
    scope = scope.where(status: @status) unless @status == "all"
    scope.order(:last_name, :first_name, :id).limit(50)
  end
end
