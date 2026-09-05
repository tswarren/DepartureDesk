class CurrentOfficesController < ApplicationController
  def edit
    @offices = Current.agency_membership.accessible_offices.order(:name)
  end

  def update
    office = Current.agency_membership.accessible_offices.find(params.require(:office_id))
    SelectCurrentOffice.new(session: Current.session, office: office).call
    redirect_to after_office_selection_url, notice: "Current office updated."
  rescue ActiveRecord::RecordNotFound
    raise
  rescue SelectCurrentOffice::Error => error
    redirect_to edit_current_office_path, alert: error.message
  end

  private

  def after_office_selection_url
    location = params[:return_to].to_s
    return location if location.start_with?("/") && !location.start_with?("//")

    root_url
  end
end
