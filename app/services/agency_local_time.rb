# Date-only facts resolve to the end of their date in a zone: 11:59 p.m.
# local (SET-10). Used by deadlines and by future-dated capacity
# adjustments (D-88), so both resolve to the same instant.
module AgencyLocalTime
  module_function

  def end_of_date(date, time_zone)
    ActiveSupport::TimeZone[time_zone].local(date.year, date.month, date.day, 23, 59)
  end
end
