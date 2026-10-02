# frozen_string_literal: true

class TransportationArrangementsController < ApplicationController
  include TransportationArrangementAccess

  before_action :require_departure_view!
  before_action :set_departure
  before_action :ensure_composable_departure!
  before_action :set_transportation_arrangement
  before_action :set_transportation_version
  before_action :assign_transportation_workspace

  def show
    assign_transportation_agreement
    @idempotency_key = SecureRandom.uuid
  end
end
