# frozen_string_literal: true

class UpdateCruiseSupplierRateSchedule < AgencyCommand
  include CostCommandSupport
  include CruiseSupplierRateBuilders

  def initialize(agency:, actor:, arrangement:, resource:,
    profiles: nil, cells: nil, terms: nil, commission: nil,
    custom_rows: nil, overlap_resolution: nil,
    stage: nil, notes: nil, convert_legacy: false,
    version_lock_version:, definition_lock_version:, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @resource = resource
    @profiles = profiles
    @cells = cells
    @terms = terms
    @commission = commission
    @custom_rows = custom_rows
    @overlap_resolution = overlap_resolution
    @stage = stage
    @notes = notes
    @convert_legacy = convert_legacy
    @version_lock_version = version_lock_version
    @definition_lock_version = definition_lock_version
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        arrangement = @agency.supplier_arrangements.find(@arrangement.id)
        version = arrangement.versions.find_by!(status: "draft")
        _item_def, _occ_def, resource_definition, item, occurrence, resource =
          resolve_cruise_rate_context!(arrangement, version, @resource.id)

        source = find_exact_context_source(version, item: item, occurrence: occurrence, resource: resource)
        raise Error.new("Add Supplier rates before updating them.", code: :invalid_state) unless source

        charging_id = source.charging_supplier_id
        departure, arrangement, version, contractor = cost_graph!(
          arrangement, extra_supplier_ids: [ charging_id ]
        )
        suppliers = lock_suppliers_in_uuid_order!(
          arrangement.contracting_supplier_id, charging_id
        ).index_by(&:id)
        contractor = suppliers.fetch(arrangement.contracting_supplier_id)
        charging_supplier = suppliers.fetch(charging_id)
        ensure_cost_ordinary_edit!(departure, arrangement, version, contractor, charging_supplier)

        source = lock_source!(version, source)
        shape = DetectCruiseSupplierRateShape.new(
          agency: @agency, arrangement: arrangement, resource: resource, version: version
        ).call
        unless shape.compatible? && !shape.empty?
          raise Error.new(
            "These Supplier terms need advanced cost planning.", code: :invalid_state
          )
        end

        definition = lock_definition!(source, shape.definition)
        ensure_current_lock_version!(version, @version_lock_version)
        ensure_current_lock_version!(definition, @definition_lock_version)

        converting = shape.legacy? && !shape.matrix?
        if converting && !(@convert_legacy == true || @convert_legacy.to_s == "true" || @convert_legacy.to_s == "1")
          raise Error.new(
            "Confirm conversion of the existing Supplier rate schedule to the rate matrix before saving.",
            code: :invalid
          )
        end

        currency = definition.currency
        matrix = build_matrix_from_inputs(currency)
        resolve_matrix_participant_categories!(matrix, version: version, item: item)

        if @stage.present?
          stage = @stage.to_s
          unless SupplierCostDefinition::STAGES.include?(stage)
            raise Error.new("Choose estimate or contracted.", code: :invalid)
          end
          if definition.stage != stage
            raise Error.new(
              "Terms stage cannot be changed after Supplier rates are saved. " \
              "Keep #{definition.stage.humanize.downcase}, or open advanced cost planning for a new definition.",
              code: :invalid
            )
          end
        end

        if !@notes.nil?
          source.update!(
            notes: normalize_text(@notes, "Notes", SupplierCostSource::NOTES_LIMIT, required: false)
          )
        end

        sync_matrix_components!(definition, matrix: matrix, converting_legacy: converting)
        bump_version!(version)
        audit_details = {
          "supplier_cost_source_id" => source.id,
          "supplier_cost_definition_id" => definition.id,
          "cruise_supplier_rate_schedule" => true,
          "cruise_supplier_rate_matrix" => true,
          "resource_id" => resource.id,
          "supplier_code" => resource_definition.supplier_code
        }
        audit_details["legacy_matrix_conversion"] = true if converting
        audit_cost!("supplier_arrangement.cost_definition_updated", arrangement, version,
          audit_details.merge(source_context(source)))
        AgencyCommand::Result.new(status: :updated, record: definition.reload)
      end
    end
  end

  private

  def build_matrix_from_inputs(currency)
    if @cells.present? || @profiles.present?
      normalize_matrix_payload(
        profiles: @profiles.presence || default_smith_profiles,
        cells: @cells || {},
        commission: @commission,
        custom_rows: @custom_rows,
        overlap_resolution: @overlap_resolution,
        currency: currency,
        convert_legacy: @convert_legacy
      )
    elsif @terms.present?
      cells = smith_matrix_cells_from_legacy_terms(@terms, currency)
      normalize_matrix_payload(
        profiles: default_smith_profiles,
        cells: cells,
        commission: @commission,
        custom_rows: @custom_rows,
        overlap_resolution: @overlap_resolution,
        currency: currency,
        convert_legacy: @convert_legacy
      )
    else
      raise Error.new("Enter Supplier rate terms.", code: :invalid)
    end
  end
end
