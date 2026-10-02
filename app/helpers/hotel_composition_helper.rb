# frozen_string_literal: true

module HotelCompositionHelper
  def hotel_room_night_sentence(shape)
    categories = shape.category_count
    nights = shape.room_night_count
    "#{categories} #{'room category'.pluralize(categories)} · #{nights} contracted #{'room night'.pluralize(nights)}"
  end

  def hotel_local_time(value)
    return if value.blank?
    return value.strftime("%H:%M") if value.respond_to?(:strftime)

    value.to_s[0, 5]
  end

  def hotel_evidence_kind_options
    CapacityPoolDefinition::EVIDENCE_KINDS
  end

  def hotel_contracted_stay_sentence(definition, night_count)
    return if definition.nil?

    nights = night_count.to_i
    "#{hotel_stay_span(definition)} · #{nights} #{'night'.pluralize(nights)}"
  end

  def hotel_stay_span(definition)
    return if definition.nil?

    start_on = definition.starts_on
    end_on = definition.ends_on
    if start_on.year == end_on.year && start_on.month == end_on.month
      "#{start_on.strftime("%b %-d")}–#{end_on.strftime("%-d, %Y")}"
    elsif start_on.year == end_on.year
      "#{start_on.strftime("%b %-d")}–#{end_on.strftime("%b %-d, %Y")}"
    else
      "#{start_on.strftime("%b %-d, %Y")}–#{end_on.strftime("%b %-d, %Y")}"
    end
  end

  def hotel_night_label(date)
    date.to_date.strftime("%b %-d")
  end

  def hotel_category_room_night_sentence(count)
    "#{count} contracted #{'room night'.pluralize(count)}"
  end

  def hotel_matrix_quantity(resource_id, date, pool)
    return pool&.proposed_opening_quantity if @submitted_quantities.nil?

    submitted = @submitted_quantities.dig(resource_id.to_s, date.to_date.iso8601)
    submitted.nil? ? pool&.proposed_opening_quantity : submitted
  end

  def hotel_matrix_cell_invalid?(resource_id, date)
    Array(@invalid_cells).include?("#{resource_id}--#{date.to_date.iso8601}")
  end

  def hotel_rates_uniform?(contexts, kind)
    contexts.map { |context| context.public_send(kind)&.amount_minor_units }.uniq.size <= 1
  end

  def hotel_rate_amount(minor, currency)
    return "" if minor.nil? || currency.blank?

    Money.new(minor, currency).format(symbol: false, thousands_separator: false)
  end

  def hotel_rate_value(context, kind, currency)
    submitted = @submitted_rate_values&.dig(context.resource_id.to_s, context.date.iso8601, kind.to_s)
    return submitted unless submitted.nil?

    hotel_rate_amount(context.public_send(kind)&.amount_minor_units, currency)
  end

  def hotel_compact_rate_value(contexts, kind, currency)
    submitted = contexts.map do |context|
      @submitted_rate_values&.dig(context.resource_id.to_s, context.date.iso8601, kind.to_s)
    end
    return submitted.compact.first if submitted.compact.uniq.size == 1

    hotel_rate_amount(contexts.first&.public_send(kind)&.amount_minor_units, currency)
  end

  def hotel_rate_field_invalid?(context, kind)
    Array(@invalid_rate_fields).include?("#{context.resource_id}--#{context.date.iso8601}--#{kind}")
  end

  def hotel_noncommissionable_checked?(shape)
    return @submitted_noncommissionable unless @submitted_noncommissionable.nil?

    definitions = shape.supported_contexts.filter_map(&:definition)
    definitions.any? && definitions.all?(&:noncommissionable?)
  end

  def hotel_agreement_money(minor, currency)
    return "—" if minor.nil? || currency.blank?

    Money.new(minor, currency).format
  end

  def hotel_local_clock(value)
    hotel_local_time(value)
  end
end
