class ClientOrganizationsController < ApplicationController
  include DirectoryAccess

  before_action :require_directory_view!
  before_action :require_directory_management!, except: %i[index show]
  before_action :set_client_organization, except: %i[index new create]

  def index
    @status = SearchClientDirectory::STATUSES.include?(params[:status]) ? params[:status] : "active"
    @kind = "organizations"
    @search = SearchClientDirectory.call(
      agency: Current.agency,
      actor: Current.agency_user,
      query: params[:q],
      status: @status,
      kind: @kind
    )
    render "clients/index"
  rescue AgencyCommand::Error => error
    @search = SearchClientDirectory::Outcome.new(records: [], truncated: false)
    flash.now[:alert] = error.message
    render "clients/index", status: :unprocessable_entity
  end

  def new
    @client_organization = directory_organizations.new
  end

  def create
    result = CreateClientOrganization.new(
      agency: Current.agency,
      actor: Current.agency_user,
      names: organization_params,
      acknowledgement_token: acknowledgement_params[:acknowledgement_token],
      acknowledgement_reason: acknowledgement_params[:acknowledgement_reason]
    ).call
    redirect_to client_organization_path(result.record), notice: "Organization saved. No Client was created."
  rescue AgencyCommand::DuplicateReviewRequired => error
    @client_organization = directory_organizations.new(organization_params)
    rescue_duplicate_review(error, :new)
  rescue AgencyCommand::Error => error
    @client_organization = directory_organizations.new(organization_params.except(:lock_version))
    rescue_directory_error(error, :new)
  end

  def show
    @current_contacts = @client_organization.organization_contacts.current.includes(:client_person).primary_first
    @historical_contacts = @client_organization.organization_contacts.historical.includes(:client_person).primary_first
    return unless can_view_contact_details?

    @email_addresses = @client_organization.email_addresses.preferred_first
    @phone_numbers = @client_organization.phone_numbers.preferred_first
    @postal_addresses = @client_organization.postal_addresses.preferred_first
    @websites = @client_organization.websites.preferred_first
  end

  def edit
  end

  def update
    UpdateClientOrganization.new(
      agency: Current.agency,
      actor: Current.agency_user,
      client_organization: @client_organization,
      names: organization_params,
      lock_version: organization_params[:lock_version],
      acknowledgement_token: acknowledgement_params[:acknowledgement_token],
      acknowledgement_reason: acknowledgement_params[:acknowledgement_reason]
    ).call
    redirect_to client_organization_path(@client_organization), notice: "Organization updated."
  rescue AgencyCommand::DuplicateReviewRequired => error
    @duplicate_profile_kind = :organization
    @client_organization.assign_attributes(organization_params.except(:lock_version))
    rescue_duplicate_review(error, :edit)
  rescue AgencyCommand::Error => error
    @client_organization.assign_attributes(organization_params.except(:lock_version))
    rescue_directory_error(error, :edit)
  end

  def edit_status
  end

  def update_status
    ChangeClientOrganizationStatus.new(
      agency: Current.agency,
      actor: Current.agency_user,
      client_organization: @client_organization,
      status: params.expect(:status),
      lock_version: params.expect(:lock_version)
    ).call
    redirect_to client_organization_path(@client_organization), notice: "Organization status updated."
  rescue AgencyCommand::Error => error
    rescue_directory_error(error, :edit_status)
  end

  def create_client
    result = CreateClientForOrganization.new(agency: Current.agency, actor: Current.agency_user, client_organization: @client_organization).call
    redirect_to client_organization_path(@client_organization), notice: "Client #{result.record.client_reference} created."
  rescue AgencyCommand::Error => error
    redirect_to client_organization_path(@client_organization), alert: error.message
  end

  def edit_client_status
    @client = @client_organization.client || raise(ActiveRecord::RecordNotFound)
  end

  def update_client_status
    client = @client_organization.client || raise(ActiveRecord::RecordNotFound)
    ChangeClientStatus.new(
      agency: Current.agency,
      actor: Current.agency_user,
      client: client,
      status: params.expect(:status),
      lock_version: params.expect(:lock_version)
    ).call
    redirect_to client_organization_path(@client_organization), notice: "Client status updated."
  rescue AgencyCommand::Error => error
    @client = client
    rescue_directory_error(error, :edit_client_status)
  end
end
