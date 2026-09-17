class AllowUnmaterializedVersionCopyLineage < ActiveRecord::Migration[8.1]
  # Reserved after review clarified that a version may be prepared before the
  # M3D.3 successor-copy command materializes lineage.
  def change; end
end
