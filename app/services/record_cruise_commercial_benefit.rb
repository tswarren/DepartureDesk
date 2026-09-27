# frozen_string_literal: true

class RecordCruiseCommercialBenefit < AgencyCommand
  include ArrangementCommandSupport

  COMMAND_NAME = "record_cruise_commercial_benefit"

  def initialize(
    agency:, actor:, arrangement:, term_type:, body:, source_citation:,
    version_lock_version:, definition_lock_version: nil, idempotency_key:
  )
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @term_type = term_type.to_s
    @body = body
    @source_citation = source_citation
    @version_lock_version = version_lock_version
    @definition_lock_version = definition_lock_version
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    ensure_term_type!
    body = normalize_body!
    citation = normalize_citation!

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      departure, arrangement, version = lock_departure_arrangement_version!(@arrangement)
      ensure_editable_version!(departure, arrangement, version)
      ensure_current_lock_version!(version, @version_lock_version)
      ensure_cruise_shape!(arrangement, version)

      definition = version.supplier_arrangement_commercial_benefit_definitions
        .lock.find_by(term_type: @term_type)
      if definition
        ensure_current_lock_version!(definition, @definition_lock_version)
        ensure_confirmed_wording_unchanged!(version, definition, body, citation)
      end

      idempotent_create!(
        command_name: COMMAND_NAME,
        idempotency_key: @idempotency_key,
        payload: payload_for(version, body, citation),
        result_class: SupplierArrangementCommercialBenefitDefinition
      ) do
        changed = definition.nil? || definition.body != body || definition.source_citation != citation
        record = persist!(arrangement, version, definition, body, citation)
        if changed
          audit!(
            agency: @agency,
            action: "supplier_arrangement.updated",
            subject: arrangement,
            actor: @actor,
            details: {
              "supplier_arrangement_id" => arrangement.id,
              "supplier_arrangement_version_id" => version.id,
              "changed_fields" => [ "commercial_benefit.#{@term_type}" ]
            }
          )
        end
        record
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def ensure_term_type!
    return if SupplierArrangementCommercialBenefitDefinition::TERM_TYPES.include?(@term_type)

    raise Error.new("Choose a commercial benefit type.", code: :invalid)
  end

  def normalize_body!
    text = @body.to_s.strip
    if text.blank?
      raise Error.new("Commercial benefit wording is required.", code: :invalid)
    end
    if text.length > SupplierArrangementCommercialBenefitDefinition::BODY_LIMIT
      raise Error.new("Commercial benefit wording is too long.", code: :invalid)
    end

    text
  end

  def normalize_citation!
    text = @source_citation.to_s.strip
    return nil if text.blank?
    if text.length > SupplierArrangementCommercialBenefitDefinition::CITATION_LIMIT
      raise Error.new("Source citation is too long.", code: :invalid)
    end

    text
  end

  def ensure_editable_version!(departure, arrangement, version)
    ensure_draft_graph!(arrangement, version)
    ensure_departure_accepts_new_planning!(departure)
  end

  def ensure_cruise_shape!(arrangement, version)
    shape = DetectCruiseArrangementShape.new(
      agency: @agency,
      arrangement: arrangement,
      version: version
    ).call
    return if shape.compatible?

    raise Error.new("Commercial benefits belong on a Cruise agreement.", code: :invalid_state)
  end

  def ensure_confirmed_wording_unchanged!(version, definition, body, citation)
    return if version.supplier_confirmations.none?
    return if definition.body == body && definition.source_citation == citation

    raise Error.new(
      "Changing saved wording on a Supplier-confirmed revision requires a successor.",
      code: :invalid_state
    )
  end

  def persist!(arrangement, version, definition, body, citation)
    if definition
      return definition if definition.body == body && definition.source_citation == citation

      definition.update!(body: body, source_citation: citation)
      return definition
    end

    benefit = find_or_create_benefit!(arrangement)
    version.supplier_arrangement_commercial_benefit_definitions.create!(
      agency: @agency,
      departure: arrangement.departure,
      supplier_arrangement: arrangement,
      supplier_arrangement_commercial_benefit: benefit,
      term_type: @term_type,
      body: body,
      source_citation: citation
    )
  end

  def find_or_create_benefit!(arrangement)
    existing = SupplierArrangementCommercialBenefitDefinition
      .where(supplier_arrangement_id: arrangement.id, term_type: @term_type)
      .order(:created_at)
      .first
    return existing.supplier_arrangement_commercial_benefit if existing

    arrangement.supplier_arrangement_commercial_benefits.create!(
      agency: @agency,
      departure: arrangement.departure
    )
  end

  def payload_for(version, body, citation)
    {
      supplier_arrangement_version_id: version.id,
      term_type: @term_type,
      body: body,
      source_citation: citation
    }
  end
end
