module SupplierReferenceIssuance
  def issue_supplier_reference!(agency)
    sequence = ReferenceSequence.lock.find_by(agency_id: agency.id, namespace: ReferenceSequence::SUPPLIER_NAMESPACE)
    if sequence.nil?
      raise AgencyCommand::Error.new("Supplier reference sequence is missing.", code: :invalid)
    end
    if sequence.next_value >= ReferenceSequence::EXHAUSTED_AT
      raise AgencyCommand::Error.new("Supplier references are exhausted.", code: :reference_exhausted)
    end

    reference = format("SUP-%06d", sequence.next_value)
    sequence.update!(next_value: sequence.next_value + 1)
    reference
  end
end
