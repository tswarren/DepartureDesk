module ClientOrganizationContactPoint
  extend ActiveSupport::Concern

  STATUSES = %w[active inactive].freeze

  included do
    belongs_to :agency
    belongs_to :client_organization

    enum :status, STATUSES.index_by(&:itself), validate: true, default: "active"

    attr_readonly :agency_id, :client_organization_id

    normalizes :label, with: ->(value) { value.to_s.strip.presence }

    validates :label, length: { maximum: 40 }, allow_nil: true

    scope :preferred_first, -> { order(preferred: :desc, created_at: :asc, id: :asc) }
  end
end
