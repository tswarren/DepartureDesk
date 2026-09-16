class ReorderArrangementItems < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, arrangement:, arrangement_item_ids:, version_lock_version:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @arrangement_item_ids = arrangement_item_ids
    @version_lock_version = version_lock_version
  end

  def call
    ensure_arrangement_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      contractor = locked_supplier!(@arrangement.contracting_supplier_id)
      departure, arrangement, version = lock_departure_arrangement_version!(@arrangement)
      ensure_ordinary_planning_edit!(departure, arrangement, version, contractor)
      ensure_current_lock_version!(version, @version_lock_version)

      definitions = version.arrangement_item_definitions.order(:position, :id).lock.to_a
      ordered_ids = normalized_id_list(@arrangement_item_ids, "Arrangement item")
      ensure_exact_permutation!(ordered_ids, definitions.map { |definition| definition.arrangement_item_id })
      definitions_by_item_id = definitions.index_by(&:arrangement_item_id)
      old_positions = ordered_position_map(definitions, :arrangement_item_id)

      ordered_ids.each_with_index do |item_id, index|
        definitions_by_item_id.fetch(item_id).update!(position: index + 1)
      end
      ActiveRecord::Base.connection.execute("SET CONSTRAINTS arrangement_item_definitions_position_unique IMMEDIATE")
      bump_version!(version)
      new_positions = {}
      ordered_ids.each_with_index { |item_id, index| new_positions[item_id] = index + 1 }
      audit!(
        agency: @agency,
        action: "supplier_arrangement.items_reordered",
        subject: arrangement,
        actor: @actor,
        details: {
          "child_type" => "arrangement_item",
          "supplier_arrangement_id" => arrangement.id,
          "supplier_arrangement_version_id" => version.id,
          "arrangement_item_ids" => ordered_ids,
          "old_positions" => old_positions,
          "new_positions" => new_positions
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
      raise Error.new("Submit every current item exactly once.", code: :invalid)
    end
  end

  def ordered_position_map(definitions, id_method)
    definitions.each_with_object({}) do |definition, map|
      map[definition.public_send(id_method)] = definition.position
    end
  end
end
