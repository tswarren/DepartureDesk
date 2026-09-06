class DirectoryDate
  def self.today(agency)
    Time.current.in_time_zone(agency.default_timezone).to_date
  end

  def self.exclusive_until(inclusive_end)
    return if inclusive_end.blank?

    inclusive_end.to_date.next_day
  end

  def self.inclusive_end(exclusive_until)
    return if exclusive_until.blank?

    exclusive_until.to_date.prev_day
  end
end
