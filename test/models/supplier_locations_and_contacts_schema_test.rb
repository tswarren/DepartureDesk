require "test_helper"

class SupplierLocationsAndContactsSchemaTest < ActiveSupport::TestCase
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

  CURRENT_SUPPLIER_TABLES = %w[
    supplier_arrangement_activation_capacity_entries
    supplier_arrangement_activation_cost_selections
    supplier_arrangement_activations
    supplier_arrangement_versions
    supplier_arrangements
    supplier_attention_findings
    supplier_category_assignments
    supplier_commitment_dispositions
    supplier_commitment_evidence_coverage_members
    supplier_commitment_evidence_coverage_revocations
    supplier_commitment_evidence_coverages
    supplier_commitment_evidence_member_disqualifications
    supplier_commitment_reopenings
    supplier_commitment_trigger_definitions
    supplier_commitments
    supplier_confirmation_activation_links
    supplier_confirmation_capacity_event_links
    supplier_confirmation_commitment_links
    supplier_confirmation_identifier_links

    supplier_confirmation_reservation_response_links

    supplier_confirmation_reservation_scope_links
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
    supplier_deadline_commitment_definition_lines
    supplier_deadline_definition_coverage_links
    supplier_deadline_definitions
    supplier_deadline_occurrences
    supplier_deadline_projections
    supplier_deposit_external_attestations
    supplier_deposit_requirement_definition_cost_links
    supplier_deposit_requirement_definition_coverage_links
    supplier_deposit_requirement_definitions
    supplier_deposit_requirement_tranche_components
    supplier_deposit_requirement_tranches
    supplier_email_addresses
    supplier_exposure_components
    supplier_exposure_source_qualifications
    supplier_exposure_summaries
    supplier_issued_identifiers
    supplier_locations
    supplier_phone_numbers
    supplier_planning_milestone_occurrences
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
  ].freeze

  test "structure.sql loads cleanly with current supplier tables and no extra gist exclusions" do
    with_temporary_database("m1d_structure") do
      ActiveRecord::Tasks::DatabaseTasks.structure_load(
        ActiveRecord::Base.connection_db_config.configuration_hash,
        Rails.root.join("db/structure.sql").to_s
      )

      tables = ActiveRecord::Base.connection.tables.grep(/\Asupplier/).sort
      assert_equal CURRENT_SUPPLIER_TABLES, tables

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

      assert_equal M1C_TABLES, ActiveRecord::Base.connection.tables.grep(/\Asupplier/).sort

      migrate_to!(20260915010000)
      assert_equal M1D_TABLES, ActiveRecord::Base.connection.tables.grep(/\Asupplier/).sort

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
      assert_equal M1C_TABLES, ActiveRecord::Base.connection.tables.grep(/\Asupplier/).sort
      assert_equal 0, ActiveRecord::Base.connection.tables.grep(/\Asupplier_(locations|contacts)/).size
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
end
