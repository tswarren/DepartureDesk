module Administration
  class OfficesController < BaseController
    helper Administration::AgenciesHelper
    before_action :set_office, only: %i[show edit update deactivate reactivate]

    def index
      @offices = Current.agency.offices.includes(office_assignments: :agency_membership).order(:name)
    end

    def show
    end

    def new
      @office = Current.agency.offices.new(default_timezone: Current.agency.default_timezone)
    end

    def create
      result = CreateOffice.new(
        agency: Current.agency,
        actor: Current.user,
        name: office_params[:name],
        code: office_params[:code],
        default_timezone: office_params[:default_timezone]
      ).call
      redirect_to administration_office_path(result.office), notice: "Office created."
    rescue MembershipCommand::Error => error
      @office = Current.agency.offices.new(office_params)
      @office.validate
      @office.errors.add(:code, "is already used") if error.code == :conflict && @office.errors[:code].empty?
      flash.now[:alert] = error.message
      render :new, status: :unprocessable_entity
    end

    def edit
    end

    def update
      UpdateOffice.new(
        agency: Current.agency,
        actor: Current.user,
        office: @office,
        name: office_params[:name],
        default_timezone: office_params[:default_timezone],
        lock_version: office_params[:lock_version]
      ).call
      redirect_to administration_office_path(@office), notice: "Office updated."
    rescue MembershipCommand::Error => error
      @office.assign_attributes(office_params.except(:code, :lock_version))
      @office.validate
      flash.now[:alert] = error.message
      render :edit, status: error.code == :conflict ? :conflict : :unprocessable_entity
    end

    def deactivate
      ChangeOfficeStatus.new(
        agency: Current.agency,
        actor: Current.user,
        office: @office,
        to: "inactive",
        reason: params.require(:reason)
      ).call
      redirect_to administration_office_path(@office), notice: "Office deactivated."
    rescue MembershipCommand::Error => error
      redirect_to administration_office_path(@office), alert: error.message
    end

    def reactivate
      ChangeOfficeStatus.new(
        agency: Current.agency,
        actor: Current.user,
        office: @office,
        to: "active",
        reason: params.require(:reason)
      ).call
      redirect_to administration_office_path(@office), notice: "Office reactivated."
    rescue MembershipCommand::Error => error
      redirect_to administration_office_path(@office), alert: error.message
    end

    private

    def set_office
      @office = Current.agency.offices.find(params[:id])
    end

    def office_params
      params.require(:office).permit(:name, :code, :default_timezone, :lock_version)
    end
  end
end
