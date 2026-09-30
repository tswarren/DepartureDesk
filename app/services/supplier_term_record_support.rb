# frozen_string_literal: true

module SupplierTermRecordSupport
  extend ActiveSupport::Concern

  include CostCommandSupport

  private

  def lock_term_item!(item)
    found = @agency.arrangement_items.find(item.is_a?(ArrangementItem) ? item.id : item)
    departure, arrangement, version = lock_departure_arrangement_version!(found.supplier_arrangement)
    locked_item = arrangement.arrangement_items.lock.find(found.id)
    version.arrangement_item_definitions.lock.find_by!(arrangement_item_id: locked_item.id)
    [ departure, arrangement, version, locked_item ]
  end

  def lock_version_occurrence!(version, item, id)
    occurrence = item.service_occurrences.lock.find(id)
    version.service_occurrence_definitions.lock.find_by!(service_occurrence_id: occurrence.id)
    occurrence
  end

  def lock_version_resource!(version, item, id)
    resource = item.supplier_resources.lock.find(id)
    version.supplier_resource_definitions.lock.find_by!(supplier_resource_id: resource.id)
    resource
  end

  def term_owner(version, item)
    {
      agency: @agency,
      departure_id: version.departure_id,
      supplier_arrangement_id: version.supplier_arrangement_id,
      supplier_arrangement_version: version,
      arrangement_item: item
    }
  end

  def integer_value!(value, label)
    text = value.to_s.strip
    unless text.match?(/\A-?\d+\z/)
      raise AgencyCommand::Error.new("#{label} must be a whole number.", code: :invalid)
    end

    Integer(text, 10)
  end

  def sorted_rows(rows)
    Array(rows).map { |row| row.to_h.deep_stringify_keys }
  end

  def replay_recorded!(result_class, payload)
    return if @idempotency_key.blank?

    key = normalize_idempotency_key(@idempotency_key)
    digest = payload_digest(payload)
    lock_idempotency_slot!(self.class.name, key)
    existing = AgencyCommandIdempotencyKey.where(
      agency: @agency, command_name: self.class.name, idempotency_key: key
    ).lock.first
    return unless existing
    unless existing.payload_digest == digest
      raise AgencyCommand::Error.new("That idempotency key was already used for different input.", code: :conflict)
    end

    AgencyCommand::Result.new(status: :replayed, record: result_class.find(existing.result_record_id))
  end
end
