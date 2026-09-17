class UpdateSupplierCostOccupancyProfile < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, profile:, attributes:, lock_version:, positions: nil, participant_positions: nil)
    @agency, @actor, @profile = agency, actor, profile
    @attributes = attributes.to_h.with_indifferent_access
    @positions_supplied = !positions.nil? || !participant_positions.nil? ||
      @attributes.key?(:positions) || @attributes.key?(:participant_positions)
    @positions = positions || participant_positions || @attributes.delete(:positions) ||
      @attributes.delete(:participant_positions) || []
    @lock_version = lock_version
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        departure, arrangement, version, contractor = cost_graph!(@profile)
        ensure_cost_ordinary_edit!(departure, arrangement, version, contractor)
        assumption = version.supplier_cost_usage_assumptions.lock.find(@profile.supplier_cost_usage_assumption_id)
        profile = assumption.supplier_cost_occupancy_profiles.lock.find(@profile.id)
        ensure_current_lock_version!(profile, @lock_version)
        attrs = {
          label: normalize_text(@attributes.fetch(:label, profile.label), "Label", SupplierCostOccupancyProfile::LABEL_LIMIT),
          resource_unit_count: integer_or_nil(
            @attributes.fetch(:resource_unit_count, profile.resource_unit_count), "Resource unit count", minimum: 1
          )
        }
        positions = normalized_positions(version, assumption)
        current_positions = profile.supplier_cost_occupancy_profile_positions.order(:occupancy_position).pluck(:participant_category_id)
        changed_positions = @positions_supplied && positions.map { |entry| entry[:participant_category_id] } != current_positions
        return Result.new(status: :noop, record: profile) if same_values?(profile, attrs) && !changed_positions
        profile.update!(attrs)
        if changed_positions
          profile.supplier_cost_occupancy_profile_positions.order(:id).lock.each(&:destroy!)
          create_positions!(profile, assumption, positions)
        end
        assumption.touch
        audit_cost!("supplier_arrangement.cost_occupancy_profile_updated", arrangement, version, {
          "supplier_cost_usage_assumption_id" => assumption.id,
          "supplier_cost_occupancy_profile_id" => profile.id,
          "changed_fields" => changed_fields(profile, attrs) + (changed_positions ? [ "positions" ] : []),
          "label" => profile.label, "resource_unit_count" => profile.resource_unit_count,
          "positions" => positions
        })
        Result.new(status: :updated, record: profile)
      end
    end
  end

  private

  def normalized_positions(version, assumption)
    return [] unless @positions_supplied
    values = Array(@positions).map.with_index do |entry, index|
      id = entry.respond_to?(:to_h) ? entry.to_h.with_indifferent_access[:participant_category_id] : entry
      id = required_uuid(id, "Participant category")
      version.supplier_cost_participant_categories.find_by!(id: id, arrangement_item_id: assumption.arrangement_item_id)
      { participant_category_id: id, occupancy_position: index + 1 }
    end
    raise Error.new("Add at least one occupancy position.", code: :invalid) if values.empty?
    values
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
