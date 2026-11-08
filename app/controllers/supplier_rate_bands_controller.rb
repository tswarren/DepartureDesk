# Adds or removes a band of a custom rate pattern (S-14).
class SupplierRateBandsController < ApplicationController
  include SupplierRateAccess

  def create
    run_rate_command("pattern", "Band added.") do
      SaveSupplierRateBand.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement,
        attributes: params.fetch(:rate_band, {}).permit(:label, :traveler_type_id, positions: []).to_h).call
    end
  end

  def destroy
    band = @arrangement.rate_bands.find(params[:id])
    run_rate_command("pattern", "Band removed, with its fares.") do
      RemoveSupplierRateBand.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement, band:).call
    end
  end
end
