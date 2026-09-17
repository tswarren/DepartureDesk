class UpdateSupplierCostUsageAssumption < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, assumption:, attributes:, lock_version:)
    @agency, @actor, @assumption, @lock_version = agency, actor, assumption, lock_version
    @attributes = attributes.to_h.with_indifferent_access
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        departure, arrangement, version, contractor = cost_graph!(@assumption)
        ensure_cost_ordinary_edit!(departure, arrangement, version, contractor)
        assumption = version.supplier_cost_usage_assumptions.lock.find(@assumption.id)
        ensure_current_lock_version!(assumption, @lock_version)
        attrs = {
          expected_resource_units: value_for(:expected_resource_units, assumption),
          expected_persons: value_for(:expected_persons, assumption),
          expected_billable_nights: value_for(:expected_billable_nights, assumption)
        }
        if assumption.supplier_cost_occupancy_profiles.exists? &&
            (attrs[:expected_resource_units].present? || attrs[:expected_persons].present?)
          raise Error.new("Resource-unit and person totals are derived while occupancy profiles exist.", code: :invalid)
        end
        return Result.new(status: :noop, record: assumption) if same_values?(assumption, attrs)
        before = assumption.attributes.slice(*attrs.keys.map(&:to_s))
        assumption.update!(attrs)
        audit_cost!("supplier_arrangement.cost_usage_assumption_updated", arrangement, version, {
          "supplier_cost_usage_assumption_id" => assumption.id,
          "arrangement_item_id" => assumption.arrangement_item_id,
          "service_occurrence_id" => assumption.service_occurrence_id,
          "supplier_resource_id" => assumption.supplier_resource_id,
          "before" => before, "after" => attrs.stringify_keys
        })
        Result.new(status: :updated, record: assumption)
      end
    end
  end

  private

  def value_for(field, assumption)
    value = @attributes.key?(field) ? @attributes[field] : assumption.public_send(field)
    integer_or_nil(value, field.to_s.humanize)
  end
end
