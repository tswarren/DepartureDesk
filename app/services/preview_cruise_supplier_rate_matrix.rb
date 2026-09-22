# frozen_string_literal: true

# Draft-only evaluation of an unsaved Cruise Supplier rate matrix.
# Compiles through the shipped create/update path inside a rolled-back
# transaction so M3C forecast math stays authoritative (2A.2R2 §9).
class PreviewCruiseSupplierRateMatrix
  Result = Data.define(:ok?, :error, :preview)

  def initialize(
    agency:,
    actor:,
    arrangement:,
    resource:,
    profiles:,
    cells:,
    custom_rows:,
    commission:,
    overlap_resolution: nil,
    stage: "estimate",
    notes: nil,
    convert_legacy: nil,
    version_lock_version:,
    definition_lock_version: nil,
    empty_schedule:
  )
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @resource = resource
    @profiles = profiles
    @cells = cells
    @custom_rows = custom_rows
    @commission = commission
    @overlap_resolution = overlap_resolution
    @stage = stage
    @notes = notes
    @convert_legacy = convert_legacy
    @version_lock_version = version_lock_version
    @definition_lock_version = definition_lock_version
    @empty_schedule = empty_schedule
  end

  def call
    preview = nil

    ActiveRecord::Base.transaction(requires_new: true) do
      if @empty_schedule
        CreateCruiseSupplierRateSchedule.new(
          agency: @agency,
          actor: @actor,
          arrangement: @arrangement,
          resource: @resource,
          profiles: @profiles,
          cells: @cells,
          custom_rows: @custom_rows,
          overlap_resolution: @overlap_resolution,
          commission: @commission,
          stage: @stage.presence || "estimate",
          notes: @notes,
          version_lock_version: @version_lock_version,
          idempotency_key: "preview-#{SecureRandom.uuid}"
        ).call
      else
        UpdateCruiseSupplierRateSchedule.new(
          agency: @agency,
          actor: @actor,
          arrangement: @arrangement,
          resource: @resource,
          profiles: @profiles,
          cells: @cells,
          custom_rows: @custom_rows,
          overlap_resolution: @overlap_resolution,
          commission: @commission,
          stage: @stage,
          notes: @notes,
          convert_legacy: @convert_legacy,
          version_lock_version: @version_lock_version,
          definition_lock_version: @definition_lock_version,
          idempotency_key: "preview-#{SecureRandom.uuid}"
        ).call
      end

      preview = CompileCruiseSupplierRatePreview.new(
        agency: @agency,
        arrangement: @arrangement,
        resource: @resource,
        version: @arrangement.versions.order(:version_number).last
      ).call

      raise ActiveRecord::Rollback
    end

    Result.new(ok?: true, error: nil, preview: preview)
  rescue AgencyCommand::Error => error
    Result.new(ok?: false, error: error.message, preview: nil)
  end
end
