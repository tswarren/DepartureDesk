require "test_helper"

class SupplierDirectorySchemaTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "structure.sql loads cleanly with supplier tables and no extra gist exclusions" do
    with_temporary_database("m1c_structure") do
      ActiveRecord::Tasks::DatabaseTasks.structure_load(
        ActiveRecord::Base.connection_db_config.configuration_hash,
        Rails.root.join("db/structure.sql").to_s
      )

      tables = ActiveRecord::Base.connection.tables.grep(/\Asupplier/).sort
      assert_equal %w[
        supplier_arrangement_activation_capacity_entries
        supplier_arrangement_activation_cost_selections
        supplier_arrangement_activations
        supplier_arrangement_versions
        supplier_arrangements
        supplier_category_assignments
        supplier_commitment_trigger_definitions
        supplier_commitments
        supplier_confirmation_activation_links
        supplier_confirmation_capacity_event_links
        supplier_confirmation_commitment_links
        supplier_confirmation_identifier_links
        supplier_confirmations
        supplier_contact_email_addresses
        supplier_contact_phone_numbers
        supplier_contacts
        supplier_cost_component_bases
        supplier_cost_components
        supplier_cost_definitions
        supplier_cost_occupancy_profile_positions
        supplier_cost_occupancy_profiles
        supplier_cost_participant_categories
        supplier_cost_sources
        supplier_cost_usage_assumptions
        supplier_email_addresses
        supplier_issued_identifiers
        supplier_locations
        supplier_phone_numbers
        supplier_postal_addresses
        supplier_reservation_event_scope_outcomes
        supplier_reservation_events
        supplier_reservation_projections
        supplier_reservation_revisions
        supplier_reservation_scopes
        supplier_reservations
        supplier_resource_definitions
        supplier_resources
        supplier_websites
        suppliers
      ], tables

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
      assert_includes namespaces, "supplier"
    end
  end

  test "forward migration from a populated M1B schema creates supplier directory and backfills sequences" do
    with_temporary_database("m1c_forward") do
      migrate_to!(20260914183000)

      agency_id = SecureRandom.uuid_v7
      ActiveRecord::Base.connection.execute(<<~SQL)
        INSERT INTO agencies (
          id, name, workspace_code, status, country_code, default_currency, default_timezone, created_at, updated_at
        ) VALUES (
          #{quote(agency_id)},
          'M1B Agency',
          'm1b#{SecureRandom.hex(3)}',
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
        );
      SQL

      assert_equal 0, ActiveRecord::Base.connection.tables.grep(/\Asupplier/).size

      migrate_to!(20260914200000)

      tables = ActiveRecord::Base.connection.tables.grep(/\Asupplier/).sort
      assert_equal %w[
        supplier_category_assignments
        supplier_email_addresses
        supplier_phone_numbers
        supplier_postal_addresses
        supplier_websites
        suppliers
      ], tables

      supplier_sequences = ActiveRecord::Base.connection.select_value(<<~SQL)
        SELECT count(*)
        FROM reference_sequences
        WHERE agency_id = #{quote(agency_id)}
          AND namespace = 'supplier'
          AND next_value = 1
      SQL
      assert_equal 1, supplier_sequences.to_i

      migrate_to!(20260914183000)
      assert_equal 0, ActiveRecord::Base.connection.tables.grep(/\Asupplier/).size
      remaining_supplier_sequences = ActiveRecord::Base.connection.select_value(<<~SQL)
        SELECT count(*)
        FROM reference_sequences
        WHERE namespace = 'supplier'
      SQL
      assert_equal 0, remaining_supplier_sequences.to_i
      client_only = ActiveRecord::Base.connection.select_value(<<~SQL)
        SELECT pg_get_constraintdef(c.oid)
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        WHERE t.relname = 'reference_sequences'
          AND c.conname = 'reference_sequences_namespace'
      SQL
      assert_match(/namespace.*=.*'client'/, client_only)
      assert_no_match(/supplier/, client_only)

      migrate_to!(20260914200000)
      assert_equal %w[
        supplier_category_assignments
        supplier_email_addresses
        supplier_phone_numbers
        supplier_postal_addresses
        supplier_websites
        suppliers
      ], ActiveRecord::Base.connection.tables.grep(/\Asupplier/).sort
      reapplied_sequences = ActiveRecord::Base.connection.select_value(<<~SQL)
        SELECT count(*)
        FROM reference_sequences
        WHERE agency_id = #{quote(agency_id)}
          AND namespace = 'supplier'
          AND next_value = 1
      SQL
      assert_equal 1, reapplied_sequences.to_i
    end
  end

  private

  def with_temporary_database(label)
    database = "departure_desk_#{label}_#{Process.pid}"
    original = ActiveRecord::Base.connection_db_config
    admin = ActiveRecord::Base.connection

    admin.execute("DROP DATABASE IF EXISTS #{admin.quote_table_name(database)}")
    admin.execute("CREATE DATABASE #{admin.quote_table_name(database)}")

    config = original.configuration_hash.merge(database:)
    ActiveRecord::Base.establish_connection(config)

    yield
  ensure
    ActiveRecord::Base.establish_connection(original)
    ActiveRecord::Base.connection.execute("DROP DATABASE IF EXISTS #{ActiveRecord::Base.connection.quote_table_name(database)}") if database
  end

  def migrate_to!(version)
    ActiveRecord::Base.connection_pool.migration_context.migrate(version)
  end

  def quote(value)
    ActiveRecord::Base.connection.quote(value)
  end
end
