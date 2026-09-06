module Directory
  class RelationshipPurposesController < ApplicationController
    before_action :set_party
    before_action :set_relationship
    before_action :set_assignment, only: %i[close correct]

    def new
      @assignment = @relationship.purpose_assignments.new(
        purpose: "general",
        priority: 1,
        effective_from: DirectoryDate.today(Current.agency)
      )
    end

    def create
      AssignRelationshipPurpose.new(
        agency: Current.agency,
        actor: Current.user,
        relationship: @relationship,
        purpose: purpose_params[:purpose],
        priority: purpose_params[:priority],
        effective_from: purpose_params[:effective_from],
        effective_until: DirectoryDate.exclusive_until(purpose_params[:inclusive_end_on]),
        replace_primary: purpose_params[:replace_primary] == "1"
      ).call
      redirect_to directory_party_relationships_path(@party), notice: "Relationship purpose assigned."
    rescue MembershipCommand::Error => error
      @assignment = @relationship.purpose_assignments.new(purpose_params.slice(:purpose, :priority, :effective_from))
      flash.now[:alert] = error.message
      render :new, status: error.code == :conflict ? :conflict : :unprocessable_entity
    end

    def close
      EndRelationshipPurpose.new(
        agency: Current.agency,
        actor: Current.user,
        relationship: @relationship,
        assignment: @assignment,
        inclusive_end_on: purpose_params[:inclusive_end_on],
        reason: purpose_params[:reason]
      ).call
      redirect_to directory_party_relationships_path(@party), notice: "Relationship purpose ended."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_relationships_path(@party), alert: error.message
    end

    def correct
      CorrectRelationshipPurpose.new(
        agency: Current.agency,
        actor: Current.user,
        relationship: @relationship,
        assignment: @assignment,
        reason: purpose_params[:reason],
        purpose: purpose_params[:purpose],
        priority: purpose_params[:priority],
        effective_from: purpose_params[:effective_from],
        effective_until: DirectoryDate.exclusive_until(purpose_params[:inclusive_end_on])
      ).call
      redirect_to directory_party_relationships_path(@party), notice: "Relationship purpose corrected."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_relationships_path(@party), alert: error.message
    end

    private

    def set_party
      @party = Current.agency.parties.find(params[:party_id])
    end

    def set_relationship
      @relationship = PartyRelationship.involving(@party).find(params[:party_relationship_id])
    end

    def set_assignment
      @assignment = @relationship.purpose_assignments.find(params[:id])
    end

    def purpose_params
      params.fetch(:relationship_purpose_assignment, params).permit(
        :purpose, :priority, :effective_from, :inclusive_end_on, :reason, :replace_primary
      )
    end
  end
end
