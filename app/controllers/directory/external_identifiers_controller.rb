module Directory
  class ExternalIdentifiersController < ApplicationController
    before_action :set_party
    before_action :set_identifier, only: %i[deactivate reactivate]

    def create
      AddExternalIdentifier.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        identifier_type: identifier_params[:identifier_type],
        original_value: identifier_params[:original_value],
        issuer: identifier_params[:issuer]
      ).call
      redirect_to directory_party_identifiers_path(@party), notice: "Identifier added."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_identifiers_path(@party), alert: error.message
    end

    def deactivate
      DeactivateExternalIdentifier.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        identifier: @identifier,
        reason: identifier_params[:reason]
      ).call
      redirect_to directory_party_identifiers_path(@party), notice: "Identifier deactivated."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_identifiers_path(@party), alert: error.message
    end

    def reactivate
      ReactivateExternalIdentifier.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        identifier: @identifier
      ).call
      redirect_to directory_party_identifiers_path(@party), notice: "Identifier reactivated."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_identifiers_path(@party), alert: error.message
    end

    private

    def set_party
      @party = Current.agency.parties.find(params[:party_id])
    end

    def set_identifier
      @identifier = @party.directory_external_identifiers.find(params[:id])
    end

    def identifier_params
      params.fetch(:external_identifier, params).permit(:identifier_type, :original_value, :issuer, :reason)
    end
  end
end
