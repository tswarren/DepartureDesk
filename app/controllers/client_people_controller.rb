class ClientPeopleController < ApplicationController
  include DirectoryAccess

  before_action :require_directory_view!
  before_action :require_directory_management!, except: :show
  before_action :set_client_person, except: %i[new create]

  def new
    @client_person = directory_people.new
  end

  def create
    result = CreateClientPerson.new(
      agency: Current.agency,
      actor: Current.agency_user,
      names: person_params,
      acknowledgement_token: acknowledgement_params[:acknowledgement_token],
      acknowledgement_reason: acknowledgement_params[:acknowledgement_reason]
    ).call
    redirect_to client_person_path(result.record), notice: "Person saved. No Client was created."
  rescue AgencyCommand::DuplicateReviewRequired => error
    @client_person = directory_people.new(person_params)
    rescue_duplicate_review(error, :new)
  rescue AgencyCommand::Error => error
    @client_person = directory_people.new(person_params)
    rescue_directory_error(error, :new)
  end

  def show
    return unless can_view_contact_details?

    @email_addresses = @client_person.email_addresses.preferred_first
    @phone_numbers = @client_person.phone_numbers.preferred_first
    @postal_addresses = @client_person.postal_addresses.preferred_first
  end

  def edit
  end

  def update
    UpdateClientPerson.new(
      agency: Current.agency,
      actor: Current.agency_user,
      client_person: @client_person,
      names: person_params,
      lock_version: person_params[:lock_version],
      acknowledgement_token: acknowledgement_params[:acknowledgement_token],
      acknowledgement_reason: acknowledgement_params[:acknowledgement_reason]
    ).call
    redirect_to client_person_path(@client_person), notice: "Person updated."
  rescue AgencyCommand::DuplicateReviewRequired => error
    @client_person.assign_attributes(person_params.except(:lock_version))
    rescue_duplicate_review(error, :edit)
  rescue AgencyCommand::Error => error
    @client_person.assign_attributes(person_params.except(:lock_version))
    rescue_directory_error(error, :edit)
  end

  def edit_status
  end

  def update_status
    ChangeClientPersonStatus.new(
      agency: Current.agency,
      actor: Current.agency_user,
      client_person: @client_person,
      status: params.expect(:status),
      lock_version: params.expect(:lock_version)
    ).call
    redirect_to client_person_path(@client_person), notice: "Person status updated."
  rescue AgencyCommand::Error => error
    rescue_directory_error(error, :edit_status)
  end

  def create_client
    result = CreateClientForPerson.new(agency: Current.agency, actor: Current.agency_user, client_person: @client_person).call
    redirect_to client_person_path(@client_person), notice: "Client #{result.record.client_reference} created."
  rescue AgencyCommand::Error => error
    redirect_to client_person_path(@client_person), alert: error.message
  end

  def edit_client_status
    @client = @client_person.client || raise(ActiveRecord::RecordNotFound)
  end

  def update_client_status
    client = @client_person.client || raise(ActiveRecord::RecordNotFound)
    ChangeClientStatus.new(
      agency: Current.agency,
      actor: Current.agency_user,
      client: client,
      status: params.expect(:status),
      lock_version: params.expect(:lock_version)
    ).call
    redirect_to client_person_path(@client_person), notice: "Client status updated."
  rescue AgencyCommand::Error => error
    @client = client
    rescue_directory_error(error, :edit_client_status)
  end
end
