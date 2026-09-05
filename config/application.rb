require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module DepartureDesk
  class Application < Rails::Application
    # Initialize configuration defaults for Rails 8.1.
    config.load_defaults 8.1

    # Ignore lib directories that do not contain reloadable Ruby code.
    config.autoload_lib(ignore: %w[assets tasks])

    # Preserve PostgreSQL-specific features and constraints.
    config.active_record.schema_format = :sql

    # Rails reads and writes database timestamps in UTC.
    config.active_record.default_timezone = :utc

    # Generate application-owned tables with UUID primary keys.
    config.generators do |generator|
      generator.orm :active_record, primary_key_type: :uuid
    end

    # Store Rails datetime columns as PostgreSQL timestamptz.
    ActiveSupport.on_load(:active_record_postgresqladapter) do
      self.datetime_type = :timestamptz
    end
  end
end
