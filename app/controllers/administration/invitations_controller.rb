module Administration
  class InvitationsController < BaseController
    def new
      @invitation = InvitationForm.new
    end

    def create
      @invitation = InvitationForm.new(invitation_params)
      unless @invitation.valid?
        render :new, status: :unprocessable_entity
        return
      end

      result = InviteTeamMember.new(
        agency: Current.agency,
        actor: Current.user,
        email: @invitation.email_address,
        role: @invitation.role,
        first_name: @invitation.first_name,
        last_name: @invitation.last_name,
        preferred_name: @invitation.preferred_name
      ).call

      if result.status == :already_member
        redirect_to administration_team_members_path, alert: result.message
      else
        redirect_to administration_team_members_path, notice: MembershipCommand::ELIGIBLE_INVITE_NOTICE
      end
    end

    private

    def invitation_params
      params.require(:invitation_form).permit(
        :email_address,
        :role,
        :first_name,
        :last_name,
        :preferred_name
      )
    end
  end
end
