class UpdateSupplierCostParticipantCategory < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, category:, lock_version:, attributes: nil, label: nil)
    @agency, @actor, @category, @lock_version = agency, actor, category, lock_version
    @label = label || (attributes || {}).to_h.with_indifferent_access[:label]
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        departure, arrangement, version, contractor = cost_graph!(@category)
        ensure_cost_ordinary_edit!(departure, arrangement, version, contractor)
        category = version.supplier_cost_participant_categories.lock.find(@category.id)
        ensure_current_lock_version!(category, @lock_version)
        label = normalize_text(@label, "Label", SupplierCostParticipantCategory::LABEL_LIMIT)
        return Result.new(status: :noop, record: category) if category.label == label
        dependent_definitions = SupplierCostDefinition.joins(:supplier_cost_components)
          .where(supplier_cost_components: { participant_category_id: category.id })
          .distinct.order(:id).lock.to_a
        category.update!(label: label)
        dependent_definitions.each { |definition| clear_readiness!(definition) }
        audit_cost!("supplier_arrangement.cost_participant_category_updated", arrangement, version, {
          "supplier_cost_participant_category_id" => category.id,
          "arrangement_item_id" => category.arrangement_item_id,
          "changed_fields" => [ "label" ], "label" => label
        })
        Result.new(status: :updated, record: category)
      end
    end
  end
end
