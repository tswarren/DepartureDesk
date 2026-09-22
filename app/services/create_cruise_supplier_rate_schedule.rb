# frozen_string_literal: true

class CreateCruiseSupplierRateSchedule < AgencyCommand
  include CostCommandSupport
  include CruiseSupplierRateBuilders

  SetupResult = Data.define(:source, :definition)

  def initialize(agency:, actor:, arrangement:, resource:,
    profiles: nil, cells: nil, terms: nil, commission: nil,
    stage: "estimate", notes: nil, version_lock_version:, idempotency_key:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @resource = resource
    @profiles = profiles
    @cells = cells
    @terms = terms
    @commission = commission
    @stage = stage
    @notes = notes
    @version_lock_version = version_lock_version
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

        charging_id = eligible_charging_supplier_id(arrangement, version, item, occurrence)
        departure, arrangement, version, contractor = cost_graph!(
          arrangement, extra_supplier_ids: [ charging_id ]
        )
        suppliers = lock_suppliers_in_uuid_order!(
          arrangement.contracting_supplier_id, charging_id
        ).index_by(&:id)
        contractor = suppliers.fetch(arrangement.contracting_supplier_id)
        charging_supplier = suppliers.fetch(charging_id)
        ensure_cost_ordinary_edit!(departure, arrangement, version, contractor, charging_supplier)
        ensure_eligible_charging_supplier!(arrangement, version, item, occurrence, charging_supplier)

        currency = departure.operating_currency
        matrix = build_matrix_from_inputs(currency)
        stage = @stage.to_s
        unless SupplierCostDefinition::STAGES.include?(stage)
          raise Error.new("Choose estimate or contracted.", code: :invalid)
        end

        payload = {
          supplier_arrangement_version_id: version.id,
          arrangement_item_id: item.id,
          service_occurrence_id: occurrence.id,
          supplier_resource_id: resource.id,
          stage: stage,
          profiles: matrix.fetch(:profiles).map(&:to_s),
          cells: matrix.fetch(:cells),
          commission: serialize_commission(matrix.fetch(:commission)),
          notes: @notes.to_s
        }

        result = idempotent_create!(
          command_name: self.class.name,
          idempotency_key: @idempotency_key,
          payload: payload,
          result_class: SupplierCostSource
        ) do
          ensure_current_lock_version!(version, @version_lock_version)
          if find_exact_context_source(version, item: item, occurrence: occurrence, resource: resource)
            raise Error.new("Supplier rates already exist for this cabin category.", code: :invalid_state)
          end

          siblings = version.supplier_cost_sources
            .where(arrangement_item_id: item.id).order(:position, :id).lock.to_a
          source = build_supplier_cost_source_already_locked!(
            version: version,
            arrangement: arrangement,
            attributes: {
              charging_supplier_id: charging_supplier.id,
              label: "#{resource_definition.supplier_code.presence || resource_definition.name} Supplier rates",
              notes: normalize_text(@notes, "Notes", SupplierCostSource::NOTES_LIMIT, required: false),
              arrangement_item_id: item.id,
              service_occurrence_id: occurrence.id,
              supplier_resource_id: resource.id
            },
            position: siblings.map(&:position).max.to_i + 1
          )
          definition = build_supplier_cost_definition_already_locked!(
            source: source,
            arrangement: arrangement,
            attributes: {
              stage: stage,
              mode: "calculated",
              currency: currency,
              rounding_mode: "half_up",
              zero_cost_reason: nil
            }
          )
          sync_matrix_components!(definition, matrix: matrix, converting_legacy: false)
          bump_version!(version)
          audit_cost!("supplier_arrangement.cost_setup_created", arrangement, version, {
            "supplier_cost_source_id" => source.id,
            "supplier_cost_definition_id" => definition.id,
            "charging_supplier_id" => charging_supplier.id,
            "stage" => definition.stage,
            "mode" => definition.mode,
            "cruise_supplier_rate_schedule" => true,
            "cruise_supplier_rate_matrix" => true
          }.merge(source_context(source)))
          source
        end

        source = result.record
        definition = source.supplier_cost_definitions.order(:stage, :id).first
        AgencyCommand::Result.new(
          status: result.status,
          record: SetupResult.new(source: source, definition: definition)
        )
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
        currency: currency
      )
    elsif @terms.present?
      cells = smith_matrix_cells_from_legacy_terms(@terms, currency)
      normalize_matrix_payload(
        profiles: default_smith_profiles,
        cells: cells,
        commission: @commission,
        currency: currency
      )
    else
      raise Error.new("Enter Supplier rate terms.", code: :invalid)
    end
  end

  def serialize_commission(commission)
    commission.transform_values do |value|
      case value
      when BigDecimal then value.to_s("F")
      when Hash then value.transform_keys(&:to_s).transform_values { |v| v.is_a?(BigDecimal) ? v.to_s("F") : v }
      else value
      end
    end
  end
end
