# S-21: the Departure's client terms. Starting them copies the agency
# wording, or another Departure's terms (D-76); the update edits the
# Departure wording and whether it overrides the agency tiers.
class DepartureClientTermsController < ApplicationController
  include PackageAccess

  before_action :require_departure_view!
  before_action :require_package_management!, except: :show
  before_action :set_departure
  before_action :set_terms_version, only: :update

  def show
    @terms_version = @departure.current_client_terms
  end

  def create
    result = StartClientTerms.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, source_departure_id: params[:source_departure_id]).call
    redirect_to departure_client_terms_path(@departure), notice: result.status == :noop ? "These terms already exist." : "Client terms saved."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to departure_client_terms_path(@departure), alert: error.message
  end

  def update
    UpdateClientTerms.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, terms_version: @terms_version,
      attributes: params.require(:client_terms_version).permit(:departure_wording, :overrides_cancellation_tiers).to_h,
      lock_version: params.dig(:client_terms_version, :lock_version)).call
    redirect_to departure_client_terms_path(@departure), notice: "Client terms updated."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to departure_client_terms_path(@departure), alert: error.message
  end
end
