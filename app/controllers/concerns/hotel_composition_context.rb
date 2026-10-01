# frozen_string_literal: true

module HotelCompositionContext
  extend ActiveSupport::Concern

  include CompositionAccess

  private

  def assign_hotel_composition_context
    @outcome = composition_outcome
    @package_id = validated_composition_package_id
    @workspace = DepartureBuilderWorkspace.new(
      agency: Current.agency,
      departure: @departure,
      package_id: @package_id,
      work_on: hotel_composition_work_on,
      require_explicit_package: true
    )
  end

  def hotel_composition_work_on
    case @outcome
    when "proposal" then "preview"
    when "supplier", "pricing" then @outcome
    end
  end
end
