# Starts the rate grid from a preset pattern, or switches to custom bands (S-14).
class SupplierRatePatternsController < ApplicationController
  include SupplierRateAccess

  def update
    run_rate_command("pattern", ->(result) { "Pattern set: #{SupplierRatePatterns::LABELS.fetch(result.record.rate_pattern)}." }) do
      SetSupplierRatePattern.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement,
        pattern: params[:pattern]).call
    end
  end
end
