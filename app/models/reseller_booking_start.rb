# The form a reseller fills in to start a booking on an offer (R-02,
# CLT-25): the new client's name, and whether they travel. Not stored.
class ResellerBookingStart
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :first_name, :string
  attribute :last_name, :string
  attribute :traveling, :boolean, default: true
  attribute :date_of_birth, :string

  def self.model_name = ActiveModel::Name.new(self, nil, "BookingStart")
end
