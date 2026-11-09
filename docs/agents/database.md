# Database

Moved from [AGENTS.md](../../AGENTS.md), which points here. PostgreSQL, the queue database, identifiers and migrations. These rules are binding when a task touches this area.

## PostgreSQL and Active Record

- PostgreSQL 18 is authoritative. Do not reduce the design to cross-database compatibility.
- `config.active_record.schema_format` is `:sql`; commit updated `db/structure.sql` after migrations.
- The identity baseline does not enable `citext` or `pg_trgm`. Enforce workspace-code and email uniqueness on normalized text columns. `btree_gist` is enabled on the primary database only for the named Client Organization contact-history exclusion `client_org_contacts_no_overlapping_history`. Do not add other `btree_gist` uses, and do not enable that extension in the queue database. Do not enable `citext` or `pg_trgm` for directory work.
- Application-owned durable tables use UUID primary keys with database defaults of `uuidv7()`.
- When an ID is needed before persistence, assign UUIDv7 in Rails and retain the database default as a safety net.
- Every UUID foreign key must declare `type: :uuid` in its migration.
- Framework-owned tables such as Solid Queue and Active Storage internals may keep their own identifier conventions. Generate Active Storage so attachments can reference UUID records, and use it only under [ADR 0019](../adr/0019-issued-document-storage.md).
- Rails operates timestamps in UTC; domain timestamps use PostgreSQL `timestamptz`.
- Store an agency’s display/business timezone as a recognized IANA timezone.
- Currency codes are uppercase three-character values.
- Store money in `bigint` integer minor-unit columns using the `_minor_units` suffix, with an explicit currency for every independently meaningful monetary fact.
- Never use floating-point columns for money, rates that post money, or allocations.
- Use decimal/numeric values only where fractional quantities or exchange rates require them, with explicit precision and scale.
- Add `null`, foreign-key, unique, check, and exclusion constraints as appropriate. Model validation alone is insufficient.
- Name important constraints and indexes so failures are diagnosable.

### Multiple databases

The application database and Solid Queue database are separate.

- Development primary: `departure_desk_development`.
- Development queue: `departure_desk_development_queue`.
- Production uses `DATABASE_URL` and `QUEUE_DATABASE_URL`.
- Development must configure `config.solid_queue.connects_to = { database: { writing: :queue } }`.
- Do not put a single shared `DATABASE_URL` into the default development database anchor; that can redirect both named connections to one database.
- Queue structure belongs in `db/queue_structure.sql`.

Do not “fix” missing queue tables by adding Solid Queue tables to the primary domain schema. Confirm the active connection and initialize the queue database instead.

## Identifier policy

Application domain models currently inherit Rails-side UUIDv7 preassignment from `ApplicationRecord`. Before introducing or retaining any application-owned bigint model, resolve that mismatch explicitly. Never let a UUID default write into a bigint primary key.

For migrations:

```ruby
create_table :example_records,
 id: :uuid,
 default: -> { "uuidv7()" } do |table|
 # ...
end
```

For references:

```ruby
table.references :agency,
 null: false,
 type: :uuid,
 foreign_key: true
```

## Migration policy

- Inspect both migrations and `db/structure.sql` before changing persistence.
- Prefer a new forward migration once a migration has been shared or run outside a disposable local environment.
- The agency-identity baseline replaced the Party migrations. Do not stack drop-table migrations on that old schema.
- Never drop, reset, or recreate a database without stating exactly which database and data will be lost.
- Never edit generated structure SQL by hand to work around a migration problem.
- Verify migrations against both development and test databases.
- Preserve unrelated user data and existing worktree changes.

## Recreating databases

After checking out this identity baseline, recreate the primary development and test databases. Do not migrate a Party or membership database forward.
