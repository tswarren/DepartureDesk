# Classifies current Supplier-issued identifiers for same-owner reuse vs cross-owner review.
#
# Arrangement owner: same Arrangement and supplier_reservation_id IS NULL.
# Reservation owner: exact Reservation ID.
# Everything else is a foreign (cross-owner) candidate.
class SupplierIssuedIdentifierOwnerLookup
  Result = Data.define(:same_owner, :foreign)

  def self.call(agency:, supplier_id:, identifier_type:, issuer_context:, normalized_value:,
    arrangement:, reservation: nil)
    new(
      agency:, supplier_id:, identifier_type:, issuer_context:, normalized_value:,
      arrangement:, reservation:
    ).call
  end

  def initialize(agency:, supplier_id:, identifier_type:, issuer_context:, normalized_value:,
    arrangement:, reservation: nil)
    @agency = agency
    @supplier_id = supplier_id
    @identifier_type = identifier_type
    @issuer_context = issuer_context
    @normalized_value = normalized_value
    @arrangement = arrangement
    @reservation = reservation
  end

  def call
    candidates = SupplierIssuedIdentifier.where(agency_id: @agency.id).where(
      supplier_id: @supplier_id,
      identifier_type: @identifier_type,
      issuer_context: @issuer_context,
      normalized_value: @normalized_value,
      superseded_at: nil
    ).to_a

    same_owner, foreign = candidates.partition { |row| same_owner?(row) }
    Result.new(same_owner: same_owner, foreign: foreign)
  end

  private

  def same_owner?(row)
    if @reservation
      row.supplier_reservation_id == @reservation.id
    else
      row.supplier_arrangement_id == @arrangement.id && row.supplier_reservation_id.nil?
    end
  end
end
