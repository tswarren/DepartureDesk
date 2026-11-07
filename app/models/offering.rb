# A client-facing package on a Departure (BKG-13): it groups what a client
# books and never merges supplier arrangements, inventory, reservations or
# costs. Its contents are its choices, each included or an add-on.
class Offering < ApplicationRecord
  NAME_LIMIT = 120

  belongs_to :agency
  belongs_to :departure
  has_many :choices, -> { order(:position, :created_at) }, class_name: "OfferingChoice", inverse_of: :offering, dependent: :restrict_with_exception

  attr_readonly :agency_id, :departure_id

  normalizes :name, with: ->(value) { value.to_s.squish }
  normalizes :description, with: ->(value) { value.to_s.gsub("\r\n", "\n").strip.presence }

  validates :name, presence: true, length: { maximum: NAME_LIMIT }
  validates :currency, format: { with: Agency::CURRENCY_FORMAT }

  # What it still needs before step 6 will book it.
  def booking_blockers
    choices.includes(options: [ :inventory_group, :prices ]).flat_map do |choice|
      next [ "Add an option to #{choice.name}." ] if choice.options.empty? && choice.required_single?

      choice.options.flat_map { |option| option.missing_prices.map { |position| "Set the #{position} price for #{option.label}." } }
    end
  end
end
