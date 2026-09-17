class BulkClassifyCapacityPairs < AgencyCommand
  include CapacityCommandSupport

  def initialize(agency:, actor:, item:, decisions:, version_lock_version:, idempotency_key:)
    @agency = agency
    @actor = actor
    @item = item
    @decisions = decisions
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    submitted_decisions = normalize_decisions(@decisions)

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      contractor = locked_supplier!(@item.supplier_arrangement.contracting_supplier_id)
      departure, arrangement, version = lock_departure_arrangement_version!(@item.supplier_arrangement)
      item = lock_arrangement_item_for!(arrangement, @item)
      ensure_capacity_ordinary_edit!(departure, arrangement, version, contractor)

      item_definition = version.arrangement_item_definitions.lock.find_by!(arrangement_item: item)
      ensure_managed_item!(item_definition)
      occurrences = item.service_occurrences.where(id: submitted_decisions.pluck(:service_occurrence_id))
        .order(:id).lock.index_by(&:id)
      resources = item.supplier_resources.where(id: submitted_decisions.pluck(:supplier_resource_id))
        .order(:id).lock.index_by(&:id)
      raise ActiveRecord::RecordNotFound unless occurrences.size == submitted_decisions.pluck(:service_occurrence_id).uniq.size
      raise ActiveRecord::RecordNotFound unless resources.size == submitted_decisions.pluck(:supplier_resource_id).uniq.size

      occurrence_definitions = version.service_occurrence_definitions
        .where(arrangement_item: item, service_occurrence_id: occurrences.keys)
        .order(:service_occurrence_id).lock.index_by(&:service_occurrence_id)
      resource_definitions = version.supplier_resource_definitions
        .where(arrangement_item: item, supplier_resource_id: resources.keys)
        .order(:supplier_resource_id).lock.index_by(&:supplier_resource_id)
      raise ActiveRecord::RecordNotFound unless occurrence_definitions.size == occurrences.size
      raise ActiveRecord::RecordNotFound unless resource_definitions.size == resources.size

      submitted_decisions.each { |decision| ensure_occurrence_accepts_capacity!(occurrences.fetch(decision[:service_occurrence_id])) }
      pairs = version.capacity_pair_definitions
        .where(arrangement_item: item)
        .where(service_occurrence_id: occurrences.keys, supplier_resource_id: resources.keys)
        .order(:service_occurrence_id, :supplier_resource_id, :id)
        .lock
        .index_by { |pair| [ pair.service_occurrence_id, pair.supplier_resource_id ] }

      payload = {
        supplier_arrangement_id: arrangement.id,
        supplier_arrangement_version_id: version.id,
        arrangement_item_id: item.id,
        decisions: submitted_decisions
      }
      key = normalize_idempotency_key(@idempotency_key)
      digest = payload_digest(payload)
      lock_idempotency_slot!(self.class.name, key)
      existing = AgencyCommandIdempotencyKey.where(
        agency: @agency, command_name: self.class.name, idempotency_key: key
      ).lock.first
      if existing
        raise Error.new("That idempotency key was already used for different input.", code: :conflict) unless existing.payload_digest == digest
        raise Error.new("That idempotency result is invalid.", code: :conflict) unless
          existing.result_record_type == SupplierArrangementVersion.name && existing.result_record_id == version.id

        return Result.new(status: :replayed, record: pairs_for_decisions(version, item, submitted_decisions))
      end

      ensure_current_lock_version!(version, @version_lock_version)
      changes = submitted_decisions.filter_map do |decision|
        occurrence = occurrences.fetch(decision[:service_occurrence_id])
        resource = resources.fetch(decision[:supplier_resource_id])
        pair = pairs[[ occurrence.id, resource.id ]]
        ensure_pair_has_no_pool_definitions!(pair) if pair && decision[:classification] == "not_applicable"
        classified, previous, status = classify_capacity_pair_already_locked!(
          departure: departure,
          arrangement: arrangement,
          version: version,
          item: item,
          occurrence: occurrence,
          resource: resource,
          classification: decision[:classification],
          pair: pair
        )
        next if status == :noop

        {
          pair: classified,
          previous_classification: previous,
          classification: classified.classification
        }
      end

      bump_version!(version) if changes.any?
      AgencyCommandIdempotencyKey.create!(
        agency: @agency,
        command_name: self.class.name,
        idempotency_key: key,
        payload_digest: digest,
        result_record_type: SupplierArrangementVersion.name,
        result_record_id: version.id
      )
      audit_bulk_classification!(arrangement, version, item, submitted_decisions, changes) if changes.any?
      Result.new(
        status: changes.any? ? :updated : :noop,
        record: pairs_for_decisions(version, item, submitted_decisions)
      )
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("That idempotency key was already used for different input.", code: :conflict)
  end

  private

  def normalize_decisions(decisions)
    entries = decisions.respond_to?(:to_unsafe_h) ? decisions.to_unsafe_h.values : decisions
    entries = entries.values if entries.is_a?(Hash)
    normalized = Array(entries).map do |decision|
      attrs = decision.to_h.with_indifferent_access
      classification = attrs[:classification].to_s.strip
      unless CapacityPairDefinition::CLASSIFICATIONS.include?(classification)
        raise Error.new("Choose a valid capacity classification for every reviewed pair.", code: :invalid)
      end
      {
        service_occurrence_id: parse_required_member_id(attrs[:service_occurrence_id], "Service occurrence"),
        supplier_resource_id: parse_required_member_id(attrs[:supplier_resource_id], "Supplier resource"),
        classification: classification
      }
    end
    raise Error.new("Select at least one capacity pair to classify.", code: :invalid) if normalized.empty?

    normalized.sort_by! { |decision| [ decision[:service_occurrence_id], decision[:supplier_resource_id] ] }
    member_keys = normalized.map { |decision| [ decision[:service_occurrence_id], decision[:supplier_resource_id] ] }
    if member_keys.uniq.size != member_keys.size
      raise Error.new("Each capacity pair can be submitted only once.", code: :invalid)
    end
    normalized
  end

  def parse_required_member_id(value, label)
    parse_optional_uuid(value, label).tap do |id|
      raise Error.new("#{label} is required.", code: :invalid) if id.blank?
    end
  end

  def pairs_for_decisions(version, item, decisions)
    clauses = decisions.map do |decision|
      "(service_occurrence_id = #{ActiveRecord::Base.connection.quote(decision[:service_occurrence_id])} AND " \
        "supplier_resource_id = #{ActiveRecord::Base.connection.quote(decision[:supplier_resource_id])})"
    end
    version.capacity_pair_definitions.where(arrangement_item: item).where(clauses.join(" OR "))
      .order(:service_occurrence_id, :supplier_resource_id, :id).to_a
  end

  def audit_bulk_classification!(arrangement, version, item, submitted_decisions, changes)
    audit!(
      agency: @agency,
      action: "supplier_arrangement.capacity_pairs_bulk_classified",
      subject: arrangement,
      actor: @actor,
      details: {
        "supplier_arrangement_id" => arrangement.id,
        "supplier_arrangement_version_id" => version.id,
        "arrangement_item_id" => item.id,
        "submitted_pair_count" => submitted_decisions.size,
        "changed_pair_count" => changes.size,
        "capacity_pair_definition_ids" => changes.map { |change| change[:pair].id },
        "decisions" => submitted_decisions.map do |decision|
          decision.stringify_keys
        end,
        "changes" => changes.map do |change|
          {
            "capacity_pair_definition_id" => change[:pair].id,
            "service_occurrence_id" => change[:pair].service_occurrence_id,
            "supplier_resource_id" => change[:pair].supplier_resource_id,
            "previous_classification" => change[:previous_classification],
            "classification" => change[:classification]
          }
        end
      }
    )
  end
end
