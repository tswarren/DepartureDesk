# frozen_string_literal: true

class DepartureBuildersController < ApplicationController
  include DepartureAccess
  include CompositionAccess

  before_action :require_composition_access!
  before_action :set_departure
  before_action :ensure_composable_departure!

  def show
    redirect_to builder_compatibility_redirect_location
  end
end
