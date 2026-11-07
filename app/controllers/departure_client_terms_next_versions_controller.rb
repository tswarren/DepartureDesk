# Starts the next version of locked client terms (BKG-28, D-76).
class DepartureClientTermsNextVersionsController < ApplicationController
  include PackageAccess

  before_action :require_departure_view!
  before_action :require_package_management!
  before_action :set_departure

  def create
    result = StartNextClientTermsVersion.new(agency: Current.agency, actor: Current.agency_user, departure: @departure).call
    redirect_to departure_client_terms_path(@departure), notice: "Version #{result.record.version_number} started. New bookings take it."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to departure_client_terms_path(@departure), alert: error.message
  end
end
