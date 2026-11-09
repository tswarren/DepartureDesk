# The package and client terms screens (S-20, S-21): viewing is baseline
# (staff see client prices, ACC-30); editing needs Departure management.
# A command error that starts with a field's label is shown on that field.
module PackageAccess
  extend ActiveSupport::Concern
  include DepartureAccess

  included { helper_method :manage_package? }

  private

  def require_departure_view!
    require_permission!(:view_departures)
  end

  def require_package_management!
    require_permission!(:manage_departures)
  end

  def manage_package? = Current.agency_user.permitted?(:manage_departures) && !@departure.departed?

  def set_offering
    @offering = @departure.offerings.find(params[:offering_id] || params[:id])
  end

  def set_terms_version
    @terms_version = @departure.current_client_terms or raise ActiveRecord::RecordNotFound
  end

  def form_params(scope, fields)
    params.require(scope).permit(*fields).to_h
  end
end
