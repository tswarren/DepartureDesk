class EffectiveCapacityPoolsController < ApplicationController
  include EffectiveCapacityAccess

  before_action :require_departure_view!
  before_action :set_effective_capacity_context

  def show
    load_effective_capacity
  end
end
