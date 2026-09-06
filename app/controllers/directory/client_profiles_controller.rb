module Directory
  class ClientProfilesController < ApplicationController
    before_action :set_party
    before_action :set_profile, only: %i[update deactivate reactivate]

    def create
      CreateClientProfile.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        office: office_from_params!
      ).call
      redirect_to directory_party_path(@party), notice: "Client role added."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_path(@party), alert: error.message
    end

    def update
      UpdateClientProfile.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        profile: @profile,
        office: office_from_params!,
        lock_version: profile_params[:lock_version]
      ).call
      redirect_to directory_party_path(@party), notice: "Client role updated."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_path(@party), alert: error.message
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
      redirect_to directory_party_path(@party), notice: "Client role deactivated."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_path(@party), alert: error.message
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
      redirect_to directory_party_path(@party), notice: "Client role reactivated."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_path(@party), alert: error.message
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
      params.fetch(:client_profile, params).permit(:responsible_office_id, :lock_version, :reason, :status)
    end

    def office_from_params!
      office_id = profile_params[:responsible_office_id]
      raise MembershipCommand::Error.new("Choose an active office.", code: :invalid) if office_id.blank?

      Current.agency.offices.find(office_id)
    end
  end
end
