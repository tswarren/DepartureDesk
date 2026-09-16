class ServiceOccurrence < ApplicationRecord
  STATUSES = %w[planned cancelled].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :arrangement_item

  has_many :definitions, class_name: "ServiceOccurrenceDefinition", dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true, default: "planned"

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id, :arrangement_item_id
end
