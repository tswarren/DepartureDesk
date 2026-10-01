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
end
