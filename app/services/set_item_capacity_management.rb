class SetItemCapacityManagement < AgencyCommand
  include CapacityCommandSupport

  def initialize(agency:, actor:, definition:, capacity_management:, lock_version:)
    @agency = agency
    @actor = actor
    @definition = definition
    @capacity_management = capacity_management.to_s.strip.presence
    @lock_version = lock_version
  end

  def call
    ensure_arrangement_actor!
    unless @capacity_management.nil? || ArrangementItemDefinition::CAPACITY_MANAGEMENT.include?(@capacity_management)
      raise Error.new("Choose a valid capacity management value.", code: :invalid)
    end

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      contractor = locked_supplier!(@definition.supplier_arrangement.contracting_supplier_id)
      departure, arrangement, version = lock_departure_arrangement_version!(@definition.supplier_arrangement)
      item = lock_arrangement_item_for!(arrangement, @definition.arrangement_item)
      definition = lock_item_definition_for!(version, @definition)
      ensure_draft_graph!(arrangement, version)
      ensure_capacity_management_transition!(departure, contractor, definition, @capacity_management)
      ensure_no_item_capacity_structure!(version, item) if @capacity_management == "unmanaged"
      ensure_current_lock_version!(definition)

      return Result.new(status: :noop, record: definition) if definition.capacity_management == @capacity_management

      previous = definition.capacity_management
      definition.update!(capacity_management: @capacity_management)
      audit!(
        agency: @agency,
        action: "supplier_arrangement.capacity_applicability_updated",
        subject: arrangement,
        actor: @actor,
        details: {
          "supplier_arrangement_id" => arrangement.id,
          "supplier_arrangement_version_id" => version.id,
          "arrangement_item_id" => item.id,
          "arrangement_item_definition_id" => definition.id,
          "previous_capacity_management" => previous,
          "capacity_management" => definition.capacity_management
        }
      )
      Result.new(status: :updated, record: definition)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
