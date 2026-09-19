# frozen_string_literal: true

class SupplierDeadlineRuleEvaluator
  UnsupportedRule = Class.new(StandardError)

  SIMPLE_SHAPES = %w[
    fixed_date fixed_local_datetime days_before_departure days_after_departure
    hours_before_departure hours_after_departure
  ].freeze
  MILESTONE_SHAPE = "planning_milestone"
  MILESTONE_KINDS = SupplierPlanningMilestoneOccurrence::KINDS

  def self.call(definition:, departure:, at: Time.current, allow_milestones: false,
    unresolved_milestone_policy: :reject, milestone_occurrences: [])
    new(
      definition:, departure:, at:, allow_milestones:,
      unresolved_milestone_policy:, milestone_occurrences:
    ).call
  end

  def initialize(definition:, departure:, at: Time.current, allow_milestones: false,
    unresolved_milestone_policy: :reject, milestone_occurrences: [])
    @definition = definition
    @departure = departure
    @at = at
    @allow_milestones = allow_milestones
    @unresolved_milestone_policy = unresolved_milestone_policy.to_sym
    @milestone_occurrences = Array(milestone_occurrences)
  end

  def call
    result = evaluate_shape(@definition.rule_shape, @definition.rule_parameters)
    {
      calculated_on: result[:calculated_on],
      calculated_at: result[:calculated_at],
      rule_inputs_snapshot: result[:inputs]
    }
  end

  private

  def evaluate_shape(shape, parameters)
    params = (parameters || {}).with_indifferent_access
    case shape.to_s
    when "fixed_date"
      date = parse_date!(params[:date], "Fixed date")
      { calculated_on: date, calculated_at: nil, inputs: { "date" => date.iso8601 } }
    when "fixed_local_datetime"
      instant = parse_local_datetime!(params[:datetime], "Fixed local datetime")
      { calculated_on: nil, calculated_at: instant, inputs: { "datetime" => instant.iso8601 } }
    when "days_before_departure"
      days = positive_integer!(params[:days], "Days before departure")
      date = @departure.starts_on - days
      {
        calculated_on: date, calculated_at: nil,
        inputs: { "days" => days, "departure_starts_on" => @departure.starts_on.iso8601 }
      }
    when "days_after_departure"
      days = nonnegative_integer!(params[:days], "Days after departure")
      date = @departure.starts_on + days
      {
        calculated_on: date, calculated_at: nil,
        inputs: { "days" => days, "departure_starts_on" => @departure.starts_on.iso8601 }
      }
    when "hours_before_departure"
      hours = positive_integer!(params[:hours], "Hours before departure")
      anchor = departure_local_start
      instant = anchor - hours.hours
      {
        calculated_on: nil, calculated_at: instant,
        inputs: {
          "hours" => hours,
          "departure_starts_on" => @departure.starts_on.iso8601,
          "departure_time_zone" => @departure.time_zone
        }
      }
    when "hours_after_departure"
      hours = nonnegative_integer!(params[:hours], "Hours after departure")
      anchor = departure_local_start
      instant = anchor + hours.hours
      {
        calculated_on: nil, calculated_at: instant,
        inputs: {
          "hours" => hours,
          "departure_starts_on" => @departure.starts_on.iso8601,
          "departure_time_zone" => @departure.time_zone
        }
      }
    when MILESTONE_SHAPE
      evaluate_milestone(params)
    when "earlier_of", "later_of"
      evaluate_composite(shape.to_s, params)
    else
      raise UnsupportedRule, "Unsupported deadline rule shape #{shape}"
    end
  end

  def evaluate_milestone(params)
    unless @allow_milestones
      raise UnsupportedRule, "Milestone anchors are not supported in M3E.2"
    end

    kind = params[:kind].to_s
    unless MILESTONE_KINDS.include?(kind)
      raise UnsupportedRule, "Unsupported planning milestone kind #{kind}"
    end

    occurrence = @milestone_occurrences
      .select { |row| row.kind == kind }
      .max_by { |row| [ row.recorded_at, row.id ] }

    if occurrence.nil?
      case @unresolved_milestone_policy
      when :use_other_arm
        return {
          calculated_on: nil, calculated_at: nil,
          inputs: { "milestone_kind" => kind, "resolved" => false },
          unresolved_milestone: true
        }
      else
        raise UnsupportedRule, "Planning milestone #{kind} has not been recorded"
      end
    end

    if occurrence.occurred_on.present?
      {
        calculated_on: occurrence.occurred_on, calculated_at: nil,
        inputs: {
          "milestone_kind" => kind,
          "resolved" => true,
          "occurred_on" => occurrence.occurred_on.iso8601,
          "supplier_planning_milestone_occurrence_id" => occurrence.id
        }
      }
    else
      {
        calculated_on: nil, calculated_at: occurrence.occurred_at,
        inputs: {
          "milestone_kind" => kind,
          "resolved" => true,
          "occurred_at" => occurrence.occurred_at.iso8601,
          "supplier_planning_milestone_occurrence_id" => occurrence.id
        }
      }
    end
  end

  def evaluate_composite(shape, params)
    arms = Array(params[:arms])
    raise UnsupportedRule, "#{shape.humanize} requires exactly two arms" unless arms.size == 2

    evaluated = arms.map.with_index do |arm, index|
      arm = arm.with_indifferent_access
      arm_shape = arm[:rule_shape].to_s
      unless SIMPLE_SHAPES.include?(arm_shape) || arm_shape == MILESTONE_SHAPE
        raise UnsupportedRule, "Composite arm #{index + 1} must be a simple rule shape"
      end
      if arm_shape.in?(%w[earlier_of later_of])
        raise UnsupportedRule, "Nested composite arms are not supported"
      end
      if arm_shape == MILESTONE_SHAPE || arm.key?(:milestone) || arm_shape.include?("milestone")
        unless @allow_milestones
          raise UnsupportedRule, "Milestone anchors are not supported in M3E.2"
        end
      end
      evaluate_shape(arm_shape, arm[:rule_parameters] || arm.except(:rule_shape))
    end

    unresolved = evaluated.select { |row| row[:unresolved_milestone] }
    if unresolved.any?
      if @unresolved_milestone_policy == :use_other_arm && unresolved.size == 1
        chosen = evaluated.find { |row| !row[:unresolved_milestone] }
        raise UnsupportedRule, "Composite requires a resolvable fallback arm" if chosen.nil?

        return {
          calculated_on: chosen[:calculated_on], calculated_at: chosen[:calculated_at],
          inputs: {
            "arms" => evaluated.map { |row| row[:inputs] },
            "chosen_on" => chosen[:calculated_on]&.iso8601,
            "chosen_at" => chosen[:calculated_at]&.iso8601,
            "fallback_unresolved_milestone" => true
          }
        }
      end
      raise UnsupportedRule, "Planning milestone arm is unresolved"
    end

    if @definition.date_only?
      dates = evaluated.map { |row| row[:calculated_on] }
      raise UnsupportedRule, "Composite date arms must resolve to dates" if dates.any?(&:nil?)

      chosen = shape == "earlier_of" ? dates.min : dates.max
      {
        calculated_on: chosen, calculated_at: nil,
        inputs: { "arms" => evaluated.map { |row| row[:inputs] }, "chosen_on" => chosen.iso8601 }
      }
    else
      instants = evaluated.map { |row| row[:calculated_at] }
      raise UnsupportedRule, "Composite time arms must resolve to timestamps" if instants.any?(&:nil?)

      chosen = shape == "earlier_of" ? instants.min : instants.max
      {
        calculated_on: nil, calculated_at: chosen,
        inputs: { "arms" => evaluated.map { |row| row[:inputs] }, "chosen_at" => chosen.iso8601 }
      }
    end
  end

  def departure_local_start
    zone = ActiveSupport::TimeZone[@departure.time_zone] ||
      ActiveSupport::TimeZone[@definition.time_zone] ||
      Time.find_zone!("UTC")
    zone.local(@departure.starts_on.year, @departure.starts_on.month, @departure.starts_on.day)
  end

  def definition_zone
    ActiveSupport::TimeZone[@definition.time_zone] || Time.find_zone!("UTC")
  end

  def parse_date!(value, label)
    Date.iso8601(value.to_s)
  rescue ArgumentError, TypeError
    raise UnsupportedRule, "#{label} must be an ISO date"
  end

  def parse_local_datetime!(value, label)
    text = value.to_s.strip
    raise UnsupportedRule, "#{label} can't be blank" if text.blank?

    if text.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?\z/)
      time_parts = text.split(/[T ]/)
      date = Date.iso8601(time_parts[0])
      hour, minute, second = time_parts[1].split(":").map(&:to_i)
      return definition_zone.local(date.year, date.month, date.day, hour, minute, second || 0)
    end

    Time.iso8601(text).in_time_zone(definition_zone)
  rescue ArgumentError, TypeError
    raise UnsupportedRule, "#{label} must be a local datetime"
  end

  def positive_integer!(value, label)
    number = Integer(value)
    raise ArgumentError unless number.positive?

    number
  rescue ArgumentError, TypeError
    raise UnsupportedRule, "#{label} must be a positive whole number"
  end

  def nonnegative_integer!(value, label)
    number = Integer(value)
    raise ArgumentError if number.negative?

    number
  rescue ArgumentError, TypeError
    raise UnsupportedRule, "#{label} must be a whole number of zero or more"
  end
end
