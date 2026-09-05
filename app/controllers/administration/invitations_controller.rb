module Administration
  class InvitationsController < BaseController
    before_action :set_offices

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
        preferred_name: @invitation.preferred_name,
        office_ids: @invitation.office_ids,
        default_office_id: @invitation.default_office_id
      ).call

      if result.status == :already_member
        redirect_to administration_team_members_path, alert: result.message
      else
        redirect_to administration_team_members_path, notice: MembershipCommand::ELIGIBLE_INVITE_NOTICE
      end
    end

    private

    def set_offices
      @offices = Current.agency.offices.active.order(:name)
    end

    def invitation_params
      form = params.require(:invitation_form)

      {
        email_address: form[:email_address],
        role: form[:role],
        first_name: form[:first_name],
        last_name: form[:last_name],
        preferred_name: form[:preferred_name],
        office_ids: Array(form[:office_ids]).compact_blank,
        default_office_id: form[:default_office_id]
      }
    end
  end
end
