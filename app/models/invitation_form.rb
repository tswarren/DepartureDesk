class InvitationForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  SOURCES = %w[new existing].freeze

  attribute :email_address, :string
  attribute :role, :string
  attribute :first_name, :string
  attribute :last_name, :string
  attribute :preferred_name, :string
  attribute :person_source, :string, default: "new"
  attribute :person_party_id, :string
  attribute :office_ids, default: -> { [] }
  attribute :default_office_id, :string

  validates :email_address, :role, presence: true
  validates :role, inclusion: { in: AgencyMembership::ROLES }
  validates :person_source, inclusion: { in: SOURCES }
  validates :first_name, :last_name, presence: true, if: :new_person?
  validates :person_party_id, presence: true, if: :existing_person?
  validate :offices_required_when_present
  validate :existing_person_is_unlinked

  def new_person?
    person_source != "existing"
  end

  def existing_person?
    person_source == "existing"
  end

  def selected_person_party_id
    person_party_id.presence if existing_person?
  end

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

  def existing_person_is_unlinked
    return unless existing_person?
    return if person_party_id.blank? || Current.agency.blank?

    person = Current.agency.people.find_by(party_id: person_party_id)
    unless person
      errors.add(:person_party_id, "must be an unlinked person in this agency")
      return
    end

    if person.linked_to_membership?
      errors.add(:person_party_id, "is already linked to a membership")
    end
  end
end
