# A staff member on a Departure's team (ACC-09). The team routes work and
# names an optional default task owner (OPS-12); it never grants or limits
# access.
class DepartureTeamMember < ApplicationRecord
  belongs_to :agency
  belongs_to :departure
  belongs_to :agency_user

  attr_readonly :agency_id, :departure_id, :agency_user_id

  validates :agency_user_id, uniqueness: { scope: :departure_id }
  validate :same_agency_staff_user

  private

  def same_agency_staff_user
    return if agency_user.blank? || departure.blank?

    errors.add(:departure, "must belong to the same agency") if departure.agency_id != agency_id
    errors.add(:agency_user, "must belong to the same agency") if agency_user.agency_id != agency_id
    errors.add(:agency_user, "must be an Agency Admin or staff user") if agency_user.reseller?
  end
end
