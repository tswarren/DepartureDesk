# frozen_string_literal: true

class DepartureBuildersController < ApplicationController
  include DepartureAccess

  before_action :require_builder_access!
  before_action :set_departure

  def show
    assign_builder
  end

  private

  def require_builder_access!
    raise ActiveRecord::RecordNotFound unless Current.agency_user&.permitted?(:manage_departures)
  end

  def assign_builder
    @builder = DepartureBuilderWorkspace.new(
      agency: Current.agency,
      departure: @departure,
      package_id: params[:package_id],
      work_on: params[:work_on],
      require_explicit_package: true
    )
    @builder_readiness = @builder.readiness
    @builder_recommendation = @builder.recommendation
    if @builder.selected_package
      @common_scenarios = DeriveCommonPackageScenarios.new(
        agency: Current.agency,
        package: @builder.selected_package
      ).call
    end
  end
end
