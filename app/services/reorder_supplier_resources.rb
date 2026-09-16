class ReorderSupplierResources < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, item:, supplier_resource_ids:, version_lock_version:)
    @agency = agency
    @actor = actor
    @item = item
    @supplier_resource_ids = supplier_resource_ids
    @version_lock_version = version_lock_version
  end

  def call
    ensure_arrangement_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      arrangement = lock_arrangement_for!(@item.supplier_arrangement)
      departure = lock_departure_for!(arrangement.departure)
      version = lock_initial_version_for!(arrangement)
      item = lock_arrangement_item_for!(arrangement, @item)
      ensure_editable_draft_arrangement!(departure, arrangement, version)
      ensure_current_lock_version!(version, @version_lock_version)

      definitions = version.supplier_resource_definitions.where(arrangement_item: item).order(:position, :id).lock.to_a
      ordered_ids = normalized_id_list(@supplier_resource_ids, "Supplier resource")
      ensure_exact_permutation!(ordered_ids, definitions.map { |definition| definition.supplier_resource_id })
      definitions_by_resource_id = definitions.index_by(&:supplier_resource_id)

      ordered_ids.each_with_index do |resource_id, index|
        definitions_by_resource_id.fetch(resource_id).update!(position: index + 1)
      end
      ActiveRecord::Base.connection.execute("SET CONSTRAINTS supplier_resource_definitions_position_unique IMMEDIATE")
      bump_version!(version)
      audit!(
        agency: @agency,
        action: "supplier_arrangement.resources_reordered",
        subject: arrangement,
        actor: @actor,
        details: {
          "supplier_arrangement_id" => arrangement.id,
          "arrangement_item_id" => item.id,
          "supplier_resource_ids" => ordered_ids
        }
      )
      Result.new(status: :updated, record: arrangement)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def normalized_id_list(values, label)
    Array(values).map { |value| parse_optional_uuid(value, label) }
  end

  def ensure_exact_permutation!(submitted, current)
    if submitted.size != current.size || submitted.uniq.size != submitted.size || submitted.sort != current.sort
      raise Error.new("Submit every current resource exactly once.", code: :invalid)
    end
  end
end
