# frozen_string_literal: true

module TemporaryDatabaseHelper
  # CREATE/DROP DATABASE take an exclusive cluster lock. Parallel CI workers plus
  # leftover pool connections to the temp database can push that past the default
  # 15s/5s timeouts.
  CLUSTER_DDL_TIMEOUT = "60s"

  def with_temporary_database(label)
    database = "departure_desk_#{label}_#{Process.pid}"
    original = ActiveRecord::Base.connection_db_config

    with_cluster_ddl_timeouts do |admin|
      quoted = admin.quote_table_name(database)
      admin.execute("DROP DATABASE IF EXISTS #{quoted}")
      admin.execute("CREATE DATABASE #{quoted}")
    end

    ActiveRecord::Base.establish_connection(original.configuration_hash.merge(database:))
    yield
  ensure
    body_error = $!
    begin
      drop_temporary_database!(database, original)
    rescue StandardError => cleanup_error
      raise body_error || cleanup_error
    end
  end

  def migrate_to!(version)
    ActiveRecord::Base.connection_pool.migration_context.migrate(version)
  end

  private

  def drop_temporary_database!(database, original)
    disconnect_current_pool!
    return if original.nil? || database.blank?

    ActiveRecord::Base.establish_connection(original)
    with_cluster_ddl_timeouts do |admin|
      quoted = admin.quote_table_name(database)
      admin.execute("DROP DATABASE IF EXISTS #{quoted} WITH (FORCE)")
    end
  end

  def with_cluster_ddl_timeouts
    admin = ActiveRecord::Base.connection
    previous_lock = admin.select_value("SHOW lock_timeout")
    previous_statement = admin.select_value("SHOW statement_timeout")
    admin.execute("SET lock_timeout TO #{admin.quote(CLUSTER_DDL_TIMEOUT)}")
    admin.execute("SET statement_timeout TO #{admin.quote(CLUSTER_DDL_TIMEOUT)}")
    yield admin
  ensure
    if ActiveRecord::Base.connected?
      admin = ActiveRecord::Base.connection
      admin.execute("SET lock_timeout TO #{admin.quote(previous_lock)}") if previous_lock
      admin.execute("SET statement_timeout TO #{admin.quote(previous_statement)}") if previous_statement
    end
  end

  def disconnect_current_pool!
    ActiveRecord::Base.connection_pool.disconnect!
  rescue ActiveRecord::ConnectionNotEstablished
    nil
  end
end
