# Daily sweep (ADR 0019, issuing order step 5): purges blobs that were
# uploaded but never attached, such as an issued document's PDF whose
# transaction failed after the upload. An attached blob is never touched.
# Idempotent: a second run finds nothing left to purge.
class PurgeUnattachedBlobsJob < ApplicationJob
  AGE = 1.day

  queue_as :documents

  def perform
    ActiveStorage::Blob.unattached.where(created_at: ...AGE.ago).find_each(&:purge)
  end
end
