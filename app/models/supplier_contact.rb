class SupplierContact < ApplicationRecord
  STATUSES = %w[active inactive].freeze

  belongs_to :agency
  belongs_to :supplier
  has_many :email_addresses, class_name: "SupplierContactEmailAddress", dependent: :restrict_with_exception
  has_many :phone_numbers, class_name: "SupplierContactPhoneNumber", dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true, default: "active"

  attr_readonly :agency_id, :supplier_id

  normalizes :first_name, :last_name, :title, :department, :role_label,
    with: ->(value) { value.to_s.strip.presence }

  validates :first_name, :last_name, presence: true, length: { maximum: 100 }
  validates :title, :department, length: { maximum: 120 }, allow_nil: true
  validates :role_label, length: { maximum: 80 }, allow_nil: true

  scope :ordered_for_directory, -> {
    order(Arel.sql("lower(last_name) ASC, lower(first_name) ASC"), :id)
  }
  scope :preferred_first, -> { order(preferred: :desc, created_at: :asc, id: :asc) }

  def display_name_for_directory
    [ first_name, last_name ].compact_blank.join(" ")
  end
end
