# A per-user permission grant for a staff user (ADR 0017). An agency_admin holds
# every permission implicitly and never has rows here; the database refuses a
# grant for any other user type.
class UserPermission < ApplicationRecord
  belongs_to :agency
  belongs_to :agency_user

  attr_readonly :agency_id, :agency_user_id, :permission

  validates :permission, inclusion: { in: AccessPermission::PERMISSIONS }
  validates :permission, uniqueness: { scope: %i[agency_id agency_user_id] }
  validate :same_agency_staff_user

  private

  def same_agency_staff_user
    return if agency_user.blank?

    errors.add(:agency_user, "must belong to the same agency") if agency_user.agency_id != agency_id
    errors.add(:agency_user, "must be a staff user") unless agency_user.staff?
  end
end
