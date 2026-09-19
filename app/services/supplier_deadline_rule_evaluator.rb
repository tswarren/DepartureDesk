# frozen_string_literal: true

class SupplierDeadlineRuleEvaluator
  UnsupportedRule = Class.new(StandardError)

  SIMPLE_SHAPES = %w[
    fixed_date fixed_local_datetime days_before_departure days_after_departure
    hours_before_departure hours_after_departure
  ].freeze

  def self.call(definition:, departure:, at: Time.current)
    new(definition:, departure:, at:).call
  end

  def initialize(definition:, departure:, at: Time.current)
    @definition = definition
    @departure = departure
    @at = at
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
    when "earlier_of", "later_of"
      evaluate_composite(shape.to_s, params)
    else
      raise UnsupportedRule, "Unsupported deadline rule shape #{shape}"
    end
  end

  def evaluate_composite(shape, params)
    arms = Array(params[:arms])
    raise UnsupportedRule, "#{shape.humanize} requires exactly two arms" unless arms.size == 2

    evaluated = arms.map.with_index do |arm, index|
      arm = arm.with_indifferent_access
      arm_shape = arm[:rule_shape].to_s
      unless SIMPLE_SHAPES.include?(arm_shape)
        raise UnsupportedRule, "Composite arm #{index + 1} must be a simple rule shape"
      end
      if arm_shape.in?(%w[earlier_of later_of]) || arm.key?(:milestone) ||
          arm_shape.include?("milestone")
        raise UnsupportedRule, "Milestone anchors are not supported in M3E.2"
      end
      evaluate_shape(arm_shape, arm[:rule_parameters] || arm.except(:rule_shape))
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
