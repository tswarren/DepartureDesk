# A convenience link from a traveler to a client, with a relationship
# (CLT-09). It grants nothing: it never gives the client access to the
# traveler's data, and a traveler can be booked without one (CLT-10).
class TravelerLink < ApplicationRecord
  RELATIONSHIPS = %w[self family_member employee_or_member other].freeze
  RELATIONSHIP_LABELS = {
    "self" => "Self", "family_member" => "Family member", "employee_or_member" => "Employee or member", "other" => "Other"
  }.freeze

  belongs_to :agency
  belongs_to :traveler, inverse_of: :links
  belongs_to :client

  enum :relationship, RELATIONSHIPS.index_by(&:itself), validate: true, prefix: :related_as

  attr_readonly :agency_id, :traveler_id, :client_id

  validates :traveler_id, uniqueness: { scope: :client_id, message: "is already linked to this client" }
  validate :self_only_for_a_person

  def relationship_label = RELATIONSHIP_LABELS.fetch(relationship)

  private

  def self_only_for_a_person
    errors.add(:relationship, "Self is only for a person client") if related_as_self? && client && client.client_person_id.nil?
  end
end
