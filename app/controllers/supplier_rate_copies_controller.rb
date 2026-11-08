# Copies another arrangement's rates onto this draft (S-14).
class SupplierRateCopiesController < ApplicationController
  include SupplierRateAccess

  def create
    notice = lambda do |result|
      copy = result.record
      "Copied #{copy[:copied]} rates from #{copy[:source].arrangement_reference}#{"; #{copy[:skipped]} had no matching group" if copy[:skipped].positive?}. " \
        "Check them against the supplier's current rate sheet before confirming."
    end
    run_rate_command("rates", notice) do
      CopySupplierRates.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement,
        source_id: params[:source_id]).call
    end
  end
end
