# frozen_string_literal: true

# Phase 1 (D-66): drop the shipped supplier-planning (M3) and offer (M4) layers.
# See docs/planning/first-slice/phase-1-m3-m4-deletion-inventory.md. No data is kept:
# there is no real agency data, and the Alpha fixture is seeded fresh (ADR 0018).
class DropM3AndM4Layers < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      DROP TABLE
        agency_command_idempotency_keys,
        arrangement_item_definitions,
        arrangement_item_setup_results,
        arrangement_items,
        capacity_events,
        capacity_pair_definitions,
        capacity_pool_definitions,
        capacity_pools,
        capacity_projections,
        capacity_reconciliation_resolutions,
        capacity_reconciliations,
        package_client_cancellation_policies,
        package_client_cancellation_tiers,
        package_client_payment_schedule_lines,
        package_client_payment_schedules,
        package_client_stated_conditions,
        package_client_term_resolutions,
        package_inclusions,
        package_price_component_bases,
        package_price_components,
        package_price_definitions,
        package_publication_manifests,
        package_publication_result_service_versions,
        package_publication_results,
        package_version_sales_states,
        package_versions,
        packages,
        service_occurrence_definitions,
        service_occurrences,
        service_offer_choice_groups,
        service_offer_choice_option_source_activations,
        service_offer_choice_options,
        service_offer_client_cancellation_policies,
        service_offer_client_cancellation_tiers,
        service_offer_client_payment_schedule_lines,
        service_offer_client_payment_schedules,
        service_offer_client_stated_conditions,
        service_offer_definitions,
        service_offer_price_component_bases,
        service_offer_price_components,
        service_offer_price_definitions,
        service_offer_publication_manifests,
        service_offer_source_bindings,
        service_offer_version_sales_states,
        service_offer_versions,
        service_offers,
        supplier_agreement_reference_absences,
        supplier_agreement_references,
        supplier_amount_due_contributors,
        supplier_amount_due_definitions,
        supplier_arrangement_activation_capacity_entries,
        supplier_arrangement_activation_cost_selections,
        supplier_arrangement_activations,
        supplier_arrangement_commercial_benefit_definitions,
        supplier_arrangement_commercial_benefits,
        supplier_arrangement_cruise_agreement_confirmations,
        supplier_arrangement_cruise_capacity_deposit_requirements,
        supplier_arrangement_cruise_term_definitions,
        supplier_arrangement_ending_previews,
        supplier_arrangement_endings,
        supplier_arrangement_versions,
        supplier_arrangements,
        supplier_attention_findings,
        supplier_commitment_dispositions,
        supplier_commitment_evidence_coverage_members,
        supplier_commitment_evidence_coverage_revocations,
        supplier_commitment_evidence_coverages,
        supplier_commitment_evidence_member_disqualifications,
        supplier_commitment_reopenings,
        supplier_commitment_trigger_definitions,
        supplier_commitments,
        supplier_confirmation_activation_links,
        supplier_confirmation_capacity_event_links,
        supplier_confirmation_commitment_links,
        supplier_confirmation_identifier_links,
        supplier_confirmation_reservation_response_links,
        supplier_confirmation_reservation_scope_links,
        supplier_confirmations,
        supplier_cost_component_bases,
        supplier_cost_components,
        supplier_cost_definitions,
        supplier_cost_occupancy_profile_positions,
        supplier_cost_occupancy_profiles,
        supplier_cost_participant_categories,
        supplier_cost_sources,
        supplier_cost_usage_assumptions,
        supplier_deadline_commitment_definition_lines,
        supplier_deadline_definition_coverage_links,
        supplier_deadline_definitions,
        supplier_deadline_occurrences,
        supplier_deadline_projections,
        supplier_deposit_external_attestations,
        supplier_deposit_requirement_definition_contributor_links,
        supplier_deposit_requirement_definition_cost_links,
        supplier_deposit_requirement_definition_coverage_links,
        supplier_deposit_requirement_definitions,
        supplier_deposit_requirement_tranche_components,
        supplier_deposit_requirement_tranches,
        supplier_exposure_components,
        supplier_exposure_source_qualifications,
        supplier_exposure_summaries,
        supplier_issued_identifiers,
        supplier_operating_threshold_definitions,
        supplier_operating_threshold_outcomes,
        supplier_payment_requirement_definitions,
        supplier_planning_milestone_occurrences,
        supplier_reservation_event_scope_outcomes,
        supplier_reservation_events,
        supplier_reservation_projections,
        supplier_reservation_revisions,
        supplier_reservation_scopes,
        supplier_reservations,
        supplier_resource_definitions,
        supplier_resources
      CASCADE;
    SQL

    execute <<~SQL
      DROP FUNCTION public.allow_deadline_occurrence_supersession_only();
      DROP FUNCTION public.allow_deposit_tranche_derived_updates_only();
      DROP FUNCTION public.allow_supplier_identifier_supersession_stamp();
      DROP FUNCTION public.clear_supplier_cost_component_bases_for_kind();
      DROP FUNCTION public.enforce_commitment_disposition_coverage_purpose();
      DROP FUNCTION public.enforce_service_offer_version_package_ownership();
      DROP FUNCTION public.lock_version_before_supplier_confirmation();
      DROP FUNCTION public.reject_activity_outcome_revision();
      DROP FUNCTION public.reject_arrangement_item_definition_owner_change();
      DROP FUNCTION public.reject_arrangement_item_owner_change();
      DROP FUNCTION public.reject_capacity_event_mutation();
      DROP FUNCTION public.reject_capacity_pair_definition_owner_change();
      DROP FUNCTION public.reject_capacity_pair_for_cancelled_occurrence();
      DROP FUNCTION public.reject_capacity_pool_definition_owner_change();
      DROP FUNCTION public.reject_capacity_pool_owner_change();
      DROP FUNCTION public.reject_capacity_projection_owner_change();
      DROP FUNCTION public.reject_capacity_reconciliation_mutation();
      DROP FUNCTION public.reject_capacity_reconciliation_resolution_mutation();
      DROP FUNCTION public.reject_commercial_benefit_definition_owner_change();
      DROP FUNCTION public.reject_confirmed_activity_definition_mutation();
      DROP FUNCTION public.reject_confirmed_agreement_reference_mutation();
      DROP FUNCTION public.reject_confirmed_lodging_definition_mutation();
      DROP FUNCTION public.reject_confirmed_transportation_definition_mutation();
      DROP FUNCTION public.reject_cruise_agreement_confirmation_owner_change();
      DROP FUNCTION public.reject_cruise_term_definition_owner_change();
      DROP FUNCTION public.reject_deadline_commitment_line_owner_change();
      DROP FUNCTION public.reject_evidence_member_after_disposition();
      DROP FUNCTION public.reject_illegal_supplier_arrangement_version_lifecycle();
      DROP FUNCTION public.reject_incompatible_reservation_outcome();
      DROP FUNCTION public.reject_invalid_capacity_pool_zone();
      DROP FUNCTION public.reject_invalid_package_version_lifecycle();
      DROP FUNCTION public.reject_invalid_service_occurrence_definition_zone();
      DROP FUNCTION public.reject_invalid_service_offer_source_binding_ancestry();
      DROP FUNCTION public.reject_invalid_service_offer_version_lifecycle();
      DROP FUNCTION public.reject_m3d_immutable_mutation();
      DROP FUNCTION public.reject_mixed_agreement_reference_scope();
      DROP FUNCTION public.reject_non_draft_arrangement_version_definition_mutation();
      DROP FUNCTION public.reject_non_draft_package_version_definition_mutation();
      DROP FUNCTION public.reject_non_draft_service_offer_version_definition_mutation();
      DROP FUNCTION public.reject_noncommissionable_expected_commission();
      DROP FUNCTION public.reject_nonnumeric_capacity_event();
      DROP FUNCTION public.reject_nonnumeric_capacity_pool_definition_quantity();
      DROP FUNCTION public.reject_nonnumeric_capacity_projection();
      DROP FUNCTION public.reject_nonnumeric_capacity_reconciliation();
      DROP FUNCTION public.reject_package_inclusion_owner_change();
      DROP FUNCTION public.reject_package_owner_change();
      DROP FUNCTION public.reject_package_version_owner_change();
      DROP FUNCTION public.reject_publication_manifest_mutation();
      DROP FUNCTION public.reject_requested_reservation_scope_mutation();
      DROP FUNCTION public.reject_reservation_scope_without_capacity_pool_definition();
      DROP FUNCTION public.reject_second_current_commitment_disposition();
      DROP FUNCTION public.reject_service_occurrence_definition_owner_change();
      DROP FUNCTION public.reject_service_occurrence_owner_change();
      DROP FUNCTION public.reject_service_offer_definition_owner_change();
      DROP FUNCTION public.reject_service_offer_item_claim_change();
      DROP FUNCTION public.reject_service_offer_owner_change();
      DROP FUNCTION public.reject_service_offer_price_component_base_owner_change();
      DROP FUNCTION public.reject_service_offer_price_component_owner_change();
      DROP FUNCTION public.reject_service_offer_price_definition_owner_change();
      DROP FUNCTION public.reject_service_offer_source_binding_owner_change();
      DROP FUNCTION public.reject_service_offer_version_owner_change();
      DROP FUNCTION public.reject_supplier_arrangement_owner_change();
      DROP FUNCTION public.reject_supplier_arrangement_version_owner_change();
      DROP FUNCTION public.reject_supplier_commitment_trigger_definition_owner_change();
      DROP FUNCTION public.reject_supplier_cost_component_basis_owner_change();
      DROP FUNCTION public.reject_supplier_cost_component_owner_change();
      DROP FUNCTION public.reject_supplier_cost_definition_owner_change();
      DROP FUNCTION public.reject_supplier_cost_definition_stage_change();
      DROP FUNCTION public.reject_supplier_cost_occupancy_profile_owner_change();
      DROP FUNCTION public.reject_supplier_cost_occupancy_profile_position_owner_change();
      DROP FUNCTION public.reject_supplier_cost_participant_category_owner_change();
      DROP FUNCTION public.reject_supplier_cost_source_owner_change();
      DROP FUNCTION public.reject_supplier_cost_usage_assumption_owner_change();
      DROP FUNCTION public.reject_supplier_deadline_definition_owner_change();
      DROP FUNCTION public.reject_supplier_deposit_definition_owner_change();
      DROP FUNCTION public.reject_supplier_reservation_owner_change();
      DROP FUNCTION public.reject_supplier_resource_definition_owner_change();
      DROP FUNCTION public.reject_supplier_resource_owner_change();
      DROP FUNCTION public.reject_supplier_term_owner_change();
      DROP FUNCTION public.reject_ungoverning_activity_outcome();
      DROP FUNCTION public.stamp_supplier_identifier_superseded_by_successor();
      DROP FUNCTION public.validate_package_inclusion_origin();
      DROP FUNCTION public.validate_service_offer_price_component();
      DROP FUNCTION public.validate_service_offer_price_component_base();
      DROP FUNCTION public.validate_service_offer_price_component_link_invariants();
      DROP FUNCTION public.validate_supplier_cost_component();
      DROP FUNCTION public.validate_supplier_cost_component_base();
      DROP FUNCTION public.validate_supplier_cost_definition_mode_change();
      DROP FUNCTION public.validate_package_ownership_inclusion_match();
      DROP FUNCTION public.activity_attraction_item(uuid, uuid);
      DROP FUNCTION public.transportation_ceiling_item(uuid, uuid);
      DROP FUNCTION public.lodging_coverage_affects_version(uuid, uuid, uuid, uuid, uuid);
    SQL

    remove_index :departures, name: "index_departures_on_id_agency_currency"
    remove_index :supplier_contacts, name: "index_supplier_contacts_on_id_supplier_agency"

    remove_check_constraint :departures, name: "departures_target_timing_text"
    remove_column :departures, :target_timing_text
    remove_check_constraint :agencies, name: "agencies_attention_warning_lead_days"
    remove_column :agencies, :attention_warning_lead_days
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
