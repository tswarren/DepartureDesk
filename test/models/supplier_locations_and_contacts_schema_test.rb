require "test_helper"
require_relative "../support/temporary_database_helper"

class SupplierLocationsAndContactsSchemaTest < ActiveSupport::TestCase
  include TemporaryDatabaseHelper
  self.use_transactional_tests = false

  M1C_TABLES = %w[
    supplier_category_assignments
    supplier_email_addresses
    supplier_phone_numbers
    supplier_postal_addresses
    supplier_websites
    suppliers
  ].freeze

  M1D_TABLES = %w[
    supplier_category_assignments
    supplier_contact_email_addresses
    supplier_contact_phone_numbers
    supplier_contacts
    supplier_email_addresses
    supplier_locations
    supplier_phone_numbers
    supplier_postal_addresses
    supplier_websites
    suppliers
  ].freeze

  test "structure.sql loads cleanly with M1D supplier tables and no extra gist exclusions" do
    with_temporary_database("m1d_structure") do
      ActiveRecord::Tasks::DatabaseTasks.structure_load(
        ActiveRecord::Base.connection_db_config.configuration_hash,
        Rails.root.join("db/structure.sql").to_s
      )

      tables = ActiveRecord::Base.connection.tables.grep(/\Asupplier/).grep_v(/\Asupplier_(arrangement|rate_line|rate_band|deadline|reservation)/).sort
      assert_equal M1D_TABLES, tables

      exclusions = ActiveRecord::Base.connection.select_values(<<~SQL)
        SELECT c.conname
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        WHERE c.contype = 'x'
        ORDER BY c.conname
      SQL
      assert_equal [ "client_org_contacts_no_overlapping_history" ], exclusions
    end
  end

  test "forward migration from M1C creates M1D tables and migrate down removes them" do
    with_temporary_database("m1d_forward") do
      migrate_to!(20260914200000)

      assert_equal M1C_TABLES, ActiveRecord::Base.connection.tables.grep(/\Asupplier/).grep_v(/\Asupplier_(arrangement|rate_line|rate_band|deadline|reservation)/).sort

      migrate_to!(20260915010000)
      assert_equal M1D_TABLES, ActiveRecord::Base.connection.tables.grep(/\Asupplier/).grep_v(/\Asupplier_(arrangement|rate_line|rate_band|deadline|reservation)/).sort

      migrate_to!(20260915120000)
      assert ActiveRecord::Base.connection.column_exists?(:supplier_locations, :name_search_vector)
      indexes = ActiveRecord::Base.connection.indexes(:supplier_locations).map(&:name)
      assert_includes indexes, "index_supplier_locations_on_name_search_vector"

      exclusions = ActiveRecord::Base.connection.select_values(<<~SQL)
        SELECT c.conname
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        WHERE c.contype = 'x'
        ORDER BY c.conname
      SQL
      assert_equal [ "client_org_contacts_no_overlapping_history" ], exclusions

      migrate_to!(20260914200000)
      assert_equal M1C_TABLES, ActiveRecord::Base.connection.tables.grep(/\Asupplier/).grep_v(/\Asupplier_(arrangement|rate_line|rate_band|deadline|reservation)/).sort
      assert_equal 0, ActiveRecord::Base.connection.tables.grep(/\Asupplier_(locations|contacts)/).size
    end
  end
end
