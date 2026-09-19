# frozen_string_literal: true

class RefreshSupplierDeadlineProjection
  def self.call(occurrence:, at: Time.current)
    new(occurrence:, at:).call
  end

  def initialize(occurrence:, at: Time.current)
    @occurrence = occurrence
    @at = at
  end

  def call
    return if @occurrence.superseded_at.present?

    boundaries = compute_boundaries
    status = status_for(boundaries)
    attrs = {
      status:,
      due_on: boundaries[:due_on],
      due_at: boundaries[:due_at],
      warning_starts_at: boundaries[:warning_starts_at],
      overdue_at: boundaries[:overdue_at],
      refreshed_at: @at,
      next_transition_at: next_transition(boundaries, status)
    }

    projection = SupplierDeadlineProjection.find_by(
      supplier_deadline_occurrence_id: @occurrence.id
    )
    if projection
      projection.lock!
      projection.update!(attrs)
      projection
    else
      SupplierDeadlineProjection.create!(
        attrs.merge(
          agency_id: @occurrence.agency_id,
          departure_id: @occurrence.departure_id,
          supplier_arrangement_id: @occurrence.supplier_arrangement_id,
          supplier_arrangement_version_id: @occurrence.supplier_arrangement_version_id,
          supplier_deadline_occurrence: @occurrence
        )
      )
    end
  end

  private

  def compute_boundaries
    zone = ActiveSupport::TimeZone[@occurrence.time_zone] || Time.find_zone!("UTC")
    lead_days = @occurrence.supplier_deadline_definition.warning_lead_days
    if @occurrence.date_only?
      due_on = @occurrence.calculated_on
      due_start = zone.local(due_on.year, due_on.month, due_on.day)
      overdue_at = due_start + 1.day
      warning_starts_at = lead_days && lead_days.positive? ? due_start - lead_days.days : nil
      { due_on:, due_at: nil, warning_starts_at:, overdue_at: }
    else
      due_at = @occurrence.calculated_at
      overdue_at = due_at
      warning_starts_at = if lead_days && lead_days.positive?
        due_at - lead_days.days
      end
      { due_on: nil, due_at:, warning_starts_at:, overdue_at: }
    end
  end

  def status_for(boundaries)
    return "overdue" if @at >= boundaries[:overdue_at]
    if @occurrence.date_only?
      due_start = boundaries[:overdue_at] - 1.day
      return "due" if @at >= due_start
    elsif boundaries[:due_at] && @at >= boundaries[:due_at]
      return "due"
    end
    if boundaries[:warning_starts_at] && @at >= boundaries[:warning_starts_at]
      return "warning"
    end

    "upcoming"
  end

  def next_transition(boundaries, status)
    case status
    when "upcoming"
      boundaries[:warning_starts_at] || (
        @occurrence.date_only? ? boundaries[:overdue_at] - 1.day : boundaries[:due_at]
      )
    when "warning"
      @occurrence.date_only? ? boundaries[:overdue_at] - 1.day : boundaries[:due_at]
    when "due"
      boundaries[:overdue_at]
    end
  end
end
