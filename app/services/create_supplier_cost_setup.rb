class CreateSupplierCostSetup < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, arrangement:, source_attributes:, definition_attributes:,
    component_attributes: nil, base_links: nil, assumption_attributes: nil,
    version_lock_version:, idempotency_key:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @source_attributes = source_attributes
    @definition_attributes = definition_attributes
    @component_attributes = component_attributes
    @base_links = base_links
    @assumption_attributes = assumption_attributes
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        source_input = @source_attributes.to_h.with_indifferent_access
        charging_id = required_uuid(source_input[:charging_supplier_id], "Charging supplier")
        departure, arrangement, version, contractor = cost_graph!(
          @arrangement, extra_supplier_ids: [ charging_id ]
        )
        suppliers = lock_suppliers_in_uuid_order!(
          arrangement.contracting_supplier_id, charging_id
        ).index_by(&:id)
        contractor = suppliers.fetch(arrangement.contracting_supplier_id)
        charging_supplier = suppliers.fetch(charging_id)
        item, occurrence, resource = lock_item_cost_context!(
          arrangement, version, item: source_input[:arrangement_item_id],
          occurrence: source_input[:service_occurrence_id],
          resource: source_input[:supplier_resource_id]
        )
        ensure_cost_ordinary_edit!(departure, arrangement, version, contractor, charging_supplier)
        ensure_eligible_charging_supplier!(arrangement, version, item, occurrence, charging_supplier)

        source_attrs = {
          charging_supplier_id: charging_supplier.id,
          label: normalize_text(source_input[:label], "Label", SupplierCostSource::LABEL_LIMIT),
          notes: normalize_text(source_input[:notes], "Notes", SupplierCostSource::NOTES_LIMIT, required: false),
          arrangement_item_id: item&.id, service_occurrence_id: occurrence&.id,
          supplier_resource_id: resource&.id
        }
        definition_input = @definition_attributes.to_h.with_indifferent_access
        stage = definition_input[:stage].to_s
        unless SupplierCostDefinition::STAGES.include?(stage)
          raise Error.new("Choose estimate or contracted.", code: :invalid)
        end
        definition_attrs = normalize_definition_attributes(definition_input, departure).merge(stage:)
        component_attrs = if definition_attrs[:mode] == "calculated"
          raise Error.new("Enter the first cost component.", code: :invalid) unless @component_attributes
          normalize_component_attributes(
            @component_attributes, version:, item:, currency: definition_attrs[:currency]
          )
        elsif @component_attributes.present?
          raise Error.new("Zero-cost definitions cannot contain components.", code: :invalid)
        end
        links = normalize_base_links(@base_links).reject { |entry| entry[:base_component_id].blank? }
        assumption_attrs = normalize_assumption_attributes(item, occurrence, resource)
        payload = {
          supplier_arrangement_version_id: version.id, source: source_attrs,
          definition: definition_attrs, component: component_attrs,
          base_links: links, assumption: assumption_attrs
        }
        result_class = component_attrs ? SupplierCostComponent : SupplierCostDefinition

        result = idempotent_create!(
          command_name: self.class.name, idempotency_key: @idempotency_key,
          payload:, result_class:
        ) do
          ensure_current_lock_version!(version, @version_lock_version)
          siblings = version.supplier_cost_sources
            .where(arrangement_item_id: item&.id).order(:position, :id).lock.to_a
          source = build_supplier_cost_source_already_locked!(
            version:, arrangement:, attributes: source_attrs,
            position: siblings.map(&:position).max.to_i + 1
          )
          definition = build_supplier_cost_definition_already_locked!(
            source:, arrangement:, attributes: definition_attrs
          )
          component = if component_attrs
            build_supplier_cost_component_already_locked!(
              definition:, attributes: component_attrs, position: 1, base_links: links
            )
          end
          assumption = if assumption_attrs
            build_supplier_cost_usage_assumption_already_locked!(
              version:, attributes: assumption_attrs
            )
          end
          bump_version!(version)
          audit_cost!("supplier_arrangement.cost_setup_created", arrangement, version, {
            "supplier_cost_source_id" => source.id,
            "supplier_cost_definition_id" => definition.id,
            "supplier_cost_component_id" => component&.id,
            "supplier_cost_usage_assumption_id" => assumption&.id,
            "charging_supplier_id" => charging_supplier.id,
            "stage" => definition.stage, "mode" => definition.mode
          }.merge(source_context(source)))
          component || definition
        end

        # The replay root is deliberately the first component for calculated
        # setups and the definition for zero-cost setups. Their ownership chain
        # recovers every created parent without making the source a lossy root.
        result
      end
    end
  end

  private

  def normalize_assumption_attributes(item, occurrence, resource)
    return nil if @assumption_attributes.blank?
    raise Error.new("Usage assumptions require an Item cost.", code: :invalid) unless item

    attrs = @assumption_attributes.to_h.with_indifferent_access
    values = {
      expected_resource_units: integer_or_nil(attrs[:expected_resource_units], "Expected resource units"),
      expected_persons: integer_or_nil(attrs[:expected_persons], "Expected persons"),
      expected_billable_nights: integer_or_nil(attrs[:expected_billable_nights], "Expected billable nights")
    }
    return nil if values.values.all?(&:nil?)

    values.merge(
      arrangement_item_id: item.id, service_occurrence_id: occurrence&.id,
      supplier_resource_id: resource&.id
    )
  end
end
