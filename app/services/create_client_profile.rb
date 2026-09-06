class CreateClientProfile < CreateRoleProfile
  private

  def profile_class
    ClientProfile
  end

  def profile_association
    :client_profile
  end

  def role_noun
    "client"
  end
end
