class OfficeDate
  def self.today(office)
    Time.current.in_time_zone(office.default_timezone).to_date
  end
end
