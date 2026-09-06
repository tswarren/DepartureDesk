module Directory
  class AlternateNamesController < ApplicationController
    before_action :set_party

    def create
      AddPartyAlternateName.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        name: alternate_params[:name],
        name_kind: alternate_params[:name_kind]
      ).call
      redirect_to directory_party_path(@party), notice: "Alternate name added."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_path(@party), alert: error.message
    end

    def update
      alternate = @party.alternate_names.find(params[:id])
      UpdatePartyAlternateName.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        alternate_name: alternate,
        name: alternate_params[:name],
        name_kind: alternate_params[:name_kind]
      ).call
      redirect_to directory_party_path(@party), notice: "Alternate name updated."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_path(@party), alert: error.message
    end

    def destroy
      alternate = @party.alternate_names.find(params[:id])
      RemovePartyAlternateName.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        alternate_name: alternate
      ).call
      redirect_to directory_party_path(@party), notice: "Alternate name removed."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_path(@party), alert: error.message
    end

    private

    def set_party
      @party = Current.agency.parties.find(params[:party_id])
    end

    def alternate_params
      params.require(:party_alternate_name).permit(:name, :name_kind)
    end
  end
end
