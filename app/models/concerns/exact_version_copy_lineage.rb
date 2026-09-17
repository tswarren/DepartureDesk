module ExactVersionCopyLineage
  extend ActiveSupport::Concern

  included do
    belongs_to :copied_from, class_name: name, optional: true
    attr_readonly :copied_from_id
  end
end
