# Phase 1: M3 and M4 deletion inventory

**Status:** Accepted 2026-11-04 with the three recommendations below. Executed on branch `phase-1/delete-m3-m4`.

**Reads with:** [first-slice charter](first-slice-charter.md) Phase 1, D-65, D-66, [ADR 0018](../../adr/0018-arrangement-history-by-dated-adjustment.md) and its spike amendment, [hold-and-reserve spike](phase-1-hold-and-reserve-spike.md).

D-66 deletes the shipped supplier-planning (M3) and offer (M4) layers, including the Cruise, Hotel, Transportation and Activity workflows, before Slice 1 step 1. This inventory lists exactly what goes, what stays, and what kept code has to change. It was built from the repository at `main` `08368ac`.

## The boundary

M3 started with commit `901f056` ("Add M3A Arrangement persistence, models, and catalogs", 2026-09-16), which added the first M3 migration, `20260916140000_create_supplier_arrangement_structure.rb`. Everything in `app/` and `test/` that existed in that commit's parent is agency identity, M1 or M2, and is kept. Every file added since is M3 or M4 and is deleted, except the one listed under "Exceptions".

| Area | Files now | Deleted | Kept |
| --- | --- | --- | --- |
| `app/` and `test/` | 1,379 | 899 | 480 |
| Lines of Ruby, ERB and JavaScript | about 164,000 | about 129,000 | about 35,000 |

The check that the boundary holds: no kept file depends on a deleted one except the files under "Kept code that changes", and no kept table has a foreign key into a dropped table.

## Database

### Tables

Kept (30): `agencies`, `agency_users`, `offices`, `sessions`, `audit_events`, `reference_sequences`, `departures`, the 12 client directory tables, `suppliers` and its 10 directory tables (categories, locations, contacts and contact points), `schema_migrations` and `ar_internal_metadata`.

Dropped (114):

| Group | Tables | Names |
| --- | --- | --- |
| Arrangements and versions | 16 | `agency_command_idempotency_keys`, `arrangement_item_definitions`, `arrangement_item_setup_results`, `arrangement_items`, `supplier_arrangement_activation_capacity_entries`, `supplier_arrangement_activation_cost_selections`, `supplier_arrangement_activations`, `supplier_arrangement_commercial_benefit_definitions`, `supplier_arrangement_commercial_benefits`, `supplier_arrangement_cruise_agreement_confirmations`, `supplier_arrangement_cruise_capacity_deposit_requirements`, `supplier_arrangement_cruise_term_definitions`, `supplier_arrangement_ending_previews`, `supplier_arrangement_endings`, `supplier_arrangement_versions`, `supplier_arrangements` |
| Service occurrences and resources | 4 | `service_occurrence_definitions`, `service_occurrences`, `supplier_resource_definitions`, `supplier_resources` |
| Capacity | 7 | `capacity_events`, `capacity_pair_definitions`, `capacity_pool_definitions`, `capacity_pools`, `capacity_projections`, `capacity_reconciliation_resolutions`, `capacity_reconciliations` |
| Supplier costs | 8 | `supplier_cost_component_bases`, `supplier_cost_components`, `supplier_cost_definitions`, `supplier_cost_occupancy_profile_positions`, `supplier_cost_occupancy_profiles`, `supplier_cost_participant_categories`, `supplier_cost_sources`, `supplier_cost_usage_assumptions` |
| Supplier commitments, deadlines, deposits and amounts due | 26 | `supplier_amount_due_contributors`, `supplier_amount_due_definitions`, `supplier_commitment_dispositions`, `supplier_commitment_evidence_coverage_members`, `supplier_commitment_evidence_coverage_revocations`, `supplier_commitment_evidence_coverages`, `supplier_commitment_evidence_member_disqualifications`, `supplier_commitment_reopenings`, `supplier_commitment_trigger_definitions`, `supplier_commitments`, `supplier_deadline_commitment_definition_lines`, `supplier_deadline_definition_coverage_links`, `supplier_deadline_definitions`, `supplier_deadline_occurrences`, `supplier_deadline_projections`, `supplier_deposit_external_attestations`, `supplier_deposit_requirement_definition_contributor_links`, `supplier_deposit_requirement_definition_cost_links`, `supplier_deposit_requirement_definition_coverage_links`, `supplier_deposit_requirement_definitions`, `supplier_deposit_requirement_tranche_components`, `supplier_deposit_requirement_tranches`, `supplier_operating_threshold_definitions`, `supplier_operating_threshold_outcomes`, `supplier_payment_requirement_definitions`, `supplier_planning_milestone_occurrences` |
| Supplier confirmations, reservations and identifiers | 16 | `supplier_agreement_reference_absences`, `supplier_agreement_references`, `supplier_confirmation_activation_links`, `supplier_confirmation_capacity_event_links`, `supplier_confirmation_commitment_links`, `supplier_confirmation_identifier_links`, `supplier_confirmation_reservation_response_links`, `supplier_confirmation_reservation_scope_links`, `supplier_confirmations`, `supplier_issued_identifiers`, `supplier_reservation_event_scope_outcomes`, `supplier_reservation_events`, `supplier_reservation_projections`, `supplier_reservation_revisions`, `supplier_reservation_scopes`, `supplier_reservations` |
| Exposure and attention | 4 | `supplier_attention_findings`, `supplier_exposure_components`, `supplier_exposure_source_qualifications`, `supplier_exposure_summaries` |
| Service offers | 17 | `service_offer_choice_groups`, `service_offer_choice_option_source_activations`, `service_offer_choice_options`, `service_offer_client_cancellation_policies`, `service_offer_client_cancellation_tiers`, `service_offer_client_payment_schedule_lines`, `service_offer_client_payment_schedules`, `service_offer_client_stated_conditions`, `service_offer_definitions`, `service_offer_price_component_bases`, `service_offer_price_components`, `service_offer_price_definitions`, `service_offer_publication_manifests`, `service_offer_source_bindings`, `service_offer_version_sales_states`, `service_offer_versions`, `service_offers` |
| Packages | 16 | `package_client_cancellation_policies`, `package_client_cancellation_tiers`, `package_client_payment_schedule_lines`, `package_client_payment_schedules`, `package_client_stated_conditions`, `package_client_term_resolutions`, `package_inclusions`, `package_price_component_bases`, `package_price_components`, `package_price_definitions`, `package_publication_manifests`, `package_publication_result_service_versions`, `package_publication_results`, `package_version_sales_states`, `package_versions`, `packages` |

`agency_command_idempotency_keys` was added by the first M3 migration and is used only by M3 and M4 commands, so it goes too. Slice 1 adds idempotency where its commands need it.

### Other database objects

- **Foreign keys:** none from a kept table into a dropped one.
- **Triggers:** 250 in total. The 27 on kept tables stay, and none of their functions reads a dropped table.
- **Functions:** 110 in total. The 17 used by kept-table triggers stay, and so does `dd_search_normalize`, which the directory search uses. The other 92 are dropped: 88 used only by triggers on dropped tables, `validate_package_ownership_inclusion_match`, and three helpers called by dropped-table checks (`activity_attraction_item`, `transportation_ceiling_item`, `lodging_coverage_affects_version`).
- **Columns on kept tables added by M3 or M4:**
  - `departures.target_timing_text` and its check constraint (M4D0, free-text timing for a Departure without dates). **Decision 1.**
  - `agencies.attention_warning_lead_days` and its check constraint (M3E5, lead days for the needs-attention catalog). **Decision 2.**
  - Index `departures (id, agency_id, operating_currency)` and index `supplier_contacts (id, supplier_id, agency_id)`. They exist for composite foreign keys from dropped tables, and are dropped with them.

### Migration approach

One new migration, `DropM3AndM4Layers`, drops the 114 tables with `CASCADE`, then the 92 functions and the two columns. It is irreversible (`raise ActiveRecord::IrreversibleMigration` in `down`). No data is kept: there is no real agency data, and the Alpha fixture is seeded fresh (ADR 0018).

The 71 M3 and M4 migration files stay in `db/migrate` as history. New environments load `db/structure.sql`, which after this migration has no M3 or M4 objects. Some of those old migrations reference model classes that will no longer exist, so replaying every migration from zero will stop working; `db:prepare` and CI load the structure file and are unaffected.

## Code

### Deleted

Every file added since `901f056`:

| Directory | Files |
| --- | --- |
| `app/controllers` | 106 (Cruise, Hotel, Transportation, Activity, composition, builder, arrangement, capacity, cost, commitment, deadline, deposit, exposure, reservation, service offer and package controllers and their concerns) |
| `app/models` | 121 (the 114 table models and 7 concerns) |
| `app/services` | 285 |
| `app/views` | 171 |
| `app/helpers` | 5 |
| `app/javascript/controllers` | 18 |
| `app/jobs` | 6 (capacity, deadline and exposure projection refresh and repair) |
| `app/queries` | 1 |
| `test/` | 186 (35 controller, 17 model, 90 service, 30 system, 3 job and 1 helper test, 6 support helpers except one, and 4 fixture files) |

### Exceptions

| File | Why it stays |
| --- | --- |
| `test/support/temporary_database_helper.rb` | Added after M3 started but used by three kept schema tests |

### The capacity engine the spike kept

ADR 0018's spike amendment keeps `CapacityTimelineReplay` and `CapacityProjectionRefresher`, and the rebuild and reconciliation code with version lookups removed. Their tables are dropped now and recreated in Slice 1 step 3. Leaving the classes in `app/` until then would leave code that points at missing tables. **Decision 3.**

### Kept code that changes

| File | Change |
| --- | --- |
| `app/models/agency.rb` | Remove the M3 and M4 associations; remove `attention_warning_lead_days` validation (Decision 2) |
| `app/models/departure.rb` | Remove the arrangement, occurrence, offer and package associations and `supplier_arrangement_activation_history?`; `target_timing_text` per Decision 1 |
| `app/models/supplier.rb` | Remove the arrangement, item definition, occurrence definition and cost source associations |
| `app/models/supplier_contact.rb` | Remove `has_many :supplier_arrangements` |
| `app/models/audit_event.rb`, `app/services/record_administrative_audit.rb` | Remove the Package, Service Offer, Supplier Arrangement and Supplier Reservation subject types |
| `app/controllers/departures_controller.rb`, `app/views/departures/show.html.erb` | Remove the arrangement list, needs-attention roll-up and the builder, composition and Packages links |
| `app/views/departures/_form.html.erb`, `app/services/create_departure.rb`, `app/services/update_departure.rb` | Target timing field per Decision 1 |
| `app/services/departure_command_support.rb` | Remove the currency-correction guard that checks offer, package and cost prices (nothing to check any more) |
| `app/services/return_departure_to_draft.rb` | Remove the guard that blocks return to Draft after an arrangement activation |
| `app/controllers/suppliers_controller.rb`, `app/services/change_supplier_status.rb`, `app/views/suppliers/edit_status.html.erb`, `app/views/suppliers/index.html.erb` | Remove the status-change consequences that read arrangements, occurrences, commitments, reservations, capacity pools and published offers |
| `app/services/update_agency_profile.rb`, `app/controllers/administration/agencies_controller.rb`, `app/views/administration/agencies/edit.html.erb`, `show.html.erb` | Remove the deadline and attention projection refresh on a zone change, and the lead-days field (Decision 2) |
| `app/helpers/application_helper.rb`, `app/helpers/navigation_helper.rb` | Remove price, capacity, occurrence and arrangement helpers and navigation entries |
| `config/routes.rb` | Remove every M3 and M4 route (about 330 of 498 lines; the file had 170 at the boundary) |
| `config/recurring.yml` | Remove the three projection jobs; keep `mark_eligible_departures_departed` |
| `test/test_helper.rb` | Remove the includes of the deleted support helpers |
| `test/test_helpers/m1_directory_scenario.rb` | Remove the `SupplierCost*` deletes from cleanup |
| `test/models/supplier_directory_schema_test.rb`, `supplier_locations_and_contacts_schema_test.rb`, `departure_schema_test.rb` | Expected table and column lists lose the dropped tables and columns |
| `test/system/departures_test.rb`, `test/services/m2_departure_scenario_test.rb` | Remove the steps that open composition and Packages from a Departure |

Supplier tests that mention Cruise or Hotel use them as directory categories and need no change.

### Documentation after the deletion

- `AGENTS.md` and `CLAUDE.md`: remove the M3 and M4 freeze rule and vocabulary; keep the pointer to the spec and charter.
- ADRs 0008, 0010 to 0015: mark "Superseded by ADR 0018; code deleted in Phase 1 (D-66)".
- `docs/planning/README.md`: mark M3 and M4 deleted. Archiving the old planning documents is the separate Phase 1 item.

## Decisions

| # | Decision | Recommendation |
| --- | --- | --- |
| 1 | Keep `departures.target_timing_text`, free text such as "Autumn 2027" shown when a Departure has no dates? | **Drop it.** No specification rule asks for it; Draft Departures show "Dates not set". It can return as a spec change if wanted. |
| 2 | Keep `agencies.attention_warning_lead_days`? | **Drop it.** It configured the deleted needs-attention catalog. Slice 1 defines warning lead times from the agency defaults in the spec. |
| 3 | How to keep the spike's chosen capacity engine until step 3? | **Delete it with the rest, and tag the last commit before deletion** `pre-m3-m4-deletion`. Step 3 restores `capacity_timeline_replay.rb` and `capacity_projection_refresher.rb` with `git checkout pre-m3-m4-deletion -- <path>` and adapts them. Nothing in `app/` points at missing tables in between. |

## How the kept files were changed

Most kept files that changed after the boundary changed only to serve M3 or M4, so they were restored to their boundary version (`git checkout 901f056^ -- <file>`). Three kept improvements unrelated to M3 and M4 stay: the duplicate-review token restart (`DirectoryDuplicateGate` and its test), the error-summary disclosure opening (`form_error_summary_controller.js`), and the Chromium system-test setup and shared temporary-database helper. The Tailwind stylesheet keeps its M3 and M4 rules for now; no kept view uses them, and they go when Slice 1 restyles the screens.

## Execution

On branch `phase-1/delete-m3-m4`, in this order, so each step can be checked:

1. Tag `pre-m3-m4-deletion` on `main` and push the tag.
2. Delete the 899 files (a script generated from the boundary commit, committed with the branch so the list can be reviewed).
3. Edit the kept files listed above.
4. Add `DropM3AndM4Layers`, run it, and commit the regenerated `db/structure.sql`.
5. Update the documentation above.

### Done when

- `bin/rails zeitwerk:check` passes, so no constant points at deleted code.
- `bin/rails test` and `bin/rails test:system` pass.
- `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit` and `bin/importmap audit` pass (the five CI checks).
- `db/structure.sql` lists only the 30 kept tables, their 17 trigger functions and `dd_search_normalize`.
- A search of `app/`, `config/` and `test/` for `SupplierArrangement`, `ServiceOffer`, `Package`, `Capacity` and `composition` finds nothing outside comments.
- Signing in, the directories and the Departure lifecycle (create, activate, correct, mark Departed) work in the browser.
