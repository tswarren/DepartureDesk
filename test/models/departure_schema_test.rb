require "test_helper"
require_relative "../support/temporary_database_helper"

class DepartureSchemaTest < ActiveSupport::TestCase
  include TemporaryDatabaseHelper
  self.use_transactional_tests = false

  test "structure.sql loads departures, departure sequences, and no extra gist exclusions" do
    with_temporary_database("m2a_structure") do
      ActiveRecord::Tasks::DatabaseTasks.structure_load(
        ActiveRecord::Base.connection_db_config.configuration_hash,
        Rails.root.join("db/structure.sql").to_s
      )

      assert_includes ActiveRecord::Base.connection.tables, "departures"

      exclusions = ActiveRecord::Base.connection.select_values(<<~SQL)
        SELECT c.conname
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        WHERE c.contype = 'x'
        ORDER BY c.conname
      SQL
      assert_equal [ "client_org_contacts_no_overlapping_history" ], exclusions

      namespaces = ActiveRecord::Base.connection.select_value(<<~SQL)
        SELECT pg_get_constraintdef(c.oid)
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        WHERE t.relname = 'reference_sequences'
          AND c.conname = 'reference_sequences_namespace'
      SQL
      assert_includes namespaces, "departure"

      generated = ActiveRecord::Base.connection.select_value(<<~SQL)
        SELECT pg_get_expr(adbin, adrelid)
        FROM pg_attrdef
        JOIN pg_attribute ON pg_attribute.attrelid = pg_attrdef.adrelid AND pg_attribute.attnum = pg_attrdef.adnum
        JOIN pg_class ON pg_class.oid = pg_attrdef.adrelid
        WHERE pg_class.relname = 'departures'
          AND pg_attribute.attname = 'name_search_key'
      SQL
      assert_match(/dd_search_normalize/, generated.to_s)

      indexes = ActiveRecord::Base.connection.select_values(<<~SQL)
        SELECT indexname FROM pg_indexes
        WHERE tablename = 'departures'
        ORDER BY indexname
      SQL
      assert_includes indexes, "index_departures_on_agency_and_name_search_key"
      assert_includes indexes, "index_departures_on_agency_starts_on_name_id"
      assert_includes indexes, "index_departures_on_agency_status_starts_on_id"
      assert_includes indexes, "index_departures_on_agency_office_starts_on_id"
      assert_includes indexes, "index_departures_on_agency_user_starts_on_id"
      assert_includes indexes, "index_departures_on_agency_ends_on_id"
    end
  end

  test "forward migration from M1E schema creates departures and backfills sequences" do
    with_temporary_database("m2a_forward") do
      migrate_to!(20260915120000)

      agency_id = SecureRandom.uuid_v7
      ActiveRecord::Base.connection.execute(<<~SQL)
        INSERT INTO agencies (
          id, name, workspace_code, status, country_code, default_currency, default_timezone, created_at, updated_at
        ) VALUES (
          #{quote(agency_id)},
          'M1E Agency',
          'm1e#{SecureRandom.hex(3)}',
          'active',
          'US',
          'USD',
          'UTC',
          CURRENT_TIMESTAMP,
          CURRENT_TIMESTAMP
        );

        INSERT INTO reference_sequences (
          id, agency_id, namespace, next_value, created_at, updated_at
        ) VALUES (
          #{quote(SecureRandom.uuid_v7)},
          #{quote(agency_id)},
          'client',
          1,
          CURRENT_TIMESTAMP,
          CURRENT_TIMESTAMP
        ), (
          #{quote(SecureRandom.uuid_v7)},
          #{quote(agency_id)},
          'supplier',
          1,
          CURRENT_TIMESTAMP,
          CURRENT_TIMESTAMP
        );
      SQL

      assert_not ActiveRecord::Base.connection.tables.include?("departures")

      migrate_to!(20260916010000)

      assert_includes ActiveRecord::Base.connection.tables, "departures"
      departure_sequences = ActiveRecord::Base.connection.select_value(<<~SQL)
        SELECT count(*)
        FROM reference_sequences
        WHERE agency_id = #{quote(agency_id)}
          AND namespace = 'departure'
          AND next_value = 1
      SQL
      assert_equal 1, departure_sequences.to_i

      created_at = ActiveRecord::Base.connection.select_value(<<~SQL)
        SELECT format_type(a.atttypid, a.atttypmod)
        FROM pg_attribute a
        JOIN pg_class c ON c.oid = a.attrelid
        WHERE c.relname = 'departures' AND a.attname = 'created_at'
      SQL
      assert_equal "timestamp(6) with time zone", created_at

      migrate_to!(20260915120000)
      assert_not ActiveRecord::Base.connection.tables.include?("departures")
      remaining = ActiveRecord::Base.connection.select_value(<<~SQL)
        SELECT count(*) FROM reference_sequences WHERE namespace = 'departure'
      SQL
      assert_equal 0, remaining.to_i
    end
  end

  private

  def quote(value)
    ActiveRecord::Base.connection.quote(value)
  end
end
