class CreateSupplierProfile < CreateRoleProfile
  private

  def profile_class
    SupplierProfile
  end

  def profile_association
    :supplier_profile
  end

  def role_noun
    "supplier"
  end

  def create_attributes
    super.merge(default_currency: @agency.default_currency)
  end

  def ensure_role_kind_allowed!(party)
    if party.household?
      raise Error.new("Households cannot be suppliers.", code: :invalid)
    end

    super
  end
end
