# frozen_string_literal: true

# Explicit contingent → guaranteed qualification for a cost source.
# Elapsed time alone never performs this transition.
class QualifySupplierContingentExposure < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, arrangement:, cost_source:, note:,
    qualification_reason: "staff_qualified_contingent_exposure",
    idempotency_key:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @cost_source = cost_source
    @note = note.to_s.strip
    @qualification_reason = qualification_reason.to_s.strip
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    raise Error.new("Enter a qualification note.", code: :invalid) if @note.blank?
    if @qualification_reason.blank? || @qualification_reason.length > 120
      raise Error.new("Enter a qualification reason of 120 characters or fewer.", code: :invalid)
    end

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      arrangement_row = @agency.supplier_arrangements.find(@arrangement.id)
      lock_suppliers_in_uuid_order!(arrangement_row.contracting_supplier_id)
      departure = lock_departure_for!(arrangement_row.departure_id)
      arrangement = lock_arrangement_for!(arrangement_row)
      raise Error.new("That supplier arrangement has ended.", code: :invalid_state) if arrangement.ended?
      raise Error.new("That supplier arrangement has been abandoned.", code: :invalid_state) if arrangement.abandoned?

      version = arrangement.governing_version ||
        raise(Error.new("Arrangement has no governing version.", code: :invalid_state))
      version = arrangement.versions.lock.find(version.id)
      source_id = @cost_source.is_a?(SupplierCostSource) ? @cost_source.id : @cost_source
      source = version.supplier_cost_sources.lock.find(source_id)

      payload = {
        "supplier_arrangement_id" => arrangement.id,
        "supplier_cost_source_id" => source.id,
        "qualification_reason" => @qualification_reason,
        "note" => @note
      }

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload:,
        result_class: SupplierExposureSourceQualification
      ) do
        now = Time.current
        qualification = SupplierExposureSourceQualification.create!(
          agency: @agency,
          departure:,
          supplier_arrangement: arrangement,
          supplier_arrangement_version: version,
          source_kind: "supplier_cost_source",
          source_id: source.id,
          qualification_band: "guaranteed",
          qualification_reason: @qualification_reason,
          note: @note,
          actor: @actor,
          recorded_at: now
        )
        rebuild_exposure_projection_already_locked!(arrangement, version:, at: now)
        audit!(
          agency: @agency, actor: @actor, subject: arrangement,
          action: "supplier_arrangement.exposure_qualified",
          details: {
            "supplier_cost_source_id" => source.id,
            "supplier_exposure_source_qualification_id" => qualification.id,
            "qualification_band" => "guaranteed",
            "qualification_reason" => @qualification_reason
          }
        )
        qualification
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("That cost source is already qualified.", code: :conflict)
  end
end
