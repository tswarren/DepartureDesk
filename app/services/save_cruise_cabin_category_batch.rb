# frozen_string_literal: true

# UI orchestration only. Each row is its own CreateCruiseCabinCategorySetup.
# This object does not open a transaction, so an earlier success stays saved
# when a later row fails.
class SaveCruiseCabinCategoryBatch
  INVENTORY_MODES = %w[block on_request externally_managed].freeze

  Row = Data.define(
    :idempotency_key,
    :supplier_code,
    :name,
    :maximum_occupancy,
    :inventory_mode,
    :proposed_opening_quantity
  ) do
    def blank_row?
      [ supplier_code, name, maximum_occupancy, proposed_opening_quantity ].all? { |value| value.to_s.strip.blank? }
    end

    def label
      supplier_code.to_s.strip.presence || name.to_s.strip.presence
    end
  end

  Result = Data.define(:status, :saved_count, :unresolved_rows, :error_message, :version_lock_version) do
    def saved?
      status == :saved
    end
  end

  def self.blank_row
    Row.new(
      idempotency_key: SecureRandom.uuid,
      supplier_code: nil,
      name: nil,
      maximum_occupancy: nil,
      inventory_mode: "block",
      proposed_opening_quantity: nil
    )
  end

  def initialize(agency:, actor:, arrangement:, rows:, version_lock_version:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @rows = Array(rows).map { |row| coerce_row(row) }
    @version_lock_version = version_lock_version
  end

  def call
    rows = @rows.map { |row| row.idempotency_key.present? ? row : row.with(idempotency_key: SecureRandom.uuid) }
    nonempty = rows.reject(&:blank_row?)
    if nonempty.empty?
      return invalid("Enter at least one cabin category.", rows.presence || [ self.class.blank_row ])
    end

    messages = validation_messages(nonempty)
    return invalid(messages.join(" "), nonempty) if messages.any?

    arrangement = @agency.supplier_arrangements.find(@arrangement.id)
    version = arrangement.versions.find_by(status: "draft")
    lock = @version_lock_version
    saved = 0

    nonempty.each_with_index do |row, index|
      CreateCruiseCabinCategorySetup.new(
        agency: @agency,
        actor: @actor,
        arrangement: @arrangement,
        resource_attributes: {
          name: row.name.to_s.strip,
          supplier_code: row.supplier_code.to_s.strip.presence,
          maximum_occupancy: row.maximum_occupancy.to_s.strip.presence
        },
        pool_attributes: {
          inventory_mode: row.inventory_mode,
          proposed_opening_quantity: row.proposed_opening_quantity.to_s.strip.presence
        },
        version_lock_version: lock,
        idempotency_key: row.idempotency_key
      ).call
      saved += 1
      lock = version.reload.lock_version if version
    rescue AgencyCommand::Error => error
      label = row.label || "Row #{index + 1}"
      return Result.new(
        status: :partial,
        saved_count: saved,
        unresolved_rows: nonempty[index..],
        error_message: "#{label} could not be saved. #{error.message}",
        version_lock_version: lock
      )
    end

    Result.new(
      status: :saved,
      saved_count: saved,
      unresolved_rows: [],
      error_message: nil,
      version_lock_version: lock
    )
  end

  private

  def invalid(message, rows)
    Result.new(
      status: :invalid,
      saved_count: 0,
      unresolved_rows: rows,
      error_message: message,
      version_lock_version: @version_lock_version
    )
  end

  def validation_messages(rows)
    messages = []
    rows.each_with_index do |row, index|
      label = row.label || "Row #{index + 1}"
      messages << "#{label} needs a category name." if row.name.to_s.strip.blank?
      unless INVENTORY_MODES.include?(row.inventory_mode.to_s)
        messages << "#{label} needs an inventory choice of Fixed block, On request, or Externally managed."
      end
      if row.inventory_mode.to_s == "block" && !positive_integer?(row.proposed_opening_quantity)
        messages << "#{label} needs a cabin quantity."
      end
      if row.maximum_occupancy.to_s.strip.present? && !positive_integer?(row.maximum_occupancy)
        messages << "#{label} needs a whole number for how many people it sleeps."
      end
    end
    messages
  end

  def positive_integer?(value)
    value.to_s.strip.match?(/\A[1-9]\d*\z/)
  end

  def coerce_row(row)
    return row if row.is_a?(Row)

    attributes = row.to_h.with_indifferent_access
    Row.new(
      idempotency_key: attributes[:idempotency_key].to_s.strip.presence,
      supplier_code: attributes[:supplier_code],
      name: attributes[:name],
      maximum_occupancy: attributes[:maximum_occupancy],
      inventory_mode: attributes[:inventory_mode].presence || "block",
      proposed_opening_quantity: attributes[:proposed_opening_quantity]
    )
  end
end
