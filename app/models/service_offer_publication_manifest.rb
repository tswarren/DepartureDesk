# frozen_string_literal: true

class ServiceOfferPublicationManifest < ApplicationRecord
  belongs_to :agency
  belongs_to :departure
  belongs_to :service_offer_version
  belongs_to :actor_agency_user, class_name: "AgencyUser", optional: true

  attr_readonly :agency_id, :departure_id, :service_offer_version_id, :actor_agency_user_id,
    :published_at, :fingerprint_json

  before_update :reject_mutation
  before_destroy :reject_mutation

  private

  def reject_mutation
    errors.add(:base, "publication manifests are immutable")
    throw :abort
  end
end
