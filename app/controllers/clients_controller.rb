class ClientsController < ApplicationController
  include DirectoryAccess

  before_action :require_directory_view!
  before_action :require_directory_management!, only: %i[new create]

  def index
    @status = directory_status_filter
    @kind = directory_kind_filter
    @search = SearchClientDirectory.call(
      agency: Current.agency,
      actor: Current.agency_user,
      query: params[:q],
      status: @status,
      kind: @kind
    )
  rescue AgencyCommand::Error => error
    @search = SearchClientDirectory::Outcome.new(records: [], truncated: false)
    flash.now[:alert] = error.message
    render :index, status: :unprocessable_entity
  end

  def new
    @source = params[:source].presence_in(%w[individual organization]) || "individual"
    @client_person = directory_people.new
    @client_organization = directory_organizations.new
  end

  def create
    if params[:client_person_id].present?
      person = directory_people.find(params[:client_person_id])
      result = CreateClientForPerson.new(agency: Current.agency, actor: Current.agency_user, client_person: person).call
      redirect_to client_person_path(result.record.client_person), notice: "Client created."
      return
    end

    if organization_create?
      result = CreateOrganizationClient.new(
        agency: Current.agency,
        actor: Current.agency_user,
        names: organization_params,
        acknowledgement_token: acknowledgement_params[:acknowledgement_token],
        acknowledgement_reason: acknowledgement_params[:acknowledgement_reason]
      ).call
      redirect_to client_organization_path(result.record.client_organization), notice: "Client created."
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
    if organization_create?
      @source = "organization"
      @client_organization = directory_organizations.new(organization_params)
      @client_person = directory_people.new
      rescue_duplicate_review(error, :new)
    else
      @source = "individual"
      @client_person = directory_people.new(person_params)
      @client_organization = directory_organizations.new
      rescue_duplicate_review(error, :new)
    end
  rescue AgencyCommand::Error => error
    if organization_create?
      @source = "organization"
      @client_organization = directory_organizations.new(organization_params.except(:lock_version))
      @client_person = directory_people.new
      rescue_directory_error(error, :new)
    else
      @source = "individual"
      @client_person = directory_people.new(person_params.except(:lock_version))
      @client_organization = directory_organizations.new
      rescue_directory_error(error, :new)
    end
  end

  private

  def directory_status_filter
    SearchClientDirectory::STATUSES.include?(params[:status]) ? params[:status] : "active"
  end

  def directory_kind_filter
    SearchClientDirectory::RECORD_KINDS.include?(params[:kind]) ? params[:kind] : "all"
  end

  def organization_create?
    params[:client_organization].present? || params[:source] == "organization"
  end
end
