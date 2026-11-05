module SupplierReferenceIssuance
  include ReferenceIssuance

  def issue_supplier_reference!(agency)
    issue_reference!(agency, ReferenceSequence::SUPPLIER_NAMESPACE)
  end
end
