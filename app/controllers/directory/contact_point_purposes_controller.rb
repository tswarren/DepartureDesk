module Directory
  class ContactPointPurposesController < ApplicationController
    before_action :set_party
    before_action :set_contact_point
    before_action :set_assignment, only: %i[close correct]

    def new
      @assignment = @contact_point.purpose_assignments.new(
        purpose: "general",
        priority: 1,
        effective_from: DirectoryDate.today(Current.agency)
      )
    end

    def create
      inclusive_until = purpose_params[:inclusive_end_on]
      AssignContactPointPurpose.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        contact_point: @contact_point,
        purpose: purpose_params[:purpose],
        priority: purpose_params[:priority],
        effective_from: purpose_params[:effective_from],
        effective_until: DirectoryDate.exclusive_until(inclusive_until)
      ).call
      redirect_to directory_party_contact_information_path(@party), notice: "Contact purpose assigned."
    rescue MembershipCommand::Error => error
      @assignment = @contact_point.purpose_assignments.new(purpose_params.slice(:purpose, :priority, :effective_from))
      flash.now[:alert] = error.message
      render :new, status: error.code == :conflict ? :conflict : :unprocessable_entity
    end

    def close
      EndContactPointPurpose.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        contact_point: @contact_point,
        assignment: @assignment,
        inclusive_end_on: purpose_params[:inclusive_end_on],
        reason: purpose_params[:reason]
      ).call
      redirect_to directory_party_contact_information_path(@party), notice: "Contact purpose ended."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_contact_information_path(@party), alert: error.message
    end

    def correct
      CorrectContactPointPurpose.new(
        agency: Current.agency,
        actor: Current.user,
        party: @party,
        contact_point: @contact_point,
        assignment: @assignment,
        reason: purpose_params[:reason],
        purpose: purpose_params[:purpose],
        priority: purpose_params[:priority],
        effective_from: purpose_params[:effective_from],
        effective_until: DirectoryDate.exclusive_until(purpose_params[:inclusive_end_on])
      ).call
      redirect_to directory_party_contact_information_path(@party), notice: "Contact purpose corrected."
    rescue MembershipCommand::Error => error
      redirect_to directory_party_contact_information_path(@party), alert: error.message
    end

    private

    def set_party
      @party = Current.agency.parties.find(params[:party_id])
    end

    def set_contact_point
      @contact_point = @party.contact_points.find(params[:contact_point_id])
    end

    def set_assignment
      @assignment = @contact_point.purpose_assignments.find(params[:id])
    end

    def purpose_params
      params.fetch(:contact_point_purpose_assignment, params).permit(
        :purpose, :priority, :effective_from, :inclusive_end_on, :reason
      )
    end
  end
end
