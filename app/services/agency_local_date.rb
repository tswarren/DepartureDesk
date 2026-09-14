module AgencyLocalDate
  private

  def agency_today
    Time.current.in_time_zone(@agency.default_timezone).to_date
  end

  def reject_future_date!(date, field:)
    return if date.blank? || date <= agency_today

    raise AgencyCommand::Error.new("#{field.to_s.humanize} cannot be in the future.", code: :invalid)
  end
end
