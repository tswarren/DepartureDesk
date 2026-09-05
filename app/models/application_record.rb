require "securerandom"

class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  attribute :id,
    default: -> {
      SecureRandom.uuid_v7(extra_timestamp_bits: 12)
    }
end