class AllocateDepartureReference
  def self.next!(agency)
    new(agency).next!
  end

  def initialize(agency)
    @agency = agency
  end

  def next!
    counter = lock_or_initialize_counter!
    counter.last_value += 1
    counter.save!
    format("D-%06d", counter.last_value)
  end

  private

  def lock_or_initialize_counter!
    counter = DepartureReferenceCounter.lock.find_by(agency_id: @agency.id)
    return counter if counter

    begin
      DepartureReferenceCounter.create!(agency: @agency, last_value: 0)
    rescue ActiveRecord::RecordNotUnique
      # Another creator initialized the row.
    end

    DepartureReferenceCounter.lock.find_by!(agency_id: @agency.id)
  end
end
