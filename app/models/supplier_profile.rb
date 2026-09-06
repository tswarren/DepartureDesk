class SupplierProfile < ApplicationRecord
  include RoleProfile

  PARTY_KINDS = %w[
    person
    organization
  ].freeze
  NOTE_LIMIT = 2000
  NOTE_ATTRIBUTES = %i[
    payment_term_notes
    commission_notes
    booking_instructions
    payment_instructions
    cancellation_policy_notes
  ].freeze

  has_many :service_category_assignments,
    class_name: "SupplierServiceCategoryAssignment",
    inverse_of: :supplier_profile,
    dependent: :restrict_with_exception
  has_many :external_identifiers,
    inverse_of: :supplier_profile,
    dependent: :restrict_with_exception

  normalizes :default_currency, with: ->(value) { value&.strip&.upcase }
  normalizes :portal_url, with: ->(value) { value&.strip.presence }
  normalizes(*NOTE_ATTRIBUTES, with: ->(value) { value&.strip.presence })

  validates :party_kind, inclusion: { in: PARTY_KINDS }
  validates :default_currency,
    presence: true,
    format: {
      with: /\A[A-Z]{3}\z/,
      message: "must be a three-letter uppercase currency code"
    }
  validates(*NOTE_ATTRIBUTES, length: { maximum: NOTE_LIMIT })
  validate :portal_url_https
  validate :instruction_content

  def category_codes
    service_category_assignments.order(:category_code).map(&:category_code)
  end

  private

  def portal_url_https
    return if portal_url.blank?

    uri = URI.parse(portal_url)
    unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.blank?
      errors.add(:portal_url, "must be an HTTPS URL without credentials")
    end
  rescue URI::InvalidURIError
    errors.add(:portal_url, "must be an HTTPS URL without credentials")
  end

  def instruction_content
    NOTE_ATTRIBUTES.each do |attribute|
      value = public_send(attribute)
      next if value.blank?

      violation = PartyNoteContentPolicy.violation_for(value)
      errors.add(attribute, violation) if violation
    end
  end
end
