module ClientReferenceIssuance
  def issue_client_reference!(agency)
    sequence = ReferenceSequence.lock.find_by(agency_id: agency.id, namespace: ReferenceSequence::CLIENT_NAMESPACE)
    if sequence.nil?
      raise AgencyCommand::Error.new("Client reference sequence is missing.", code: :invalid)
    end
    if sequence.next_value >= ReferenceSequence::EXHAUSTED_AT
      raise AgencyCommand::Error.new("Client references are exhausted.", code: :reference_exhausted)
    end

    reference = format("CL-%06d", sequence.next_value)
    sequence.update!(next_value: sequence.next_value + 1)
    reference
  end
end
