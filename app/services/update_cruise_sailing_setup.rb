# frozen_string_literal: true

class UpdateCruiseSailingSetup < AgencyCommand
  include ArrangementCommandSupport

  SetupResult = Data.define(:arrangement, :item_definition, :occurrence_definition)

  def initialize(agency:, actor:, arrangement:, arrangement_attributes:, item_attributes:,
    occurrence_attributes:, arrangement_lock_version:, version_lock_version:,
    item_lock_version:, occurrence_lock_version:, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @arrangement_attributes = arrangement_attributes.to_h.with_indifferent_access
    @item_attributes = item_attributes.to_h.with_indifferent_access
    @occurrence_attributes = occurrence_attributes.to_h.with_indifferent_access
    @arrangement_lock_version = arrangement_lock_version
    @version_lock_version = version_lock_version
    @item_lock_version = item_lock_version
    @occurrence_lock_version = occurrence_lock_version
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    arrangement_name = normalize_arrangement_name(@arrangement_attributes[:name])

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      contractor = locked_supplier!(@arrangement.contracting_supplier_id)
      contact = resolve_optional_contact!(
        contractor,
        @arrangement_attributes[:supplier_contact_id]
      )
      departure, arrangement, version = lock_departure_arrangement_version!(@arrangement)
      ensure_ordinary_planning_edit!(departure, arrangement, version, contractor)

      item_definition = version.arrangement_item_definitions.lock.sole
      occurrence_definition = version.service_occurrence_definitions.lock.sole

      unless item_definition.category == "cruise"
        raise Error.new("That arrangement is not a Cruise sailing setup.", code: :invalid_state)
      end

      item_attrs = normalize_item_attributes(
        @item_attributes.merge(
          category: "cruise",
          other_category_label: nil,
          description: @item_attributes.fetch(:description, item_definition.description)
        )
      ).merge(
        capacity_management: item_definition.capacity_management,
        default_service_provider_id: item_definition.default_service_provider_id
      )
      occurrence_attrs = normalize_occurrence_attributes(
        @occurrence_attributes.merge(
          description: @occurrence_attributes.fetch(
            :description, occurrence_definition.description
          ),
          starts_at_local: @occurrence_attributes.fetch(
            :starts_at_local, occurrence_definition.starts_at_local
          ),
          ends_at_local: @occurrence_attributes.fetch(
            :ends_at_local, occurrence_definition.ends_at_local
          ),
          service_provider_id: occurrence_definition.service_provider_id
        ),
        departure
      ).merge(service_provider_id: occurrence_definition.service_provider_id)

      arrangement_attrs = { name: arrangement_name, supplier_contact_id: contact&.id }
      payload = {
        supplier_arrangement_id: arrangement.id,
        supplier_arrangement_version_id: version.id,
        arrangement: arrangement_attrs,
        item: item_attrs,
        occurrence: occurrence_attrs
      }

      if replay_optional_idempotency?(
        payload: payload,
        result_record_type: SupplierArrangement.name,
        result_record_id: arrangement.id
      )
        return Result.new(
          status: :replayed,
          record: SetupResult.new(
            arrangement: arrangement.reload,
            item_definition: item_definition.reload,
            occurrence_definition: occurrence_definition.reload
          )
        )
      end

      ensure_current_lock_version!(arrangement, @arrangement_lock_version)
      ensure_current_lock_version!(version, @version_lock_version)
      ensure_current_lock_version!(item_definition, @item_lock_version)
      ensure_current_lock_version!(occurrence_definition, @occurrence_lock_version)

      unchanged =
        same_values?(arrangement, arrangement_attrs) &&
        same_values?(item_definition, item_attrs) &&
        same_values?(occurrence_definition, occurrence_attrs)
      if unchanged
        claim_optional_idempotency!(
          payload: payload,
          result_record_type: SupplierArrangement.name,
          result_record_id: arrangement.id
        )
        return Result.new(
          status: :noop,
          record: SetupResult.new(
            arrangement: arrangement,
            item_definition: item_definition,
            occurrence_definition: occurrence_definition
          )
        )
      end

      arrangement.update!(arrangement_attrs) unless same_values?(arrangement, arrangement_attrs)
      item_definition.update!(item_attrs) unless same_values?(item_definition, item_attrs)
      unless same_values?(occurrence_definition, occurrence_attrs)
        occurrence_definition.update!(occurrence_attrs)
      end
      bump_version!(version)
      claim_optional_idempotency!(
        payload: payload,
        result_record_type: SupplierArrangement.name,
        result_record_id: arrangement.id
      )

      audit!(
        agency: @agency,
        action: "supplier_arrangement.updated",
        subject: arrangement,
        actor: @actor,
        details: {
          "supplier_arrangement_id" => arrangement.id,
          "supplier_arrangement_version_id" => version.id,
          "changed_fields" => changed_fields(arrangement, arrangement_attrs),
          "name" => arrangement.name,
          "supplier_contact_id" => arrangement.supplier_contact_id,
          "arrangement_item_definition_id" => item_definition.id,
          "service_occurrence_definition_id" => occurrence_definition.id,
          "item_changed_fields" => changed_fields(item_definition, item_attrs),
          "occurrence_changed_fields" => changed_fields(occurrence_definition, occurrence_attrs)
        }
      )

      Result.new(
        status: :updated,
        record: SetupResult.new(
          arrangement: arrangement,
          item_definition: item_definition,
          occurrence_definition: occurrence_definition
        )
      )
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  rescue ActiveRecord::RecordNotFound, Enumerable::SoleItemExpectedError
    raise Error.new("That arrangement is not a Cruise sailing setup.", code: :invalid_state)
  end

  private

  def replay_optional_idempotency?(payload:, result_record_type:, result_record_id:)
    return false if @idempotency_key.blank?

    key = normalize_idempotency_key(@idempotency_key)
    digest = payload_digest(payload)
    lock_idempotency_slot!(self.class.name, key)
    existing = AgencyCommandIdempotencyKey.where(
      agency: @agency,
      command_name: self.class.name,
      idempotency_key: key
    ).lock.first
    return false unless existing

    unless existing.payload_digest == digest &&
        existing.result_record_type == result_record_type &&
        existing.result_record_id == result_record_id
      raise Error.new("That idempotency key was already used for different input.", code: :conflict)
    end

    true
  end

  def claim_optional_idempotency!(payload:, result_record_type:, result_record_id:)
    return if @idempotency_key.blank?

    key = normalize_idempotency_key(@idempotency_key)
    digest = payload_digest(payload)
    AgencyCommandIdempotencyKey.create!(
      agency: @agency,
      command_name: self.class.name,
      idempotency_key: key,
      payload_digest: digest,
      result_record_type: result_record_type,
      result_record_id: result_record_id
    )
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("That idempotency key was already used for different input.", code: :conflict)
  end
end
