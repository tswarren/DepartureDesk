# frozen_string_literal: true

class SetCruiseSupplierOccupancyPlan < AgencyCommand
  include CostCommandSupport
  include CruiseSupplierRateBuilders

  def initialize(agency:, actor:, arrangement:, resource:, expected_cabins:,
    version_lock_version:, assumption_lock_version: nil)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @resource = resource
    @expected_cabins = expected_cabins.to_h.with_indifferent_access
    @version_lock_version = version_lock_version
    @assumption_lock_version = assumption_lock_version
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        arrangement = @agency.supplier_arrangements.find(@arrangement.id)
        version = arrangement.versions.find_by!(status: "draft")
        _item_def, _occ_def, resource_definition, item, occurrence, resource =
          resolve_cruise_rate_context!(arrangement, version, @resource.id)

        departure, arrangement, version, contractor = cost_graph!(arrangement)
        ensure_cost_ordinary_edit!(departure, arrangement, version, contractor)
        ensure_current_lock_version!(version, @version_lock_version)

        supported = CruiseSupplierRateSupport.occupancy_keys_for_maximum(resource_definition.maximum_occupancy)
        counts = {}
        supported.each do |key|
          raw = @expected_cabins[key]
          next if raw.blank?

          count = integer_or_nil(raw, "#{key.to_s.humanize} expected cabins", minimum: 1)
          counts[key] = count if count
        end
        unsupported = @expected_cabins.keys.map(&:to_sym) - supported - OCCUPANCY_PROFILE_SPECS.keys
        # ignore unknown blanks; reject unsupported occupancy keys with values
        @expected_cabins.each do |key, value|
          next if value.blank?
          next if supported.include?(key.to_sym)

          raise Error.new("#{key.to_s.humanize} is not supported for this cabin category.", code: :invalid)
        end

        category = ensure_traveler_category!(version, item: item)
        assumption = version.supplier_cost_usage_assumptions.lock.find_by(
          arrangement_item_id: item.id,
          service_occurrence_id: occurrence.id,
          supplier_resource_id: resource.id
        )

        before_snapshot = occupancy_snapshot(assumption)

        if assumption.nil?
          assumption = build_supplier_cost_usage_assumption_already_locked!(
            version: version,
            attributes: {
              arrangement_item_id: item.id,
              service_occurrence_id: occurrence.id,
              supplier_resource_id: resource.id,
              expected_resource_units: nil,
              expected_persons: nil,
              expected_billable_nights: nil
            }
          )
          audit_cost!("supplier_arrangement.cost_usage_assumption_created", arrangement, version, {
            "supplier_cost_usage_assumption_id" => assumption.id
          }.merge(
            "arrangement_item_id" => item.id,
            "service_occurrence_id" => occurrence.id,
            "supplier_resource_id" => resource.id
          ))
        else
          ensure_current_lock_version!(assumption, @assumption_lock_version) if @assumption_lock_version
          if assumption.expected_resource_units.present? || assumption.expected_persons.present?
            assumption.update!(expected_resource_units: nil, expected_persons: nil)
          end
        end

        existing = assumption.supplier_cost_occupancy_profiles.includes(
          :supplier_cost_occupancy_profile_positions
        ).order(:position, :id).lock.index_by(&:label)

        OCCUPANCY_PROFILE_SPECS.each do |key, spec|
          label = spec.fetch(:label)
          count = counts[key]
          profile = existing.delete(label)

          if count.nil?
            if profile
              profile.supplier_cost_occupancy_profile_positions.order(:id).lock.each(&:destroy!)
              profile.supplier_cost_occupancy_profile_positions.reset
              profile.destroy!
            end
            next
          end

          position_count = spec.fetch(:positions)
          if profile
            profile.update!(resource_unit_count: count)
            current = profile.supplier_cost_occupancy_profile_positions.order(:occupancy_position).pluck(:participant_category_id)
            desired = Array.new(position_count, category.id)
            if current != desired
              profile.supplier_cost_occupancy_profile_positions.order(:id).lock.each(&:destroy!)
              desired.each_with_index do |category_id, index|
                profile.supplier_cost_occupancy_profile_positions.create!(
                  owner_attributes_for(assumption).merge(
                    arrangement_item_id: item.id,
                    supplier_cost_usage_assumption: assumption,
                    participant_category_id: category_id,
                    occupancy_position: index + 1
                  )
                )
              end
            end
          else
            siblings = assumption.supplier_cost_occupancy_profiles.order(:position, :id).lock.to_a
            profile = assumption.supplier_cost_occupancy_profiles.create!(
              owner_attributes_for(assumption).merge(
                arrangement_item_id: item.id,
                label: label,
                resource_unit_count: count,
                position: siblings.map(&:position).max.to_i + 1
              )
            )
            position_count.times do |index|
              profile.supplier_cost_occupancy_profile_positions.create!(
                owner_attributes_for(assumption).merge(
                  arrangement_item_id: item.id,
                  supplier_cost_usage_assumption: assumption,
                  participant_category_id: category.id,
                  occupancy_position: index + 1
                )
              )
            end
          end
        end

        # Remove any leftover non-cruise profiles? Do not — leave advanced profiles alone,
        # but Cruise typed labels that are unsupported are already handled above.
        remaining = assumption.supplier_cost_occupancy_profiles.order(:position, :id).lock.to_a
        remaining.each_with_index do |profile, index|
          profile.update!(position: index + 1) if profile.position != index + 1
        end
        assumption.touch

        after_snapshot = occupancy_snapshot(assumption)
        if before_snapshot != after_snapshot
          clear_readiness_for_context!(version, item: item, occurrence: occurrence, resource: resource)
        end

        bump_version!(version)
        audit_cost!("supplier_arrangement.cost_occupancy_profile_updated", arrangement, version, {
          "supplier_cost_usage_assumption_id" => assumption.id,
          "cruise_occupancy_plan" => true,
          "expected_cabins" => counts.transform_keys(&:to_s)
        })
        AgencyCommand::Result.new(status: :updated, record: assumption.reload)
      end
    end
  end

  private

  def occupancy_snapshot(assumption)
    return [] if assumption.nil?

    assumption.supplier_cost_occupancy_profiles.order(:label).map do |profile|
      [
        profile.label,
        profile.resource_unit_count,
        profile.supplier_cost_occupancy_profile_positions.order(:occupancy_position).pluck(:participant_category_id)
      ]
    end
  end
end
