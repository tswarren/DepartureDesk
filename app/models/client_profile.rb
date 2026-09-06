class ClientProfile < ApplicationRecord
  include RoleProfile

  PARTY_KINDS = Party::KINDS

  validates :party_kind, inclusion: { in: PARTY_KINDS }
end
