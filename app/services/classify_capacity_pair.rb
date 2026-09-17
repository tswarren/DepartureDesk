class ClassifyCapacityPair < AgencyCommand
  include CapacityCommandSupport

  def initialize(agency:, actor:, item:, service_occurrence:, supplier_resource:, classification:, version_lock_version:)
    @agency = agency
    @actor = actor
    @item = item
    @service_occurrence = service_occurrence
    @supplier_resource = supplier_resource
    @classification = classification.to_s.strip.presence
    @version_lock_version = version_lock_version
  end

  def call
    ensure_arrangement_actor!
    unless CapacityPairDefinition::CLASSIFICATIONS.include?(@classification)
      raise Error.new("Choose a valid capacity classification.", code: :invalid)
    end

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      contractor = locked_supplier!(@item.supplier_arrangement.contracting_supplier_id)
      departure, arrangement, version = lock_departure_arrangement_version!(@item.supplier_arrangement)
      item = lock_arrangement_item_for!(arrangement, @item)
      ensure_capacity_ordinary_edit!(departure, arrangement, version, contractor)
      ensure_current_lock_version!(version, @version_lock_version)

      item_definition, occurrence, = lock_exact_capacity_graph!(version, item, @service_occurrence, @supplier_resource)
      ensure_managed_item!(item_definition)
      ensure_occurrence_accepts_capacity!(occurrence)
      pair = lock_pair_by_members!(version, @service_occurrence, @supplier_resource)
      ensure_pair_has_no_pool_definitions!(pair) if pair && @classification == "not_applicable"

      pair, previous, status = classify_capacity_pair_already_locked!(
        departure: departure,
        arrangement: arrangement,
        version: version,
        item: item,
        occurrence: @service_occurrence,
        resource: @supplier_resource,
        classification: @classification,
        pair: pair
      )
      return Result.new(status: :noop, record: pair) if status == :noop

      bump_version!(version)
      audit!(
        agency: @agency,
        action: "supplier_arrangement.capacity_pair_classified",
        subject: arrangement,
        actor: @actor,
        details: {
          "supplier_arrangement_id" => arrangement.id,
          "supplier_arrangement_version_id" => version.id,
          "arrangement_item_id" => item.id,
          "capacity_pair_definition_id" => pair.id,
          "service_occurrence_id" => @service_occurrence.id,
          "supplier_resource_id" => @supplier_resource.id,
          "previous_classification" => previous,
          "classification" => pair.classification
        }
      )
      Result.new(status: status, record: pair)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
