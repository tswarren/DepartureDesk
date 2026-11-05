module ClientReferenceIssuance
  include ReferenceIssuance

  def issue_client_reference!(agency)
    issue_reference!(agency, ReferenceSequence::CLIENT_NAMESPACE)
  end
end
