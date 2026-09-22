# frozen_string_literal: true

class UpdateCruiseSupplierRateSchedule < AgencyCommand
  include CostCommandSupport
  include CruiseSupplierRateBuilders

  def initialize(agency:, actor:, arrangement:, resource:, terms:, commission: nil,
    stage: nil, notes: nil, version_lock_version:, definition_lock_version:, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @resource = resource
    @terms = terms
    @commission = commission
    @stage = stage
    @notes = notes
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

        currency = definition.currency
        terms = normalize_rate_terms(@terms, currency)
        commission = normalize_commission(@commission, currency)

        if @stage.present?
          stage = @stage.to_s
          unless SupplierCostDefinition::STAGES.include?(stage)
            raise Error.new("Choose estimate or contracted.", code: :invalid)
          end
          definition.update!(stage: stage) if definition.stage != stage
        end

        if !@notes.nil?
          source.update!(
            notes: normalize_text(@notes, "Notes", SupplierCostSource::NOTES_LIMIT, required: false)
          )
        end

        sync_canonical_components!(definition, terms: terms, commission: commission)
        bump_version!(version)
        audit_cost!("supplier_arrangement.cost_definition_updated", arrangement, version, {
          "supplier_cost_source_id" => source.id,
          "supplier_cost_definition_id" => definition.id,
          "cruise_supplier_rate_schedule" => true,
          "resource_id" => resource.id,
          "supplier_code" => resource_definition.supplier_code
        }.merge(source_context(source)))
        AgencyCommand::Result.new(status: :updated, record: definition.reload)
      end
    end
  end
end
