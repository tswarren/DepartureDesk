module Administration
  class AgencyUsersController < BaseController
    before_action :set_agency_user, only: %i[show edit update suspend reactivate close replace_invitation revoke_invitation]

    def index
      @agency_users = agency_users.order(:last_name, :first_name)
    end

    def show
    end

    def new
      @agency_user = agency_users.new(access_role: "staff")
      @offices = offices.order(:name)
    end

    def create
      office = offices.find_by(id: agency_user_params[:default_office_id])
      result = InviteAgencyUser.new(
        agency: Current.agency,
        actor: Current.agency_user,
        email_address: agency_user_params[:email_address],
        first_name: agency_user_params[:first_name],
        last_name: agency_user_params[:last_name],
        access_role: agency_user_params[:access_role],
        default_office: office,
        relationship: agency_user_params[:relationship]
      ).call
      redirect_to administration_agency_user_path(result.record), notice: "Invitation sent."
    rescue AgencyCommand::Error => error
      @agency_user = agency_users.new(agency_user_params)
      @offices = offices.order(:name)
      flash.now[:alert] = error.message
      render :new, status: :unprocessable_entity
    end

    def edit
      @offices = offices.order(:name)
    end

    def update
      UpdateAgencyUser.new(
        agency_user: @agency_user,
        actor: Current.agency_user,
        access_role: agency_user_params[:access_role],
        relationship: agency_user_params[:relationship],
        default_office_id: agency_user_params[:default_office_id],
        lock_version: agency_user_params[:lock_version]
      ).call
      redirect_to administration_agency_user_path(@agency_user), notice: "User updated."
    rescue AgencyCommand::Error => error
      raise ActiveRecord::RecordNotFound if error.code == :not_found

      @offices = offices.order(:name)
      flash.now[:alert] = error.message
      render :edit, status: :unprocessable_entity
    end

    def suspend
      change_status!("suspended", "User suspended.")
    end

    def reactivate
      change_status!("active", "User reactivated.")
    end

    def close
      change_status!("closed", "User closed.")
    end

    def replace_invitation
      ReplaceAgencyUserInvitation.new(agency_user: @agency_user, actor: Current.agency_user).call
      redirect_to administration_agency_user_path(@agency_user), notice: "Invitation replaced."
    rescue AgencyCommand::Error => error
      redirect_to administration_agency_user_path(@agency_user), alert: error.message
    end

    def revoke_invitation
      RevokeAgencyUserInvitation.new(agency_user: @agency_user, actor: Current.agency_user).call
      redirect_to administration_agency_user_path(@agency_user), notice: "Invitation revoked."
    rescue AgencyCommand::Error => error
      redirect_to administration_agency_user_path(@agency_user), alert: error.message
    end

    private

    def change_status!(status, notice)
      ChangeAgencyUserAccess.new(
        agency_user: @agency_user,
        actor: Current.agency_user,
        status: status,
        lock_version: params[:lock_version]
      ).call
      redirect_to administration_agency_user_path(@agency_user), notice: notice
    rescue AgencyCommand::Error => error
      redirect_to administration_agency_user_path(@agency_user), alert: error.message
    end

    def set_agency_user
      @agency_user = agency_users.find(params[:id])
    end

    def agency_user_params
      params.require(:agency_user).permit(:email_address, :first_name, :last_name, :access_role, :default_office_id, :relationship, :lock_version)
    end
  end
end
