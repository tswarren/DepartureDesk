module Administration
  class TeamMembersController < BaseController
    before_action :set_membership, except: :index

    def index
      @memberships = Current.agency.agency_memberships.includes(:user).order(:created_at)
    end

    def show
    end

    def role
      ChangeMembershipRole.new(
        agency: Current.agency,
        actor: Current.user,
        membership: @membership,
        role: params.require(:role)
      ).call
      redirect_to administration_team_member_path(@membership), notice: "Role updated."
    rescue MembershipCommand::Error => error
      redirect_to administration_team_member_path(@membership), alert: error.message
    end

    def suspend
      SuspendMembership.new(
        agency: Current.agency,
        actor: Current.user,
        membership: @membership
      ).call
      redirect_to administration_team_member_path(@membership), notice: "Access suspended."
    rescue MembershipCommand::Error => error
      redirect_to administration_team_member_path(@membership), alert: error.message
    end

    def reactivate
      ReactivateMembership.new(
        agency: Current.agency,
        actor: Current.user,
        membership: @membership
      ).call
      redirect_to administration_team_member_path(@membership), notice: "Access reactivated."
    rescue MembershipCommand::Error => error
      redirect_to administration_team_member_path(@membership), alert: error.message
    end

    def replace_invitation
      ReplaceInvitation.new(
        agency: Current.agency,
        actor: Current.user,
        membership: @membership
      ).call
      redirect_to administration_team_member_path(@membership),
        notice: MembershipCommand::ELIGIBLE_INVITE_NOTICE
    rescue MembershipCommand::Error => error
      redirect_to administration_team_member_path(@membership), alert: error.message
    end

    def revoke_invitation
      RevokeInvitation.new(
        agency: Current.agency,
        actor: Current.user,
        membership: @membership
      ).call
      redirect_to administration_team_member_path(@membership), notice: "Invitation revoked."
    rescue MembershipCommand::Error => error
      redirect_to administration_team_member_path(@membership), alert: error.message
    end

    private

    def set_membership
      @membership = Current.agency.agency_memberships.find(params[:id])
    end
  end
end
