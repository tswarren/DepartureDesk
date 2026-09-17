class UpdateSupplierCostSource < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, source:, attributes:, lock_version:)
    @agency, @actor, @source, @lock_version = agency, actor, source, lock_version
    @attributes = attributes.to_h.with_indifferent_access
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        departure, arrangement, version, contractor = cost_graph!(@source)
        source = lock_source!(version, @source)
        charging_supplier = locked_supplier!(source.charging_supplier_id)
        ensure_cost_ordinary_edit!(departure, arrangement, version, contractor, charging_supplier)
        ensure_current_lock_version!(source, @lock_version)
        attrs = {
          label: normalize_text(@attributes.fetch(:label, source.label), "Label", SupplierCostSource::LABEL_LIMIT),
          notes: normalize_text(@attributes.fetch(:notes, source.notes), "Notes", SupplierCostSource::NOTES_LIMIT, required: false)
        }
        return Result.new(status: :noop, record: source) if same_values?(source, attrs)
        source.update!(attrs)
        audit_cost!("supplier_arrangement.cost_source_updated", arrangement, version, {
          "supplier_cost_source_id" => source.id, "changed_fields" => changed_fields(source, attrs)
        }.merge(source_context(source)))
        Result.new(status: :updated, record: source)
      end
    end
  end
end
