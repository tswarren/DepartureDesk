module Directory
  class ClientProfilesController < ApplicationController
    before_action :set_party
    before_action :set_profile, only: %i[edit update deactivate reactivate assign_advisor clear_advisor]
    before_action :prepare_form, only: %i[new edit update]

    def new
    end

    def create
      CreateClientProfile.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        office: office_from_params!
      ).call
      redirect_to directory_party_roles_path(@party), notice: "Client role added."
    rescue MembershipCommand::Error => error
      redirect_to new_directory_party_client_profile_path(@party), alert: error.message
    end

    def edit
    end

    def update
      UpdateClientProfile.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        profile: @profile,
        office: office_from_params!,
        communication_preference: profile_params[:communication_preference],
        servicing_restrictions: profile_params[:servicing_restrictions],
        billing_restrictions: profile_params[:billing_restrictions],
        lock_version: profile_params[:lock_version]
      ).call
      redirect_to directory_party_roles_path(@party), notice: "Client role updated."
    rescue MembershipCommand::Error => error
      flash.now[:alert] = error.message
      @profile.assign_attributes(profile_params.except(:lock_version, :reason, :status, :responsible_office_id, :primary_advisor_membership_id))
      render :edit, status: :unprocessable_entity
    end

    def deactivate
      DeactivateClientProfile.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        profile: @profile,
        reason: profile_params[:reason],
        lock_version: profile_params[:lock_version]
      ).call
      redirect_to directory_party_roles_path(@party), notice: "Client role deactivated."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_roles_path(@party), alert: error.message
    end

    def reactivate
      ReactivateClientProfile.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        profile: @profile,
        office: office_from_params!,
        lock_version: profile_params[:lock_version]
      ).call
      redirect_to directory_party_roles_path(@party), notice: "Client role reactivated."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_roles_path(@party), alert: error.message
    end

    def assign_advisor
      AssignClientAdvisor.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        profile: @profile,
        membership: advisor_from_params!,
        lock_version: profile_params[:lock_version]
      ).call
      redirect_to edit_directory_party_client_profile_path(@party), notice: "Client advisor updated."
    rescue MembershipCommand::Error => error
      redirect_to edit_directory_party_client_profile_path(@party), alert: error.message
    end

    def clear_advisor
      ClearClientAdvisor.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        profile: @profile,
        lock_version: profile_params[:lock_version]
      ).call
      redirect_to edit_directory_party_client_profile_path(@party), notice: "Client advisor cleared."
    rescue MembershipCommand::Error => error
      redirect_to edit_directory_party_client_profile_path(@party), alert: error.message
    end

    private

    def set_party
      @party = Current.agency.parties.find(params[:party_id])
    end

    def set_profile
      @profile = @party.client_profile
      raise ActiveRecord::RecordNotFound unless @profile
    end

    def profile_params
      params.fetch(:client_profile, params).permit(
        :responsible_office_id,
        :primary_advisor_membership_id,
        :communication_preference,
        :servicing_restrictions,
        :billing_restrictions,
        :lock_version,
        :reason,
        :status
      )
    end

    def office_from_params!
      office_id = profile_params[:responsible_office_id]
      raise MembershipCommand::Error.new("Choose an active office.", code: :invalid) if office_id.blank?

      Current.agency.offices.find(office_id)
    end

    def advisor_from_params!
      membership_id = profile_params[:primary_advisor_membership_id]
      raise MembershipCommand::Error.new("Choose an active team member as advisor.", code: :invalid) if membership_id.blank?

      Current.agency.agency_memberships.find(membership_id)
    end

    def prepare_form
      @active_offices = Current.agency.offices.active.order(:name, :code, :id)
      @advisor_memberships = Current.agency.agency_memberships.active
        .joins(person_party: :party)
        .includes(person_party: :party)
        .order("parties.sort_name", "agency_memberships.id")
    end
  end
end
