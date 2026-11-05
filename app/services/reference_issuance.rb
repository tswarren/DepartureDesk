# Issues the next agency reference for a namespace (REF-02, REF-03, REF-05).
# The sequence row is locked for the caller's transaction, so a rollback
# returns the number. Gapless types refuse to issue outside a transaction.
module ReferenceIssuance
  def issue_reference!(agency, namespace)
    if namespace.in?(ReferenceSequence::GAPLESS) && !ReferenceSequence.connection.transaction_open?
      raise ArgumentError, "#{namespace} references must be issued inside the record's transaction"
    end

    label = namespace.humanize
    sequence = ReferenceSequence.lock.find_by(agency_id: agency.id, namespace:)
    raise AgencyCommand::Error.new("#{label} reference sequence is missing.", code: :invalid) if sequence.nil?
    if sequence.fixed_width? && sequence.next_value >= ReferenceSequence::EXHAUSTED_AT
      raise AgencyCommand::Error.new("#{label} references are exhausted.", code: :reference_exhausted)
    end

    reference = ReferenceSequence.format_reference(namespace, sequence.next_value)
    sequence.update!(next_value: sequence.next_value + 1)
    reference
  end
end
