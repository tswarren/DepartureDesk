# Creates a Draft arrangement for a supplier on a Departure (SUP-07, SUP-11).
# Its currency is the Departure's (FIN-22; no FX in Slice 1).
class CreateSupplierArrangement < AgencyCommand
  include ArrangementCommandSupport
  include ReferenceIssuance

  def initialize(agency:, actor:, departure:, supplier_id:, attributes: {})
    @agency = agency
    @actor = actor
    @departure = departure
    @supplier_id = supplier_id
    @attributes = attributes.to_h.stringify_keys
  end

  def call
    ensure_departure_actor!(:manage_arrangements)

    ActiveRecord::Base.transaction do
      departure = lock_arrangement_context!
      currency = ensure_departure_currency!(departure)
      supplier = @agency.suppliers.find_by(id: parse_optional_uuid(@supplier_id, "Supplier"))
      raise Error.new("Choose a supplier.", code: :invalid) if supplier.nil?
      raise Error.new("That supplier is not active.", code: :invalid_state) unless supplier.active?
      if departure.supplier_arrangements.live.exists?(supplier_id: supplier.id)
        raise Error.new("This departure already has an arrangement with that supplier.", code: :invalid)
      end

      arrangement = departure.supplier_arrangements.create!(
        agency: @agency,
        supplier:,
        arrangement_reference: issue_reference!(@agency, ReferenceSequence::ARRANGEMENT_NAMESPACE),
        currency:,
        **arrangement_attributes(supplier).symbolize_keys
      )
      audit!(
        agency: @agency, action: "supplier_arrangement.created", subject: arrangement, actor: @actor,
        details: { "supplier_arrangement_id" => arrangement.id, "departure_id" => departure.id, "supplier_id" => supplier.id,
                   "arrangement_reference" => arrangement.arrangement_reference }
      )
      Result.new(status: :created, record: arrangement)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
