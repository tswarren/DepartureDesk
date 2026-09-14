class ClientOrganizationContactsController < ApplicationController
  include DirectoryAccess

  PERSON_CHOICE_LIMIT = 50

  before_action :require_directory_view!
  before_action :require_contact_detail_view!, only: %i[index show]
  before_action :require_directory_management!, except: %i[index show]
  before_action :set_client_organization
  before_action :set_organization_contact, only: %i[show edit update edit_end end primary]

  def index
    @current_contacts = @client_organization.organization_contacts.current.includes(:client_person).primary_first
    @historical_contacts = @client_organization.organization_contacts.historical.includes(:client_person).primary_first
  end

  def show
  end

  def new
    @organization_contact = @client_organization.organization_contacts.new
    @client_person = directory_people.new
    load_person_choices
  end

  def create
    attributes = create_contact_attributes
    selected_person_id = attributes[:client_person_id].presence
    result = if selected_person_id
      person = directory_people.find(selected_person_id)
      AddClientOrganizationContact.new(
        agency: Current.agency,
        actor: Current.agency_user,
        client_organization: @client_organization,
        client_person: person,
        attributes: attributes
      ).call
    else
      names = new_person_params
      if names[:first_name].blank? || names[:last_name].blank?
        raise AgencyCommand::Error.new("Choose an existing person or enter a first and last name for a new person.", code: :invalid)
      end

      CreateClientPersonAndOrganizationContact.new(
        agency: Current.agency,
        actor: Current.agency_user,
        client_organization: @client_organization,
        names: names,
        attributes: attributes,
        acknowledgement_token: acknowledgement_params[:acknowledgement_token],
        acknowledgement_reason: acknowledgement_params[:acknowledgement_reason]
      ).call
    end
    redirect_to client_organization_path(@client_organization), notice: "Organization contact saved."
  rescue AgencyCommand::DuplicateReviewRequired => error
    prepare_new_after_error
    rescue_duplicate_review(error, :new)
  rescue AgencyCommand::Error, ActiveRecord::RecordNotFound => error
    prepare_new_after_error
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    UpdateClientOrganizationContact.new(
      agency: Current.agency,
      actor: Current.agency_user,
      client_organization_contact: @organization_contact,
      attributes: contact_params,
      lock_version: contact_params[:lock_version]
    ).call
    redirect_to client_organization_path(@client_organization), notice: "Organization contact updated."
  rescue AgencyCommand::Error => error
    @organization_contact.assign_attributes(contact_params.except(:lock_version))
    rescue_directory_error(error, :edit)
  end

  def edit_end
    @replacement_contacts = replacement_contacts
  end

  def end
    EndClientOrganizationContact.new(
      agency: Current.agency,
      actor: Current.agency_user,
      client_organization_contact: @organization_contact,
      lock_version: params.expect(:lock_version),
      replacement_primary_contact: replacement_contact
    ).call
    redirect_to client_organization_path(@client_organization), notice: "Organization contact ended."
  rescue AgencyCommand::Error => error
    @replacement_contacts = replacement_contacts
    rescue_directory_error(error, :edit_end)
  end

  def primary
    result = ChangeClientOrganizationPrimaryContact.new(
      agency: Current.agency,
      actor: Current.agency_user,
      client_organization_contact: @organization_contact,
      lock_version: params.expect(:lock_version)
    ).call
    notice = result.status == :noop ? "Organization contact is already primary." : "Organization primary contact updated."
    redirect_to client_organization_path(@client_organization), notice: notice
  rescue AgencyCommand::Error => error
    redirect_to client_organization_path(@client_organization), alert: error.message
  end

  private

  def require_contact_detail_view!
    require_permission!(:view_client_contact_details)
  end

  def set_organization_contact
    @organization_contact = @client_organization.organization_contacts.includes(:client_person).find(params[:organization_contact_id])
  end

  def contact_params
    params.expect(client_organization_contact: %i[client_person_id starts_on ends_on title role_label primary lock_version])
  end

  def create_contact_attributes
    contact_params
      .except(:starts_on, :ends_on, :lock_version)
      .merge(
        starts_on: Time.current.in_time_zone(Current.agency.default_timezone).to_date,
        ends_on: nil
      )
  end

  def new_person_params
    params.fetch(:client_person, {}).permit(:first_name, :middle_name, :last_name, :suffix, :preferred_name).to_h.symbolize_keys
  end

  def load_person_choices
    @person_query = params[:person_q].to_s.strip
    scope = directory_people.active
    if @person_query.present?
      normalized = SearchNormalizer.normalize(@person_query)
      tokens = SearchNormalizer.tokens(@person_query)
      prefix = person_choice_prefix_tsquery(tokens)
      matched = scope.none
      matched = matched.or(scope.where(name_search_key: normalized)) if normalized.present?
      matched = matched.or(scope.where("name_search_vector @@ to_tsquery('simple', ?)", prefix)) if prefix.present?
      scope = matched
    end

    rows = scope.order(:last_name, :first_name, :id).limit(PERSON_CHOICE_LIMIT + 1).to_a
    @person_choices_truncated = rows.size > PERSON_CHOICE_LIMIT
    @person_choices = rows.first(PERSON_CHOICE_LIMIT)

    selected_id = params.dig(:client_organization_contact, :client_person_id).presence ||
      @organization_contact&.client_person_id.presence
    return if selected_id.blank? || @person_choices.any? { |person| person.id == selected_id }

    selected = directory_people.active.find_by(id: selected_id)
    @person_choices = [ selected ] + @person_choices if selected
  end

  def person_choice_prefix_tsquery(tokens)
    return if tokens.empty?

    lexemes = tokens.filter_map do |token|
      next if token.match?(/[&|!():*<>\\']/) && !token.match?(/\A[[:alnum:]\-]+\z/)

      "'#{token.gsub("'", "''")}'"
    end
    return if lexemes.empty? || lexemes.size != tokens.size

    lexemes.map { |lexeme| "#{lexeme}:*" }.join(" & ")
  end

  def prepare_new_after_error
    @organization_contact = @client_organization.organization_contacts.new(
      contact_params.except(:lock_version, :starts_on, :ends_on)
    )
    @client_person = directory_people.new(new_person_params)
    load_person_choices
  end

  def replacement_contacts
    @client_organization.organization_contacts.current.includes(:client_person).where.not(id: @organization_contact.id).primary_first
  end

  def replacement_contact
    return if params[:replacement_primary_contact_id].blank?

    @client_organization.organization_contacts.current.find(params[:replacement_primary_contact_id])
  end
end
