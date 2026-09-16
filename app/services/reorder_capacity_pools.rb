class ReorderCapacityPools < AgencyCommand
  include CapacityCommandSupport

  def initialize(agency:, actor:, pair:, capacity_pool_ids:, version_lock_version:)
    @agency = agency
    @actor = actor
    @pair = pair
    @capacity_pool_ids = capacity_pool_ids
    @version_lock_version = version_lock_version
  end

  def call
    ensure_arrangement_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      contractor = locked_supplier!(@pair.supplier_arrangement.contracting_supplier_id)
      departure, arrangement, version = lock_departure_arrangement_version!(@pair.supplier_arrangement)
      ensure_capacity_ordinary_edit!(departure, arrangement, version, contractor)
      ensure_current_lock_version!(version, @version_lock_version)
      pair = lock_pair_for!(version, @pair)
      definitions = lock_current_pool_definitions_for!(version, pair)
      ordered_ids = normalized_capacity_pool_id_list(@capacity_pool_ids)
      current_ids = definitions.map(&:capacity_pool_id)
      ensure_exact_pool_permutation!(ordered_ids, current_ids)

      old_positions = definitions.each_with_object({}) do |definition, map|
        map[definition.capacity_pool_id] = definition.position
      end
      definitions_by_pool_id = definitions.index_by(&:capacity_pool_id)
      ordered_ids.each_with_index do |pool_id, index|
        definitions_by_pool_id.fetch(pool_id).update!(position: index + 1)
      end
      ActiveRecord::Base.connection.execute("SET CONSTRAINTS capacity_pool_defs_position_unique IMMEDIATE")
      bump_version!(version)
      new_positions = {}
      ordered_ids.each_with_index { |pool_id, index| new_positions[pool_id] = index + 1 }
      audit!(
        agency: @agency,
        action: "supplier_arrangement.capacity_pools_reordered",
        subject: arrangement,
        actor: @actor,
        details: {
          "supplier_arrangement_id" => arrangement.id,
          "supplier_arrangement_version_id" => version.id,
          "arrangement_item_id" => pair.arrangement_item_id,
          "capacity_pair_definition_id" => pair.id,
          "capacity_pool_ids" => ordered_ids,
          "old_positions" => old_positions,
          "new_positions" => new_positions
        }
      )
      Result.new(status: :updated, record: pair)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def ensure_exact_pool_permutation!(submitted, current)
    if submitted.size != current.size || submitted.uniq.size != submitted.size || submitted.sort != current.sort
      raise Error.new("Submit every current capacity pool exactly once.", code: :invalid)
    end
  end
end
