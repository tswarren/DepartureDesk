module DepartureAccess
  extend ActiveSupport::Concern

  private

  def require_departure_view!
    require_permission!(:view_departures)
  end

  def require_departure_management!
    require_permission!(:manage_departures)
  end

  def departures_scope
    Current.agency.departures
  end

  def set_departure
    @departure = departures_scope.find(params[:departure_id] || params[:id])
  end

  def rescue_departure_error(error, template)
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    if @departure && error.code == :invalid
      @departure.errors.add(departure_error_attribute(error.message), error.message)
    else
      flash.now[:alert] = error.message
    end
    render template, status: :unprocessable_entity
  end

  def departure_error_attribute(message)
    case message
    when /name/i then :name
    when /description/i then :description
    when /start date/i then :starts_on
    when /end date/i then :ends_on
    when /time zone|timezone/i then :time_zone
    when /currency/i then :operating_currency
    when /office/i then :responsible_office_id
    when /agency user/i then :responsible_agency_user_id
    when /reason/i then :reason
    else :base
    end
  end

  def departure_params
    params.fetch(:departure, {}).permit(
      :name, :description, :target_timing_text, :starts_on, :ends_on, :time_zone, :operating_currency,
      :responsible_office_id, :responsible_agency_user_id, :lock_version, :reason, :timing_mode
    )
  end

  def assign_submitted_departure_fields
    attrs = departure_params.except(:lock_version, :reason, :responsible_office_id, :responsible_agency_user_id, :timing_mode)
    @departure.assign_attributes(attrs)
    @departure.responsible_office_id = departure_params[:responsible_office_id]
    @departure.responsible_agency_user_id = departure_params[:responsible_agency_user_id]
  end
end
