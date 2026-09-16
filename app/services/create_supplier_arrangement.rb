class CreateSupplierArrangement < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, departure:, attributes:, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @attributes = attributes.to_h.with_indifferent_access
    @idempotency_key = idempotency_key || @attributes.delete(:idempotency_key)
  end

  def call
    ensure_arrangement_actor!
    attrs = normalized_attributes

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      contractor = resolve_active_supplier!(attrs.delete(:contracting_supplier_id), "Contracting supplier")
      contact = resolve_optional_contact!(contractor, attrs.delete(:supplier_contact_id))
      departure = lock_departure_for!(@departure)
      ensure_departure_accepts_new_planning!(departure)

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: attrs.merge(contracting_supplier_id: contractor.id, supplier_contact_id: contact&.id, departure_id: departure.id),
        result_class: SupplierArrangement
      ) do
        arrangement = @agency.supplier_arrangements.create!(
          departure: departure,
          contracting_supplier: contractor,
          supplier_contact: contact,
          name: attrs[:name],
          status: "draft"
        )
        arrangement.versions.create!(
          agency: @agency,
          departure: departure,
          version_number: 1,
          status: "draft"
        )
        audit!(
          agency: @agency,
          action: "supplier_arrangement.created",
          subject: arrangement,
          actor: @actor,
          details: {
            "supplier_arrangement_id" => arrangement.id,
            "departure_id" => departure.id,
            "contracting_supplier_id" => contractor.id,
            "supplier_contact_id" => contact&.id,
            "name" => arrangement.name
          }
        )
        arrangement
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def normalized_attributes
    {
      name: normalize_arrangement_name(@attributes[:name]),
      contracting_supplier_id: @attributes[:contracting_supplier_id],
      supplier_contact_id: @attributes[:supplier_contact_id]
    }
  end
end
