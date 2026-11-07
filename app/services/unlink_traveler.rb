# Removes a traveler's link to a client (CLT-09). The traveler, and any
# booking they are on, is unaffected (CLT-10).
class UnlinkTraveler < AgencyCommand
  include TravelerCommandSupport

  def initialize(agency:, actor:, link:)
    @agency = agency
    @actor = actor
    @link = link
  end

  def call
    ensure_actor!(:manage_client_directory)

    ActiveRecord::Base.transaction do
      @agency.lock!
      link = @agency.traveler_links.lock.find(@link.id)
      link.destroy!
      audit!(agency: @agency, action: "client.traveler_unlinked", subject: link.client, actor: @actor,
        details: { "traveler_id" => link.traveler_id, "relationship" => link.relationship })
      Result.new(status: :removed, record: link)
    end
  end
end
