module Administration
  class OfficesController < BaseController
    before_action :set_office, only: %i[show edit update deactivate reactivate]

    def index
      @offices = offices.order(:name)
    end

    def show
    end

    def new
      @office = offices.new
    end

    def create
      result = CreateOffice.new(
        agency: Current.agency,
        actor: Current.agency_user,
        name: office_params[:name],
        code: office_params[:code],
        default_timezone: office_params[:default_timezone]
      ).call
      redirect_to administration_office_path(result.record), notice: "Office created."
    rescue AgencyCommand::Error => error
      @office = offices.new(office_params)
      flash.now[:alert] = error.message
      render :new, status: :unprocessable_entity
    end

    def edit
    end

    def update
      UpdateOffice.new(
        office: @office,
        actor: Current.agency_user,
        name: office_params[:name],
        default_timezone: office_params[:default_timezone],
        lock_version: office_params[:lock_version]
      ).call
      redirect_to administration_office_path(@office), notice: "Office updated."
    rescue AgencyCommand::Error => error
      flash.now[:alert] = error.message
      render :edit, status: :unprocessable_entity
    end

    def deactivate
      ChangeOfficeStatus.new(office: @office, actor: Current.agency_user, status: "inactive", lock_version: params[:lock_version]).call
      redirect_to administration_office_path(@office), notice: "Office deactivated."
    rescue AgencyCommand::Error => error
      redirect_to administration_office_path(@office), alert: error.message
    end

    def reactivate
      ChangeOfficeStatus.new(office: @office, actor: Current.agency_user, status: "active", lock_version: params[:lock_version]).call
      redirect_to administration_office_path(@office), notice: "Office reactivated."
    rescue AgencyCommand::Error => error
      redirect_to administration_office_path(@office), alert: error.message
    end

    private

    def set_office
      @office = offices.find(params[:id])
    end

    def office_params
      params.require(:office).permit(:name, :code, :default_timezone, :lock_version)
    end
  end
end
