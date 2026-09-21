# frozen_string_literal: true

class PackageTermsController < ApplicationController
  include DepartureAccess

  before_action :require_unpublished_package_access!
  before_action :set_departure
  before_action :set_package

  def update
    UpdatePackageClientTerms.new(
      agency: Current.agency, actor: Current.agency_user, package: @package,
      attributes: terms_params, version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_package_path(@departure, @package), notice: "Package terms saved."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    flash[:alert] = error.message
    redirect_to departure_package_path(@departure, @package)
  end

  private

  def require_unpublished_package_access!
    raise ActiveRecord::RecordNotFound unless Current.agency_user&.permitted?(:manage_departures)
  end

  def set_package
    @package = @departure.packages.find(params[:package_id])
  end

  def terms_params
    params.fetch(:terms, {}).permit(
      :sales_starts_on, :sales_ends_on, :sales_cap_quantity, :sales_cap_basis,
      payment_lines: [ :due_kind, :due_on, :milestone_name, :amount_kind, :amount_minor_units, :percent_rate ],
      cancellation_tiers: [ :threshold_kind, :threshold_on, :days_before, :consequence_kind, :amount_minor_units, :percent_rate, :summary ],
      stated_conditions: [ :condition_kind, :body ],
      resolutions: [ :kind, :service_offer_version_id, :governing_side, :reason ]
    )
  end
end
