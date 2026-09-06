class DeactivateSupplierProfile < DeactivateRoleProfile
  private

  def profile_association
    :supplier_profile
  end

  def role_noun
    "supplier"
  end
end
