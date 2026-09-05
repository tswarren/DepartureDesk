class EnablePostgresqlExtensions < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")
    enable_extension "citext" unless extension_enabled?("citext")
  end
end
