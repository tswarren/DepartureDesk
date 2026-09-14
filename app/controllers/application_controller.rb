class ApplicationController < ActionController::Base
  include Authentication

  allow_browser versions: :modern
  stale_when_importmap_changes

  private

  def agency_users
    Current.agency.agency_users
  end

  def offices
    Current.agency.offices
  end
end
