class InvitationForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :email_address, :string
  attribute :role, :string
  attribute :first_name, :string
  attribute :last_name, :string
  attribute :preferred_name, :string
  attribute :office_ids, default: -> { [] }
  attribute :default_office_id, :string

  validates :email_address, :first_name, :last_name, :role, presence: true
  validates :role, inclusion: { in: AgencyMembership::ROLES }
  validate :offices_required_when_present

  private

  def offices_required_when_present
    return unless Agency.table_exists? && Office.table_exists?
    return unless Current.agency&.offices&.active&.exists?

    ids = Array(office_ids).compact_blank
    if role == "staff" && (ids.empty? || default_office_id.blank?)
      errors.add(:office_ids, "must include a default office")
    end
    if role == "administrator" && default_office_id.blank?
      errors.add(:default_office_id, "must be selected")
    end
  end
end
