# An offering published to one reseller channel (DEP-07). In Slice 1 each
# reseller relationship is its own channel (D-68). A publication is open
# until it is withdrawn, by staff (DEP-09) or by a return to Draft (DEP-08);
# publishing again makes a new row. PostgreSQL allows only the withdrawal to
# be written after creation.
class OfferingPublication < ApplicationRecord
  belongs_to :agency
  belongs_to :offering
  belongs_to :reseller
  belongs_to :published_by, class_name: "AgencyUser"
  belongs_to :withdrawn_by, class_name: "AgencyUser", optional: true

  attr_readonly :agency_id, :offering_id, :reseller_id, :published_at, :published_by_id

  scope :open, -> { where(withdrawn_at: nil) }

  def open? = withdrawn_at.nil?
end
