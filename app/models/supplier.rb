class Supplier < ApplicationRecord
  KINDS = %w[organization individual].freeze
  STATUSES = %w[active inactive].freeze
  REFERENCE_FORMAT = /\ASUP-[0-9]{6}\z/

  belongs_to :agency
  has_many :category_assignments, class_name: "SupplierCategoryAssignment", dependent: :restrict_with_exception
  has_many :locations, class_name: "SupplierLocation", dependent: :restrict_with_exception
  has_many :contacts, class_name: "SupplierContact", dependent: :restrict_with_exception
  has_many :email_addresses, class_name: "SupplierEmailAddress", dependent: :restrict_with_exception
  has_many :phone_numbers, class_name: "SupplierPhoneNumber", dependent: :restrict_with_exception
  has_many :postal_addresses, class_name: "SupplierPostalAddress", dependent: :restrict_with_exception
  has_many :websites, class_name: "SupplierWebsite", dependent: :restrict_with_exception

  enum :kind, KINDS.index_by(&:itself), validate: true
  enum :status, STATUSES.index_by(&:itself), validate: true, default: "active"

  attr_readonly :agency_id, :kind, :supplier_reference

  normalizes :display_name, :legal_name, :first_name, :last_name, :doing_business_as,
    with: ->(value) { value.to_s.strip.presence }

  validates :supplier_reference, presence: true, format: { with: REFERENCE_FORMAT }
  validate :name_shape_matches_kind

  scope :ordered_for_directory, -> {
    order(Arel.sql("lower(coalesce(doing_business_as, display_name, first_name || ' ' || last_name)) ASC"), :supplier_reference)
  }

  def display_name_for_directory
    doing_business_as.presence || display_name.presence || [ first_name, last_name ].compact_blank.join(" ")
  end

  private

  def name_shape_matches_kind
    case kind
    when "organization"
      errors.add(:display_name, "can't be blank") if display_name.blank?
      errors.add(:first_name, "must be blank for organizations") if first_name.present?
      errors.add(:last_name, "must be blank for organizations") if last_name.present?
    when "individual"
      errors.add(:first_name, "can't be blank") if first_name.blank?
      errors.add(:last_name, "can't be blank") if last_name.blank?
      errors.add(:display_name, "must be blank for individuals") if display_name.present?
      errors.add(:legal_name, "must be blank for individuals") if legal_name.present?
    end
  end
end
