module Directory
  class PartyRelationshipsController < ApplicationController
    before_action :set_party
    before_action :set_relationship, only: %i[close correct void]

    def new
      @relationship_kind = params[:relationship_kind].to_s.presence
    end

    def create
      origin, related = oriented_parties
      CreatePartyRelationship.new(
        agency: Current.agency,
        actor: Current.user,
        origin_party: origin,
        related_party: related,
        relationship_kind: relationship_params[:relationship_kind],
        relationship_label: relationship_params[:relationship_label],
        title: relationship_params[:title],
        notes: relationship_params[:notes],
        effective_from: relationship_params[:effective_from],
        effective_until: DirectoryDate.exclusive_until(relationship_params[:inclusive_end_on])
      ).call
      redirect_to directory_party_relationships_path(@party), notice: "Relationship added."
    rescue MembershipCommand::Error => error
      @relationship_kind = relationship_params[:relationship_kind]
      flash.now[:alert] = error.message
      render :new, status: error.code == :conflict ? :conflict : :unprocessable_entity
    end

    def close
      EndPartyRelationship.new(
        agency: Current.agency,
        actor: Current.user,
        relationship: @relationship,
        inclusive_end_on: relationship_params[:inclusive_end_on],
        reason: relationship_params[:reason]
      ).call
      redirect_to directory_party_relationships_path(@party), notice: "Relationship ended."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_relationships_path(@party), alert: error.message
    end

    def correct
      CorrectPartyRelationship.new(
        agency: Current.agency,
        actor: Current.user,
        relationship: @relationship,
        reason: relationship_params[:reason],
        relationship_label: relationship_params[:relationship_label],
        title: relationship_params[:title],
        notes: relationship_params[:notes],
        effective_from: relationship_params[:effective_from],
        effective_until: DirectoryDate.exclusive_until(relationship_params[:inclusive_end_on])
      ).call
      redirect_to directory_party_relationships_path(@party), notice: "Relationship corrected."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_relationships_path(@party), alert: error.message
    end

    def void
      VoidPartyRelationship.new(
        agency: Current.agency,
        actor: Current.user,
        relationship: @relationship,
        reason: relationship_params[:reason]
      ).call
      redirect_to directory_party_relationships_path(@party), notice: "Relationship voided."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_relationships_path(@party), alert: error.message
    end

    private

    def set_party
      @party = Current.agency.parties.find(params[:party_id])
    end

    def set_relationship
      @relationship = PartyRelationship.involving(@party).find(params[:id])
    end

    def relationship_params
      params.fetch(:party_relationship, params).permit(
        :relationship_kind, :relationship_label, :other_party_id, :title, :notes,
        :effective_from, :inclusive_end_on, :reason
      )
    end

    def oriented_parties
      kind = relationship_params[:relationship_kind].to_s
      other = Current.agency.parties.find(relationship_params[:other_party_id])
      origin_kind, related_kind = PartyRelationship.pair_for(kind)
      if @party.party_kind == origin_kind && other.party_kind == related_kind
        [ @party, other ]
      elsif @party.party_kind == related_kind && other.party_kind == origin_kind
        [ other, @party ]
      else
        [ @party, other ]
      end
    rescue KeyError
      [ @party, @party ]
    end
  end
end
