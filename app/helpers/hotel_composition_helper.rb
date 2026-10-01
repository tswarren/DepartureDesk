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
end
