# Which profile fields and footer a document family shows (SET-06, SET-07).
# One row per agency and family, created with the defaults below.
class AgencyDocumentInclusion < ApplicationRecord
  FAMILIES = %w[confirmation invoice receipt statement].freeze
  FIELDS = %w[
    display_name contact_email phone legal_name mailing_address
    agency_contact_name seller_of_travel_disclosure footer
  ].freeze
  FINANCIAL_ONLY = %w[legal_name mailing_address].freeze
  OFF_UNTIL_SELECTED = %w[agency_contact_name seller_of_travel_disclosure].freeze

  belongs_to :agency

  attr_readonly :agency_id, :document_family

  validates :document_family, inclusion: { in: FAMILIES }, uniqueness: { scope: :agency_id }

  def self.defaults_for(family)
    FIELDS.to_h do |field|
      included = !field.in?(OFF_UNTIL_SELECTED) && (family != "confirmation" || !field.in?(FINANCIAL_ONLY))
      [ "include_#{field}", included ]
    end
  end

  def self.create_defaults!(agency)
    FAMILIES.each do |family|
      agency.document_inclusions.create!(document_family: family, **defaults_for(family))
    end
  end

  def includes?(field)
    public_send("include_#{field}")
  end
end
