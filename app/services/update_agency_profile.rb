# frozen_string_literal: true

class UpdateAgencyProfile < AgencyCommand
  def initialize(agency:, actor:, name:, legal_name:, country_code:, default_currency:,
    default_timezone:, attention_warning_lead_days: :unchanged, lock_version: nil)
    @agency = agency
    @actor = actor
    @name = name
    @legal_name = legal_name
    @country_code = country_code
    @default_currency = default_currency
    @default_timezone = default_timezone
    @attention_warning_lead_days = attention_warning_lead_days
    @lock_version = lock_version
  end

  def call
    ActiveRecord::Base.transaction do
      @agency.with_lock do
        @agency.reload
        ensure_permitted!(@actor, :manage_agency_profile)
        ensure_fresh_lock!
        ensure_active_agency!(@agency)
        previous_lead = @agency.attention_warning_lead_days
        attrs = {
          name: @name,
          legal_name: @legal_name,
          country_code: @country_code,
          default_currency: @default_currency,
          default_timezone: @default_timezone
        }
        unless @attention_warning_lead_days == :unchanged
          attrs[:attention_warning_lead_days] = normalize_lead_days(@attention_warning_lead_days)
        end
        @agency.update!(attrs)
        if previous_lead != @agency.attention_warning_lead_days
          refresh_agency_deadline_projections!
        end
        audit!(
          agency: @agency,
          action: "agency.profile_updated",
          subject: @agency,
          actor: @actor,
          details: { "agency_id" => @agency.id }
        )
      end
    end
    Result.new(status: :accepted, record: @agency)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def ensure_fresh_lock!
    return if @lock_version.nil?
    return if @agency.lock_version == @lock_version.to_i

    raise Error.new("This agency was updated by someone else.", code: :conflict)
  end

  def normalize_lead_days(value)
    return nil if value.nil? || value.to_s.strip.empty?

    Integer(value)
  rescue ArgumentError, TypeError
    raise Error.new("Attention warning lead days must be a whole number of days.", code: :invalid)
  end

  def refresh_agency_deadline_projections!
    SupplierDeadlineOccurrence.where(agency_id: @agency.id, superseded_at: nil)
      .includes(:supplier_deadline_definition, :agency)
      .find_each do |occurrence|
      RefreshSupplierDeadlineProjection.call(occurrence:)
      arrangement = SupplierArrangement.find_by(
        id: occurrence.supplier_arrangement_id, agency_id: @agency.id
      )
      next if arrangement.nil?

      RebuildSupplierAttentionProjectionAlreadyLocked.new(
        agency: @agency,
        arrangement:,
        version: occurrence.supplier_arrangement_version
      ).call
    end
  end
end
