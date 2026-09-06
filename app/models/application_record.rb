require "securerandom"

class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  after_initialize :assign_uuidv7_id, if: :assign_uuidv7_id?

  private

  def assign_uuidv7_id?
    new_record? && self.class.primary_key == "id" && self[:id].blank?
  end

  def assign_uuidv7_id
    self.id = SecureRandom.uuid_v7(extra_timestamp_bits: 12)
  end
end
