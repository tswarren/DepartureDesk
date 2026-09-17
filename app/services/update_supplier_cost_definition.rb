class UpdateSupplierCostDefinition < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, definition:, attributes:, lock_version:)
    @agency, @actor, @definition, @lock_version = agency, actor, definition, lock_version
    @attributes = attributes.to_h.with_indifferent_access
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        departure, arrangement, version, contractor = cost_graph!(@definition)
        source = lock_source!(version, @definition.supplier_cost_source)
        charging = locked_supplier!(source.charging_supplier_id)
        ensure_cost_ordinary_edit!(departure, arrangement, version, contractor, charging)
        definition = lock_definition!(source, @definition)
        ensure_current_lock_version!(definition, @lock_version)
        attrs = normalize_definition_attributes!(@attributes, definition, departure)
        return Result.new(status: :noop, record: definition) if same_values?(definition, attrs)
        if attrs[:currency] != definition.currency && definition.supplier_cost_components.exists?
          raise Error.new("Remove components before changing definition currency.", code: :invalid_state)
        end
        if attrs[:mode] == "zero_cost" && definition.supplier_cost_components.exists?
          raise Error.new("Remove components before marking a definition zero cost.", code: :invalid_state)
        end
        before = definition.attributes.slice(*attrs.keys.map(&:to_s))
        definition.update!(attrs.merge(READINESS_FIELDS))
        audit_cost!("supplier_arrangement.cost_definition_updated", arrangement, version, {
          "supplier_cost_source_id" => source.id, "supplier_cost_definition_id" => definition.id,
          "changed_fields" => attrs.keys.select { |key| before[key.to_s] != definition.public_send(key) }.map(&:to_s),
          "stage" => definition.stage, "mode" => definition.mode, "status" => definition.status
        })
        Result.new(status: :updated, record: definition)
      end
    end
  end

  private

  def normalize_definition_attributes!(input, definition, departure)
    attrs = input.to_h.with_indifferent_access
    normalize_definition_attributes({
      mode: attrs.fetch(:mode, definition.mode),
      currency: attrs.fetch(:currency, definition.currency),
      rounding_mode: attrs.fetch(:rounding_mode, definition.rounding_mode),
      zero_cost_reason: attrs.fetch(:zero_cost_reason, definition.zero_cost_reason)
    }, departure)
  end
end
