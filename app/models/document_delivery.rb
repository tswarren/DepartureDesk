# A delivery of an issued document made outside the app, recorded by hand
# (DOC-21): the method, the recipient and the date. Append-only.
class DocumentDelivery < ApplicationRecord
  METHODS = %w[own_email printed in_person].freeze
  METHOD_LABELS = { "own_email" => "Own email", "printed" => "Printed", "in_person" => "In person" }.freeze
  RECIPIENT_LIMIT = 200

  belongs_to :agency
  belongs_to :document_version, inverse_of: :deliveries
  belongs_to :recorded_by, class_name: "AgencyUser"

  enum :delivery_method, METHODS.index_by(&:itself), validate: true, prefix: :by

  validates :recipient, presence: true, length: { maximum: RECIPIENT_LIMIT }
  validates :delivered_on, presence: true

  before_update { raise ActiveRecord::ReadOnlyRecord }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }

  def method_label = METHOD_LABELS.fetch(delivery_method)
end
