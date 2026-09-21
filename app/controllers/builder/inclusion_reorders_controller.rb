# frozen_string_literal: true

module Builder
  class InclusionReordersController < ApplicationController
    include DepartureAccess

    before_action :require_builder_access!
    before_action :set_departure
    before_action :set_package

    def show
      @version = @package.editable_draft_version
      raise ActiveRecord::RecordNotFound if @version.nil?

      @inclusions = @version.inclusions.includes(:service_offer).order(:position, :id).to_a
    end

    def update
      version = @package.editable_draft_version
      raise ActiveRecord::RecordNotFound if version.nil?

      ReorderPackageInclusions.new(
        agency: Current.agency,
        actor: Current.agency_user,
        package: @package,
        ordered_ids: Array(params[:inclusion_ids]),
        version_lock_version: params[:version_lock_version]
      ).call
      redirect_to departure_builder_path(@departure, package_id: @package.id), notice: "Itinerary order saved."
    rescue AgencyCommand::Error => error
      raise ActiveRecord::RecordNotFound if error.code == :not_found

      @version = @package.editable_draft_version
      @inclusions = @version.inclusions.includes(:service_offer).order(:position, :id).to_a
      flash.now[:alert] = error.message
      render :show, status: :unprocessable_entity
    end

    private

    def require_builder_access!
      raise ActiveRecord::RecordNotFound unless Current.agency_user&.permitted?(:manage_departures)
    end

    def set_package
      @package = @departure.packages.find(params[:package_id])
    end
  end
end
