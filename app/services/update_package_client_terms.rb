# frozen_string_literal: true

class UpdatePackageClientTerms < AgencyCommand
  include PackageCommandSupport

  def initialize(agency:, actor:, package:, attributes:, version_lock_version:)
    @agency = agency
    @actor = actor
    @package = package
    @attributes = attributes.to_h.with_indifferent_access
    @version_lock_version = version_lock_version
  end

  def call
    ensure_offer_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      departure, package, version = lock_departure_package_draft!(@package)
      ensure_package_draft_editable!(departure, package, version)
      ensure_current_lock_version!(version, @version_lock_version)
      apply_window_and_caps!(version)
      replace_payment!(version, package, departure)
      replace_cancellation!(version, package, departure)
      replace_conditions!(version, package, departure)
      replace_resolutions!(version, package, departure)
      bump_version!(version)
      audit!(
        agency: @agency, action: "package.terms_updated", subject: package, actor: @actor,
        details: package_audit_details(package, version)
      )
      Result.new(status: :updated, record: package.reload)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def apply_window_and_caps!(version)
    starts = @attributes[:sales_starts_on]
    ends = @attributes[:sales_ends_on]
    version.sales_starts_on = starts.presence
    version.sales_ends_on = ends.presence
    version.sales_cap_quantity = @attributes[:sales_cap_quantity].presence
    version.sales_cap_basis = @attributes[:sales_cap_basis].presence
    version.save!
  end

  def replace_payment!(version, package, departure)
    PackageClientPaymentScheduleLine.where(package_version_id: version.id).delete_all
    PackageClientPaymentSchedule.where(package_version_id: version.id).delete_all
    lines = Array(@attributes[:payment_lines]).map { |row| row.to_h.with_indifferent_access }.reject { |row| row[:due_kind].blank? }
    return if lines.empty?

    schedule = version.create_payment_schedule!(agency: @agency, departure: departure, package: package)
    lines.each_with_index do |raw, index|
      attrs = raw.to_h.with_indifferent_access
      schedule.lines.create!(
        agency: @agency, departure: departure, package: package, package_version: version,
        position: index + 1,
        due_kind: attrs[:due_kind],
        due_on: attrs[:due_on],
        milestone_name: attrs[:milestone_name],
        amount_kind: attrs[:amount_kind],
        amount_minor_units: attrs[:amount_minor_units],
        percent_rate: attrs[:percent_rate],
        percent_base: attrs[:amount_kind].to_s == "percent" ? "selected_client_price" : nil
      )
    end
  end

  def replace_cancellation!(version, package, departure)
    PackageClientCancellationTier.where(package_version_id: version.id).delete_all
    PackageClientCancellationPolicy.where(package_version_id: version.id).delete_all
    tiers = Array(@attributes[:cancellation_tiers]).map { |row| row.to_h.with_indifferent_access }.reject { |row| row[:consequence_kind].blank? }
    return if tiers.empty?

    policy = version.create_cancellation_policy!(agency: @agency, departure: departure, package: package)
    tiers.each_with_index do |raw, index|
      attrs = raw.to_h.with_indifferent_access
      policy.tiers.create!(
        agency: @agency, departure: departure, package: package, package_version: version,
        position: index + 1,
        threshold_kind: attrs[:threshold_kind],
        threshold_on: attrs[:threshold_on],
        days_before: attrs[:days_before],
        consequence_kind: attrs[:consequence_kind],
        amount_minor_units: attrs[:amount_minor_units],
        percent_rate: attrs[:percent_rate],
        percent_base: attrs[:consequence_kind].to_s == "percent" ? "selected_client_price" : nil,
        summary: attrs[:summary]
      )
    end
  end

  def replace_conditions!(version, package, departure)
    PackageClientStatedCondition.where(package_version_id: version.id).delete_all
    Array(@attributes[:stated_conditions]).each_with_index do |raw, index|
      attrs = raw.to_h.with_indifferent_access
      next if attrs[:body].to_s.strip.blank?

      version.stated_conditions.create!(
        agency: @agency, departure: departure, package: package,
        position: index + 1, condition_kind: attrs[:condition_kind], body: attrs[:body]
      )
    end
  end

  def replace_resolutions!(version, package, departure)
    PackageClientTermResolution.where(package_version_id: version.id).delete_all
    Array(@attributes[:resolutions]).each do |raw|
      attrs = raw.to_h.with_indifferent_access
      next if attrs[:kind].blank? || attrs[:service_offer_version_id].blank?

      version.term_resolutions.create!(
        agency: @agency, departure: departure, package: package,
        kind: attrs[:kind],
        service_offer_version_id: attrs[:service_offer_version_id],
        governing_side: attrs[:governing_side],
        reason: attrs[:reason]
      )
    end
  end
end
