# frozen_string_literal: true

class PackageInclusionsController < ApplicationController
  include DepartureAccess

  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_package

  def reorder
    version = @package.editable_draft_version
    raise ActiveRecord::RecordNotFound if version.nil?

    ReorderPackageInclusions.new(
      agency: Current.agency,
      actor: Current.agency_user,
      package: @package,
      ordered_ids: Array(params[:inclusion_ids]),
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_path(@departure), notice: "Itinerary order saved."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    flash[:alert] = error.message
    redirect_to departure_path(@departure)
  end

  private

  def set_package
    @package = @departure.packages.find(params[:package_id])
  end
end
