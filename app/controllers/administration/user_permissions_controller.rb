module Administration
  class UserPermissionsController < BaseController
    before_action :set_agency_user

    def edit
      return if @agency_user.staff?

      redirect_to administration_agency_user_path(@agency_user), alert: "Only staff users hold individual permissions."
    end

    def update
      UpdateUserPermissions.new(
        agency_user: @agency_user,
        actor: Current.agency_user,
        permissions: Array(params.dig(:agency_user, :permissions)),
        lock_version: params.dig(:agency_user, :lock_version)
      ).call
      redirect_to administration_agency_user_path(@agency_user), notice: "Permissions updated."
    rescue AgencyCommand::Error => error
      return redirect_to(root_path, alert: error.message) if error.code == :unauthorized

      @submitted_permissions = Array(params.dig(:agency_user, :permissions))
      @agency_user.errors.add(:permissions, error.message)
      render :edit, status: :unprocessable_entity
    end

    private

    def set_agency_user
      @agency_user = Current.agency.agency_users.find(params[:agency_user_id])
    end
  end
end
