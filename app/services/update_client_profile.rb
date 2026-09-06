class UpdateClientProfile < UpdateRoleProfile
  private

  def profile_association
    :client_profile
  end

  def role_noun
    "client"
  end
end
