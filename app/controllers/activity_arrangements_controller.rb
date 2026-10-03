# frozen_string_literal: true

class ActivityArrangementsController < ApplicationController
  include ActivityArrangementAccess

  before_action :require_departure_view!
  before_action :set_departure
  before_action :ensure_composable_departure!
  before_action :set_activity_arrangement
  before_action :set_activity_version
  before_action :assign_activity_workspace

  def show
    assign_activity_agreement
    @idempotency_key = SecureRandom.uuid
  end
end
