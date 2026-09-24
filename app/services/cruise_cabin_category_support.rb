# frozen_string_literal: true

module CruiseCabinCategorySupport
  module_function

  def typed_cabin_pool?(pool, pool_definition)
    pool.present? &&
      pool_definition.present? &&
      pool.resource_units? &&
      pool_definition.unit_label.to_s.casecmp("cabins").zero?
  end
end
