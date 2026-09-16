class DepartureActivationsController < ApplicationController
  include DepartureAccess

  before_action :require_departure_management!
  before_action :set_departure

  def show
    @activation_blockers = @departure.activation_blockers
  end
end
