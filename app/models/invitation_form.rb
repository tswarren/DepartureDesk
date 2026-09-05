class InvitationForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :email_address, :string
  attribute :role, :string
  attribute :first_name, :string
  attribute :last_name, :string
  attribute :preferred_name, :string

  validates :email_address, :first_name, :last_name, :role, presence: true
  validates :role, inclusion: { in: AgencyMembership::ROLES }
end
