# frozen_string_literal: true

class CreateActivityOffering < AgencyCommand
  include TypedItemWrite

  TEMPLATES = {
    "activity" => "activity_attraction",
    "meal" => "dining",
    "excursion" => "activity_attraction"
  }.freeze

  def initialize(agency:, actor:, departure:, template:, arrangement_attributes:, item_attributes:, occurrence_attributes:, idempotency_key:, arrangement: nil, version_lock_version: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @template = template.to_s
    @arrangement = arrangement
    @arrangement_attributes = arrangement_attributes
    @item_attributes = item_attributes
    @occurrence_attributes = occurrence_attributes
    @idempotency_key = idempotency_key
    @version_lock_version = version_lock_version
  end

  def call
    category = TEMPLATES[@template]
    raise Error.new("Choose an activity, meal, or excursion.", code: :invalid) unless category

    establish_typed_item!(
      departure: @departure, arrangement: @arrangement, category: category, capacity_management: "unmanaged",
      arrangement_attributes: @arrangement_attributes, item_attributes: @item_attributes,
      occurrence_attributes: @occurrence_attributes, idempotency_key: @idempotency_key,
      version_lock_version: @version_lock_version
    )
  end
end
