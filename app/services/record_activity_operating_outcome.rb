# frozen_string_literal: true

class RecordActivityOperatingOutcome < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, arrangement:, item:, outcome:, evidence:, occurred_on:,
    observed_quantity:, idempotency_key:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @item = item
    @outcome = outcome
    @evidence = evidence
    @occurred_on = occurred_on
    @observed_quantity = observed_quantity
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      arrangement = lock_arrangement_for!(@arrangement)
      version = arrangement.governing_version
      threshold = version&.supplier_operating_threshold_definitions&.find_by(arrangement_item: @item)
      unless arrangement.active? && version && SupplierConfirmation.exists?(supplier_arrangement_version_id: version.id) && threshold
        raise Error.new(
          "Record the Supplier decision on the Supplier-confirmed governing Activity agreement.",
          code: :invalid_state
        )
      end
      occurrence = @item.service_occurrences.order(:created_at).first
      raise Error.new("Choose operate or cancel.", code: :invalid) unless %w[operate cancel].include?(@outcome.to_s)
      raise Error.new("Enter the Supplier evidence.", code: :invalid) if @evidence.to_s.strip.blank?

      idempotent_create!(
        command_name: self.class.name, idempotency_key: @idempotency_key,
        payload: {
          supplier_operating_threshold_definition_id: threshold.id,
          outcome: @outcome, evidence: @evidence.to_s.strip
        },
        result_class: SupplierOperatingThresholdOutcome
      ) do
        record = SupplierOperatingThresholdOutcome.create!(
          agency: @agency, departure: arrangement.departure, supplier_arrangement: arrangement,
          arrangement_item: @item, service_occurrence: occurrence,
          supplier_operating_threshold_definition: threshold,
          outcome: @outcome, evidence: @evidence.to_s.strip,
          observed_quantity: observed_quantity, occurred_on: @occurred_on.presence || Date.current,
          recorded_by: @actor, recorded_at: Time.current
        )
        audit!(
          agency: @agency, action: "supplier_arrangement.activity_outcome_recorded",
          subject: arrangement, actor: @actor,
          details: {
            "supplier_arrangement_id" => arrangement.id,
            "arrangement_item_id" => @item.id,
            "supplier_operating_threshold_outcome_id" => record.id,
            "outcome" => record.outcome
          }
        )
        record
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def observed_quantity
    raw = @observed_quantity.presence
    raw && Integer(raw)
  end
end
