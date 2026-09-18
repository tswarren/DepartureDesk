# Marks the prior current identifier superseded, then inserts an immutable replacement.
class SupersedeSupplierIssuedIdentifier < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, identifier:, attributes:, confirmation:)
    @agency = agency
    @actor = actor
    @identifier = identifier
    @attributes = attributes.to_h.with_indifferent_access
    @confirmation = confirmation
  end

  def call
    ensure_arrangement_actor!
    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      prior = SupplierIssuedIdentifier.lock.find_by!(id: @identifier.id, agency_id: @agency.id)
      raise Error.new("That identifier is already superseded.", code: :invalid_state) if prior.superseded_at.present?

      type = @attributes[:identifier_type].to_s.strip.presence || prior.identifier_type
      display = @attributes[:display_value].to_s.strip
      issuer = @attributes[:issuer_context].to_s.strip.presence || prior.issuer_context
      other_label = @attributes[:other_type_label].to_s.strip.presence
      raise Error.new("Enter a replacement Supplier identifier.", code: :invalid) if display.blank? || issuer.blank?

      prior.update!(superseded_at: Time.current)
      replacement = SupplierIssuedIdentifier.create!(
        agency: @agency,
        departure_id: prior.departure_id,
        supplier_arrangement_id: prior.supplier_arrangement_id,
        supplier_reservation_id: prior.supplier_reservation_id,
        supplier_id: prior.supplier_id,
        issuer_context: issuer,
        identifier_type: type,
        other_type_label: other_label,
        display_value: display,
        normalized_value: display.downcase,
        first_supplier_confirmation: @confirmation,
        supersedes_id: prior.id
      )
      Result.new(status: :created, record: replacement)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
