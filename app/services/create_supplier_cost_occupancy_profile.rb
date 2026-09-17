class CreateSupplierCostOccupancyProfile < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, assumption:, attributes:, assumption_lock_version:, positions: nil,
    participant_positions: nil, idempotency_key: nil)
    @agency, @actor, @assumption = agency, actor, assumption
    @attributes = attributes.to_h.with_indifferent_access
    @positions = positions || participant_positions || @attributes.delete(:positions) ||
      @attributes.delete(:participant_positions) || []
    @assumption_lock_version = assumption_lock_version
    @idempotency_key = idempotency_key || @attributes.delete(:idempotency_key)
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        departure, arrangement, version, contractor = cost_graph!(@assumption)
        ensure_cost_ordinary_edit!(departure, arrangement, version, contractor)
        assumption = version.supplier_cost_usage_assumptions.lock.find(@assumption.id)
        attrs = profile_attributes
        positions = normalized_positions(version, assumption)
        idempotent_create!(
          command_name: self.class.name, idempotency_key: @idempotency_key,
          payload: attrs.merge(positions: positions, supplier_cost_usage_assumption_id: assumption.id),
          result_class: SupplierCostOccupancyProfile
        ) do
          ensure_current_lock_version!(assumption, @assumption_lock_version)
          reject_competing_scalars!(assumption)
          siblings = assumption.supplier_cost_occupancy_profiles.order(:position, :id).lock.to_a
          profile = assumption.supplier_cost_occupancy_profiles.create!(
            attrs.merge(owner_attributes_for(assumption), arrangement_item_id: assumption.arrangement_item_id,
                        position: siblings.map(&:position).max.to_i + 1)
          )
          create_positions!(profile, assumption, positions)
          assumption.touch
          audit_cost!("supplier_arrangement.cost_occupancy_profile_created", arrangement, version, {
            "supplier_cost_usage_assumption_id" => assumption.id,
            "supplier_cost_occupancy_profile_id" => profile.id,
            "arrangement_item_id" => assumption.arrangement_item_id,
            "label" => profile.label, "resource_unit_count" => profile.resource_unit_count,
            "position" => profile.position, "positions" => positions
          })
          profile
        end
      end
    end
  end

  private

  def profile_attributes
    {
      label: normalize_text(@attributes[:label], "Label", SupplierCostOccupancyProfile::LABEL_LIMIT),
      resource_unit_count: integer_or_nil(@attributes[:resource_unit_count], "Resource unit count", minimum: 1)
    }
  end

  def normalized_positions(version, assumption)
    values = Array(@positions).map.with_index do |entry, index|
      id = entry.respond_to?(:to_h) ? entry.to_h.with_indifferent_access[:participant_category_id] : entry
      id = required_uuid(id, "Participant category")
      version.supplier_cost_participant_categories.find_by!(id: id, arrangement_item_id: assumption.arrangement_item_id)
      { participant_category_id: id, occupancy_position: index + 1 }
    end
    raise Error.new("Add at least one occupancy position.", code: :invalid) if values.empty?
    values
  end

  def reject_competing_scalars!(assumption)
    return if assumption.expected_resource_units.nil? && assumption.expected_persons.nil?
    raise Error.new("Clear resource-unit and person totals before adding occupancy profiles.", code: :invalid)
  end

  def create_positions!(profile, assumption, positions)
    positions.each do |entry|
      profile.supplier_cost_occupancy_profile_positions.create!(
        entry.merge(owner_attributes_for(assumption), arrangement_item_id: assumption.arrangement_item_id,
                    supplier_cost_usage_assumption: assumption)
      )
    end
  end
end
