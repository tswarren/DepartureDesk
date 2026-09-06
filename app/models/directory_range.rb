class DirectoryRange
  def self.overlap?(from_a, until_a, from_b, until_b)
    start_a = from_a || Date.new(1, 1, 1)
    end_a = until_a || Date.new(9999, 12, 31)
    start_b = from_b || Date.new(1, 1, 1)
    end_b = until_b || Date.new(9999, 12, 31)
    start_a < end_b && start_b < end_a
  end

  def self.contained?(from, until_date, container_from, container_until)
    if container_from.present? && (from.blank? || from < container_from)
      return false
    end
    if container_until.present? && (until_date.blank? || until_date > container_until)
      return false
    end

    true
  end

  def self.intersection(from_a, until_a, from_b, until_b)
    return unless overlap?(from_a, until_a, from_b, until_b)

    from = [ from_a, from_b ].compact.max
    until_date = [ until_a, until_b ].compact.min
    return if from.present? && until_date.present? && from >= until_date

    [ from, until_date ]
  end
end
