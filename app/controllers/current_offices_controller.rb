class CurrentOfficesController < ApplicationController
  def edit
    @offices = Current.agency.offices.active.order(:name)
  end

  def update
    office = Current.agency.offices.find_by(id: params[:office_id])
    SelectCurrentOffice.new(session: Current.session, office: office).call
    redirect_to root_path, notice: "Current office updated."
  rescue AgencyCommand::Error => error
    status = error.code == :not_found ? :not_found : :unprocessable_entity
    redirect_to edit_current_office_path, alert: error.message, status: status
  end
end
