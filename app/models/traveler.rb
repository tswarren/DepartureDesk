# A traveler profile: always one person (CLT-05), reusable across trips
# (CLT-06). The legal name is given names, middle name, surname and suffix
# as on the passport, with a preferred name used in conversation and never
# sent to suppliers (CLT-28). A profile saves with details missing (UI
# acceptance); the details a stage needs are checked by that stage (CLT-15).
# No passport fields in Slice 1.
class Traveler < ApplicationRecord
  GENDERS = %w[female male unspecified].freeze
  NAME_LIMIT = 80
  SUFFIX_LIMIT = 20

  belongs_to :agency
  has_many :links, class_name: "TravelerLink", inverse_of: :traveler, dependent: :restrict_with_exception
  has_many :clients, through: :links

  attr_readonly :agency_id

  normalizes :given_names, :middle_name, :surname, :suffix, :preferred_name, :phone, with: ->(value) { value.to_s.squish.presence }
  normalizes :email_address, with: ->(value) { value.to_s.strip.downcase.presence }

  validates :given_names, :middle_name, :surname, :preferred_name, length: { maximum: NAME_LIMIT }
  validates :suffix, length: { maximum: SUFFIX_LIMIT }
  validates :gender, inclusion: { in: GENDERS }, allow_nil: true
  validates :email_address, format: { with: /\A[^@\s]+@[^@\s]+\z/ }, length: { maximum: 254 }, allow_nil: true
  validates :phone, length: { maximum: 40 }
  validate :some_name
  validate :plausible_date_of_birth

  scope :ordered, -> { order(:surname, :given_names, :id) }

  def legal_name
    [ given_names, middle_name, surname, suffix ].compact.join(" ").presence
  end

  def display_name
    [ preferred_name.presence || given_names, surname ].compact.join(" ").presence || legal_name
  end

  # CLT-15: what confirmation needs from the profile.
  def legal_name_complete? = given_names.present? && surname.present?

  def age_on(date)
    return if date_of_birth.nil? || date.nil?

    age = date.year - date_of_birth.year
    before_birthday = date.month < date_of_birth.month || (date.month == date_of_birth.month && date.day < date_of_birth.day)
    before_birthday ? age - 1 : age
  end

  private

  def some_name
    errors.add(:surname, "or given names are required") if given_names.blank? && surname.blank? && preferred_name.blank?
  end

  def plausible_date_of_birth
    return if date_of_birth.nil?

    errors.add(:date_of_birth, "must be on or after 1900-01-01") if date_of_birth < Date.new(1900, 1, 1)
  end
end
