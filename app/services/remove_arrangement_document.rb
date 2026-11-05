# Removes a supplier document at any time (ADR 0019 amendment): the removal
# is audited with the file's name, kind and SHA-256, and the file is purged.
class RemoveArrangementDocument < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, departure:, arrangement:, document:)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @document = document
  end

  def call
    ensure_departure_actor!(:manage_arrangements)

    ActiveRecord::Base.transaction do
      departure = lock_arrangement_context!
      arrangement = lock_arrangement!(departure)
      document = arrangement.documents.lock.find(@document.id)
      details = {
        "arrangement_document_id" => document.id, "filename" => document.file.filename.to_s, "kind" => document.kind,
        "sha256" => document.sha256, "uploaded_by_id" => document.uploaded_by_id
      }
      document.destroy! # has_one_attached purges the file after commit
      audit!(agency: @agency, action: "supplier_arrangement.document_removed", subject: arrangement, actor: @actor, details:)
      Result.new(status: :updated, record: arrangement)
    end
  end
end
