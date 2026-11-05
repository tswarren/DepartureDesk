module DepartureReferenceIssuance
  include ReferenceIssuance

  def issue_departure_reference!(agency)
    issue_reference!(agency, ReferenceSequence::DEPARTURE_NAMESPACE)
  end
end
