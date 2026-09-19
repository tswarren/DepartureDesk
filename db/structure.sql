SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


--
-- Name: allow_deadline_occurrence_supersession_only(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.allow_deadline_occurrence_supersession_only() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.id IS DISTINCT FROM OLD.id
    OR NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
    OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
    OR NEW.supplier_arrangement_version_id IS DISTINCT FROM OLD.supplier_arrangement_version_id
    OR NEW.supplier_deadline_definition_id IS DISTINCT FROM OLD.supplier_deadline_definition_id
    OR NEW.supplier_arrangement_activation_id IS DISTINCT FROM OLD.supplier_arrangement_activation_id
    OR NEW.deadline_type IS DISTINCT FROM OLD.deadline_type
    OR NEW.other_label IS DISTINCT FROM OLD.other_label
    OR NEW.kind IS DISTINCT FROM OLD.kind
    OR NEW.rule_shape IS DISTINCT FROM OLD.rule_shape
    OR NEW.rule_parameters_snapshot IS DISTINCT FROM OLD.rule_parameters_snapshot
    OR NEW.rule_inputs_snapshot IS DISTINCT FROM OLD.rule_inputs_snapshot
    OR NEW.precision IS DISTINCT FROM OLD.precision
    OR NEW.time_zone IS DISTINCT FROM OLD.time_zone
    OR NEW.cardinality IS DISTINCT FROM OLD.cardinality
    OR NEW.coverage_snapshot IS DISTINCT FROM OLD.coverage_snapshot
    OR NEW.calculated_on IS DISTINCT FROM OLD.calculated_on
    OR NEW.calculated_at IS DISTINCT FROM OLD.calculated_at
    OR NEW.materialization_key IS DISTINCT FROM OLD.materialization_key
    OR NEW.predecessor_occurrence_id IS DISTINCT FROM OLD.predecessor_occurrence_id
    OR NEW.actor_id IS DISTINCT FROM OLD.actor_id
    OR NEW.materialized_at IS DISTINCT FROM OLD.materialized_at
    OR NEW.created_at IS DISTINCT FROM OLD.created_at
  THEN
    RAISE EXCEPTION 'supplier_deadline_occurrences is append-only';
  END IF;
  IF OLD.superseded_at IS NOT NULL THEN
    RAISE EXCEPTION 'supplier_deadline_occurrences is append-only';
  END IF;
  IF NEW.superseded_at IS NULL THEN
    RAISE EXCEPTION 'supplier_deadline_occurrences is append-only';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: allow_supplier_identifier_supersession_stamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.allow_supplier_identifier_supersession_stamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF OLD.superseded_at IS NULL
    AND NEW.superseded_at IS NOT NULL
    AND NEW.id IS NOT DISTINCT FROM OLD.id
    AND NEW.created_at IS NOT DISTINCT FROM OLD.created_at
    AND NEW.updated_at IS NOT DISTINCT FROM OLD.updated_at
    AND NEW.supersedes_id IS NOT DISTINCT FROM OLD.supersedes_id
    AND NEW.agency_id IS NOT DISTINCT FROM OLD.agency_id
    AND NEW.departure_id IS NOT DISTINCT FROM OLD.departure_id
    AND NEW.supplier_arrangement_id IS NOT DISTINCT FROM OLD.supplier_arrangement_id
    AND NEW.supplier_reservation_id IS NOT DISTINCT FROM OLD.supplier_reservation_id
    AND NEW.supplier_id IS NOT DISTINCT FROM OLD.supplier_id
    AND NEW.issuer_context IS NOT DISTINCT FROM OLD.issuer_context
    AND NEW.identifier_type IS NOT DISTINCT FROM OLD.identifier_type
    AND NEW.other_type_label IS NOT DISTINCT FROM OLD.other_type_label
    AND NEW.display_value IS NOT DISTINCT FROM OLD.display_value
    AND NEW.normalized_value IS NOT DISTINCT FROM OLD.normalized_value
    AND NEW.first_supplier_confirmation_id IS NOT DISTINCT FROM OLD.first_supplier_confirmation_id
  THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'supplier_issued_identifiers is append-only';
END;
$$;


--
-- Name: clear_supplier_cost_component_bases_for_kind(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clear_supplier_cost_component_bases_for_kind() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.calculation_kind IS DISTINCT FROM OLD.calculation_kind AND
     NEW.calculation_kind IN ('fixed', 'unit_rate') THEN
    DELETE FROM supplier_cost_component_bases
     WHERE supplier_cost_component_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: dd_search_normalize(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dd_search_normalize(input text) RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    RETURN regexp_replace(btrim(NORMALIZE(casefold((NORMALIZE(input, NFKC) COLLATE pg_unicode_fast)), NFKC)), '[[:space:]]+'::text, ' '::text, 'g'::text);


--
-- Name: enforce_commitment_disposition_coverage_purpose(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_commitment_disposition_coverage_purpose() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE coverage_purpose text; BEGIN IF NEW.supplier_commitment_evidence_coverage_id IS NULL THEN RETURN NEW; END IF; SELECT purpose INTO coverage_purpose FROM supplier_commitment_evidence_coverages WHERE id = NEW.supplier_commitment_evidence_coverage_id; IF coverage_purpose IS DISTINCT FROM NEW.outcome THEN RAISE EXCEPTION 'disposition outcome must match evidence coverage purpose' USING ERRCODE = 'check_violation'; END IF; RETURN NEW; END; $$;


--
-- Name: reject_agency_user_agency_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_agency_user_agency_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id THEN
    RAISE EXCEPTION 'agency_id is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_agency_workspace_code_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_agency_workspace_code_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.workspace_code IS DISTINCT FROM OLD.workspace_code THEN
    RAISE EXCEPTION 'workspace_code is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_arrangement_item_definition_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_arrangement_item_definition_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.supplier_arrangement_version_id IS DISTINCT FROM OLD.supplier_arrangement_version_id
          OR NEW.arrangement_item_id IS DISTINCT FROM OLD.arrangement_item_id THEN
    RAISE EXCEPTION 'arrangement item definition owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_arrangement_item_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_arrangement_item_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
    OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id THEN
    RAISE EXCEPTION 'arrangement item owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_audit_event_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_audit_event_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'audit events are append-only';
END;
$$;


--
-- Name: reject_capacity_event_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_capacity_event_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'capacity event is append-only';
END;
$$;


--
-- Name: reject_capacity_pair_definition_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_capacity_pair_definition_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.supplier_arrangement_version_id IS DISTINCT FROM OLD.supplier_arrangement_version_id
          OR NEW.arrangement_item_id IS DISTINCT FROM OLD.arrangement_item_id
          OR NEW.service_occurrence_id IS DISTINCT FROM OLD.service_occurrence_id
          OR NEW.supplier_resource_id IS DISTINCT FROM OLD.supplier_resource_id THEN
    RAISE EXCEPTION 'capacity pair definition owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_capacity_pair_for_cancelled_occurrence(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_capacity_pair_for_cancelled_occurrence() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM service_occurrences
    WHERE id = NEW.service_occurrence_id
      AND agency_id = NEW.agency_id
      AND status = 'cancelled'
  ) THEN
    RAISE EXCEPTION 'capacity pair cannot be created for a cancelled occurrence';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_capacity_pool_definition_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_capacity_pool_definition_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.supplier_arrangement_version_id IS DISTINCT FROM OLD.supplier_arrangement_version_id
          OR NEW.arrangement_item_id IS DISTINCT FROM OLD.arrangement_item_id
          OR NEW.service_occurrence_id IS DISTINCT FROM OLD.service_occurrence_id
          OR NEW.supplier_resource_id IS DISTINCT FROM OLD.supplier_resource_id
          OR NEW.capacity_pair_definition_id IS DISTINCT FROM OLD.capacity_pair_definition_id
          OR NEW.capacity_pool_id IS DISTINCT FROM OLD.capacity_pool_id THEN
    RAISE EXCEPTION 'capacity pool definition owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_capacity_pool_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_capacity_pool_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.arrangement_item_id IS DISTINCT FROM OLD.arrangement_item_id
          OR NEW.service_occurrence_id IS DISTINCT FROM OLD.service_occurrence_id
          OR NEW.supplier_resource_id IS DISTINCT FROM OLD.supplier_resource_id
          OR NEW.supplying_supplier_id IS DISTINCT FROM OLD.supplying_supplier_id
          OR NEW.inventory_mode IS DISTINCT FROM OLD.inventory_mode
          OR NEW.measurement_basis IS DISTINCT FROM OLD.measurement_basis
          OR NEW.effective_time_zone IS DISTINCT FROM OLD.effective_time_zone THEN
    RAISE EXCEPTION 'capacity pool semantic identity is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_capacity_projection_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_capacity_projection_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.arrangement_item_id IS DISTINCT FROM OLD.arrangement_item_id
          OR NEW.service_occurrence_id IS DISTINCT FROM OLD.service_occurrence_id
          OR NEW.supplier_resource_id IS DISTINCT FROM OLD.supplier_resource_id
          OR NEW.capacity_pool_id IS DISTINCT FROM OLD.capacity_pool_id THEN
    RAISE EXCEPTION 'capacity projection owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_capacity_reconciliation_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_capacity_reconciliation_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'capacity reconciliation is append-only';
END;
$$;


--
-- Name: reject_capacity_reconciliation_resolution_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_capacity_reconciliation_resolution_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'capacity reconciliation resolution is append-only';
END;
$$;


--
-- Name: reject_client_identity_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_client_identity_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.client_person_id IS DISTINCT FROM OLD.client_person_id
    OR NEW.client_organization_id IS DISTINCT FROM OLD.client_organization_id
    OR NEW.client_reference IS DISTINCT FROM OLD.client_reference THEN
    RAISE EXCEPTION 'client identity is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_client_organization_contact_identity_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_client_organization_contact_identity_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.client_organization_id IS DISTINCT FROM OLD.client_organization_id
    OR NEW.client_person_id IS DISTINCT FROM OLD.client_person_id THEN
    RAISE EXCEPTION 'organization contact identity is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_client_organization_contact_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_client_organization_contact_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.client_organization_id IS DISTINCT FROM OLD.client_organization_id THEN
    RAISE EXCEPTION 'contact-point owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_client_person_contact_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_client_person_contact_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.client_person_id IS DISTINCT FROM OLD.client_person_id THEN
    RAISE EXCEPTION 'contact-point owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_departure_identity_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_departure_identity_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id THEN
    RAISE EXCEPTION 'departure identity is immutable';
  END IF;
  IF OLD.departure_reference IS NOT NULL
    AND NEW.departure_reference IS DISTINCT FROM OLD.departure_reference THEN
    RAISE EXCEPTION 'departure identity is immutable';
  END IF;
  IF OLD.first_activated_at IS NOT NULL
    AND NEW.first_activated_at IS DISTINCT FROM OLD.first_activated_at THEN
    RAISE EXCEPTION 'departure identity is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_directory_agency_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_directory_agency_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id THEN
    RAISE EXCEPTION 'agency_id is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_evidence_member_after_disposition(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_evidence_member_after_disposition() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF EXISTS ( SELECT 1 FROM supplier_commitment_dispositions WHERE supplier_commitment_evidence_coverage_id = NEW.supplier_commitment_evidence_coverage_id ) THEN RAISE EXCEPTION 'evidence coverage membership is sealed after disposition' USING ERRCODE = 'check_violation'; END IF; RETURN NEW; END; $$;


--
-- Name: reject_illegal_supplier_arrangement_version_lifecycle(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_illegal_supplier_arrangement_version_lifecycle() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
    IF OLD.status = 'draft' THEN
      RETURN NEW;
    END IF;
    RAISE EXCEPTION 'supplier arrangement version lifecycle is immutable except for accepted transitions';
  END IF;

  IF OLD.status = 'draft' AND NEW.status = 'activated' THEN
    IF NEW.activated_at IS NULL
      OR NEW.superseded_at IS NOT NULL
      OR NEW.abandoned_at IS NOT NULL
      OR NEW.abandoned_reason IS NOT NULL
    THEN
      RAISE EXCEPTION 'supplier arrangement version lifecycle transition is invalid';
    END IF;
    RETURN NEW;
  END IF;

  IF OLD.status = 'activated' AND NEW.status = 'superseded' THEN
    IF NEW.activated_at IS DISTINCT FROM OLD.activated_at
      OR NEW.superseded_at IS NULL
      OR NEW.abandoned_at IS NOT NULL
      OR NEW.abandoned_reason IS NOT NULL
    THEN
      RAISE EXCEPTION 'supplier arrangement version lifecycle transition is invalid';
    END IF;
    RETURN NEW;
  END IF;

  IF OLD.status = 'draft' AND NEW.status = 'abandoned' THEN
    IF NEW.abandoned_at IS NULL
      OR NEW.abandoned_reason IS NULL
      OR NEW.activated_at IS NOT NULL
      OR NEW.superseded_at IS NOT NULL
    THEN
      RAISE EXCEPTION 'supplier arrangement version lifecycle transition is invalid';
    END IF;
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'supplier arrangement version lifecycle transition is not permitted';
END;
$$;


--
-- Name: reject_incompatible_reservation_outcome(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_incompatible_reservation_outcome() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  parent_event_kind text;
  allowed boolean := false;
BEGIN
  SELECT event_kind INTO parent_event_kind
  FROM public.supplier_reservation_events
  WHERE id = NEW.supplier_reservation_event_id;

  IF parent_event_kind IS NULL THEN
    RAISE EXCEPTION 'reservation outcome requires a parent event';
  END IF;

  IF parent_event_kind = 'request' AND NEW.outcome_kind = 'requested' THEN
    allowed := true;
  ELSIF parent_event_kind = 'withdrawal' AND NEW.outcome_kind = 'withdrawn' THEN
    allowed := true;
  ELSIF parent_event_kind = 'cancellation' AND NEW.outcome_kind = 'cancelled' THEN
    allowed := true;
  ELSIF parent_event_kind = 'response'
    AND NEW.outcome_kind IN ('confirmed', 'declined', 'counterproposed') THEN
    allowed := true;
  END IF;

  IF NOT allowed THEN
    RAISE EXCEPTION 'reservation outcome kind is incompatible with parent event kind';
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: reject_invalid_capacity_pool_zone(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_invalid_capacity_pool_zone() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_timezone_names
    WHERE name = NEW.effective_time_zone
  ) THEN
    RAISE EXCEPTION 'capacity pool effective_time_zone is not a recognized IANA timezone';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_invalid_service_occurrence_definition_zone(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_invalid_service_occurrence_definition_zone() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_timezone_names
    WHERE name = NEW.time_zone
  ) THEN
    RAISE EXCEPTION 'service occurrence definition time_zone is not a recognized IANA timezone';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_m3d_immutable_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_m3d_immutable_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION '% is append-only', TG_TABLE_NAME;
END;
$$;


--
-- Name: reject_non_draft_arrangement_version_definition_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_non_draft_arrangement_version_definition_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  version_id uuid;
  version_status text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    version_id := NEW.supplier_arrangement_version_id;
    -- Serialize against activation: either finish before activation reads the
    -- graph, or wait and re-check status after activation commits. UPDATE and
    -- DELETE already serialize on existing definition-row locks held by
    -- activation.
    SELECT status INTO version_status
    FROM public.supplier_arrangement_versions
    WHERE id = version_id
    FOR SHARE;
  ELSE
    version_id := OLD.supplier_arrangement_version_id;
    SELECT status INTO version_status
    FROM public.supplier_arrangement_versions
    WHERE id = version_id;
  END IF;

  IF version_status IS DISTINCT FROM 'draft' THEN
    RAISE EXCEPTION 'exact-version definitions are immutable after leaving draft';
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_nonnumeric_capacity_event(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_nonnumeric_capacity_event() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  pool_mode text;
BEGIN
  SELECT inventory_mode INTO pool_mode FROM capacity_pools WHERE id = NEW.capacity_pool_id;
  IF pool_mode IN ('on_request', 'externally_managed') THEN
    RAISE EXCEPTION 'nonnumeric capacity pools cannot store capacity events';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_nonnumeric_capacity_pool_definition_quantity(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_nonnumeric_capacity_pool_definition_quantity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  pool_mode text;
BEGIN
  SELECT inventory_mode INTO pool_mode FROM capacity_pools WHERE id = NEW.capacity_pool_id;
  IF pool_mode IN ('on_request', 'externally_managed') AND NEW.proposed_opening_quantity IS NOT NULL THEN
    RAISE EXCEPTION 'nonnumeric capacity pools cannot store a proposed opening quantity';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_nonnumeric_capacity_projection(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_nonnumeric_capacity_projection() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  pool_mode text;
BEGIN
  SELECT inventory_mode INTO pool_mode FROM capacity_pools WHERE id = NEW.capacity_pool_id;
  IF pool_mode IN ('on_request', 'externally_managed') THEN
    RAISE EXCEPTION 'nonnumeric capacity pools cannot store projections';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_nonnumeric_capacity_reconciliation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_nonnumeric_capacity_reconciliation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  pool_mode text;
BEGIN
  SELECT inventory_mode INTO pool_mode FROM capacity_pools WHERE id = NEW.capacity_pool_id;
  IF pool_mode IN ('on_request', 'externally_managed') THEN
    RAISE EXCEPTION 'nonnumeric capacity pools cannot store reconciliations';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_office_identity_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_office_identity_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id OR NEW.code IS DISTINCT FROM OLD.code THEN
    RAISE EXCEPTION 'office identity is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_reference_sequence_identity_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_reference_sequence_identity_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.namespace IS DISTINCT FROM OLD.namespace THEN
    RAISE EXCEPTION 'reference sequence identity is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_requested_reservation_scope_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_requested_reservation_scope_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  revision_status text;
  revision_id uuid;
BEGIN
  IF TG_OP = 'INSERT' THEN
    revision_id := NEW.supplier_reservation_revision_id;
  ELSE
    revision_id := OLD.supplier_reservation_revision_id;
  END IF;

  SELECT status INTO revision_status
  FROM supplier_reservation_revisions
  WHERE id = revision_id;

  IF revision_status IS DISTINCT FROM 'planned' THEN
    RAISE EXCEPTION 'requested reservation scopes are immutable';
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_reservation_scope_without_capacity_pool_definition(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_reservation_scope_without_capacity_pool_definition() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.target_kind IS DISTINCT FROM 'capacity_pool' THEN
    RETURN NEW;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.capacity_pool_definitions definitions
    WHERE definitions.agency_id = NEW.agency_id
      AND definitions.supplier_arrangement_version_id = NEW.supplier_arrangement_version_id
      AND definitions.capacity_pool_id = NEW.capacity_pool_id
  ) THEN
    RAISE EXCEPTION 'reservation capacity pool scope requires a version definition';
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: reject_second_current_commitment_disposition(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_second_current_commitment_disposition() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF EXISTS ( SELECT 1 FROM supplier_commitment_dispositions d LEFT JOIN supplier_commitment_reopenings r ON r.supplier_commitment_disposition_id = d.id WHERE d.supplier_commitment_id = NEW.supplier_commitment_id AND r.id IS NULL ) THEN RAISE EXCEPTION 'commitment already has a current disposition' USING ERRCODE = 'check_violation'; END IF; RETURN NEW; END; $$;


--
-- Name: reject_service_occurrence_definition_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_service_occurrence_definition_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.supplier_arrangement_version_id IS DISTINCT FROM OLD.supplier_arrangement_version_id
          OR NEW.arrangement_item_id IS DISTINCT FROM OLD.arrangement_item_id
          OR NEW.service_occurrence_id IS DISTINCT FROM OLD.service_occurrence_id THEN
    RAISE EXCEPTION 'service occurrence definition owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_service_occurrence_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_service_occurrence_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
    OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
    OR NEW.arrangement_item_id IS DISTINCT FROM OLD.arrangement_item_id THEN
    RAISE EXCEPTION 'service occurrence owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_supplier_arrangement_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_supplier_arrangement_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
    OR NEW.contracting_supplier_id IS DISTINCT FROM OLD.contracting_supplier_id THEN
    RAISE EXCEPTION 'supplier arrangement owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_supplier_arrangement_version_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_supplier_arrangement_version_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
    OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
    OR NEW.version_number IS DISTINCT FROM OLD.version_number THEN
    RAISE EXCEPTION 'supplier arrangement version owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_supplier_category_identity_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_supplier_category_identity_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.supplier_id IS DISTINCT FROM OLD.supplier_id
    OR NEW.category_code IS DISTINCT FROM OLD.category_code THEN
    RAISE EXCEPTION 'supplier category assignment identity is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_supplier_commitment_trigger_definition_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_supplier_commitment_trigger_definition_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
    OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
    OR NEW.supplier_arrangement_version_id IS DISTINCT FROM OLD.supplier_arrangement_version_id
    OR NEW.copied_from_id IS DISTINCT FROM OLD.copied_from_id
  THEN
    RAISE EXCEPTION 'supplier commitment trigger definition owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_supplier_contact_destination_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_supplier_contact_destination_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.supplier_contact_id IS DISTINCT FROM OLD.supplier_contact_id THEN
    RAISE EXCEPTION 'supplier contact destination owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_supplier_contact_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_supplier_contact_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.supplier_id IS DISTINCT FROM OLD.supplier_id THEN
    RAISE EXCEPTION 'contact-point owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_supplier_contact_person_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_supplier_contact_person_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.supplier_id IS DISTINCT FROM OLD.supplier_id THEN
    RAISE EXCEPTION 'supplier contact owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_supplier_cost_component_basis_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_supplier_cost_component_basis_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.supplier_arrangement_version_id IS DISTINCT FROM OLD.supplier_arrangement_version_id
          OR NEW.supplier_cost_definition_id IS DISTINCT FROM OLD.supplier_cost_definition_id
          OR NEW.supplier_cost_component_id IS DISTINCT FROM OLD.supplier_cost_component_id
          OR NEW.base_component_id IS DISTINCT FROM OLD.base_component_id THEN
    RAISE EXCEPTION 'supplier_cost_component_basis owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_supplier_cost_component_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_supplier_cost_component_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.supplier_arrangement_version_id IS DISTINCT FROM OLD.supplier_arrangement_version_id
          OR NEW.supplier_cost_definition_id IS DISTINCT FROM OLD.supplier_cost_definition_id THEN
    RAISE EXCEPTION 'supplier_cost_component owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_supplier_cost_definition_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_supplier_cost_definition_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.supplier_arrangement_version_id IS DISTINCT FROM OLD.supplier_arrangement_version_id
          OR NEW.supplier_cost_source_id IS DISTINCT FROM OLD.supplier_cost_source_id THEN
    RAISE EXCEPTION 'supplier_cost_definition owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_supplier_cost_definition_stage_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_supplier_cost_definition_stage_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.stage IS DISTINCT FROM OLD.stage THEN
    RAISE EXCEPTION 'supplier cost definition stage is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_supplier_cost_occupancy_profile_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_supplier_cost_occupancy_profile_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.supplier_arrangement_version_id IS DISTINCT FROM OLD.supplier_arrangement_version_id
          OR NEW.arrangement_item_id IS DISTINCT FROM OLD.arrangement_item_id
          OR NEW.supplier_cost_usage_assumption_id IS DISTINCT FROM OLD.supplier_cost_usage_assumption_id THEN
    RAISE EXCEPTION 'supplier_cost_occupancy_profile owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_supplier_cost_occupancy_profile_position_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_supplier_cost_occupancy_profile_position_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.supplier_arrangement_version_id IS DISTINCT FROM OLD.supplier_arrangement_version_id
          OR NEW.arrangement_item_id IS DISTINCT FROM OLD.arrangement_item_id
          OR NEW.supplier_cost_usage_assumption_id IS DISTINCT FROM OLD.supplier_cost_usage_assumption_id
          OR NEW.supplier_cost_occupancy_profile_id IS DISTINCT FROM OLD.supplier_cost_occupancy_profile_id
          OR NEW.participant_category_id IS DISTINCT FROM OLD.participant_category_id
          OR NEW.occupancy_position IS DISTINCT FROM OLD.occupancy_position THEN
    RAISE EXCEPTION 'supplier_cost_occupancy_profile_position owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_supplier_cost_participant_category_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_supplier_cost_participant_category_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.supplier_arrangement_version_id IS DISTINCT FROM OLD.supplier_arrangement_version_id
          OR NEW.arrangement_item_id IS DISTINCT FROM OLD.arrangement_item_id THEN
    RAISE EXCEPTION 'supplier_cost_participant_category owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_supplier_cost_source_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_supplier_cost_source_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.supplier_arrangement_version_id IS DISTINCT FROM OLD.supplier_arrangement_version_id
          OR NEW.arrangement_item_id IS DISTINCT FROM OLD.arrangement_item_id
          OR NEW.service_occurrence_id IS DISTINCT FROM OLD.service_occurrence_id
          OR NEW.supplier_resource_id IS DISTINCT FROM OLD.supplier_resource_id
          OR NEW.charging_supplier_id IS DISTINCT FROM OLD.charging_supplier_id THEN
    RAISE EXCEPTION 'supplier_cost_source owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_supplier_cost_usage_assumption_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_supplier_cost_usage_assumption_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.supplier_arrangement_version_id IS DISTINCT FROM OLD.supplier_arrangement_version_id
          OR NEW.arrangement_item_id IS DISTINCT FROM OLD.arrangement_item_id
          OR NEW.service_occurrence_id IS DISTINCT FROM OLD.service_occurrence_id
          OR NEW.supplier_resource_id IS DISTINCT FROM OLD.supplier_resource_id THEN
    RAISE EXCEPTION 'supplier_cost_usage_assumption owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_supplier_deadline_definition_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_supplier_deadline_definition_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
    OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
    OR NEW.supplier_arrangement_version_id IS DISTINCT FROM OLD.supplier_arrangement_version_id
    OR NEW.copied_from_id IS DISTINCT FROM OLD.copied_from_id
  THEN
    RAISE EXCEPTION 'supplier deadline definition owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_supplier_identity_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_supplier_identity_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.kind IS DISTINCT FROM OLD.kind
    OR NEW.supplier_reference IS DISTINCT FROM OLD.supplier_reference THEN
    RAISE EXCEPTION 'supplier identity is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_supplier_location_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_supplier_location_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.supplier_id IS DISTINCT FROM OLD.supplier_id THEN
    RAISE EXCEPTION 'supplier location owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_supplier_reservation_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_supplier_reservation_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id <> OLD.agency_id OR
     NEW.departure_id <> OLD.departure_id OR
     NEW.supplier_arrangement_id <> OLD.supplier_arrangement_id OR
     NEW.booking_supplier_id <> OLD.booking_supplier_id THEN
    RAISE EXCEPTION 'supplier_reservations owner columns are immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_supplier_resource_definition_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_supplier_resource_definition_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.supplier_arrangement_version_id IS DISTINCT FROM OLD.supplier_arrangement_version_id
          OR NEW.arrangement_item_id IS DISTINCT FROM OLD.arrangement_item_id
          OR NEW.supplier_resource_id IS DISTINCT FROM OLD.supplier_resource_id THEN
    RAISE EXCEPTION 'supplier resource definition owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_supplier_resource_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_supplier_resource_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
    OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
    OR NEW.arrangement_item_id IS DISTINCT FROM OLD.arrangement_item_id THEN
    RAISE EXCEPTION 'supplier resource owner is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: stamp_supplier_identifier_superseded_by_successor(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.stamp_supplier_identifier_superseded_by_successor() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.supersedes_id IS NULL THEN
    RETURN NEW;
  END IF;

  UPDATE public.supplier_issued_identifiers
  SET superseded_at = COALESCE(NEW.created_at, CURRENT_TIMESTAMP)
  WHERE id = NEW.supersedes_id
    AND agency_id = NEW.agency_id
    AND departure_id = NEW.departure_id
    AND supplier_arrangement_id = NEW.supplier_arrangement_id
    AND supplier_id = NEW.supplier_id
    AND supplier_reservation_id IS NOT DISTINCT FROM NEW.supplier_reservation_id
    AND superseded_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'supplier identifier supersession target is missing, already superseded, or ownership differs';
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: validate_supplier_cost_component(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_supplier_cost_component() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE source_item uuid;
DECLARE definition_mode text;
BEGIN
  SELECT s.arrangement_item_id, d.mode INTO source_item, definition_mode
    FROM supplier_cost_definitions d
    JOIN supplier_cost_sources s ON s.id = d.supplier_cost_source_id
   WHERE d.id = NEW.supplier_cost_definition_id;
  IF definition_mode <> 'calculated' THEN
    RAISE EXCEPTION 'zero-cost definitions cannot contain components';
  END IF;
  IF source_item IS NULL AND
     (NEW.quantity_basis IS NOT NULL OR NEW.participant_category_id IS NOT NULL
      OR NEW.occupancy_position_from IS NOT NULL OR NEW.calculation_kind = 'minimum_quantity_shortfall') THEN
    RAISE EXCEPTION 'arrangement-wide cost components cannot use quantity inputs';
  END IF;
  IF NEW.participant_category_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM supplier_cost_participant_categories c
     WHERE c.id = NEW.participant_category_id AND c.arrangement_item_id = source_item
  ) THEN
    RAISE EXCEPTION 'cost component participant category must match source item';
  END IF;
  IF TG_OP = 'UPDATE' AND NEW.position IS DISTINCT FROM OLD.position AND (
    EXISTS (
      SELECT 1
        FROM supplier_cost_component_bases l
        JOIN supplier_cost_components b ON b.id = l.base_component_id
       WHERE l.supplier_cost_component_id = NEW.id
         AND b.position >= NEW.position
    ) OR EXISTS (
      SELECT 1
        FROM supplier_cost_component_bases l
        JOIN supplier_cost_components c ON c.id = l.supplier_cost_component_id
       WHERE l.base_component_id = NEW.id
         AND c.position <= NEW.position
    )
  ) THEN
    RAISE EXCEPTION 'cost component reorder would create a forward base';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: validate_supplier_cost_component_base(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_supplier_cost_component_base() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE component_position integer;
DECLARE component_kind text;
DECLARE component_basis text;
DECLARE component_category uuid;
DECLARE component_from integer;
DECLARE component_to integer;
DECLARE base_position integer;
DECLARE base_kind text;
DECLARE base_basis text;
DECLARE base_category uuid;
DECLARE base_from integer;
DECLARE base_to integer;
BEGIN
  SELECT position, calculation_kind, quantity_basis, participant_category_id,
         occupancy_position_from, occupancy_position_to
    INTO component_position, component_kind, component_basis, component_category,
         component_from, component_to
    FROM supplier_cost_components
   WHERE id = NEW.supplier_cost_component_id
     AND supplier_cost_definition_id = NEW.supplier_cost_definition_id;
  SELECT position, calculation_kind, quantity_basis, participant_category_id,
         occupancy_position_from, occupancy_position_to
    INTO base_position, base_kind, base_basis, base_category, base_from, base_to
    FROM supplier_cost_components
   WHERE id = NEW.base_component_id
     AND supplier_cost_definition_id = NEW.supplier_cost_definition_id;
  IF component_position IS NULL OR base_position IS NULL OR base_position >= component_position THEN
    RAISE EXCEPTION 'cost component base must be an earlier component in the same definition';
  END IF;
  IF component_kind NOT IN ('percentage', 'minimum_amount_shortfall', 'minimum_quantity_shortfall') THEN
    RAISE EXCEPTION 'cost component kind does not accept bases';
  END IF;
  IF component_kind = 'minimum_quantity_shortfall' AND
     (base_kind <> 'unit_rate' OR NEW.direction <> 'add') THEN
    RAISE EXCEPTION 'quantity minimum base must be one earlier unit rate';
  END IF;
  IF component_kind = 'minimum_quantity_shortfall' AND (
       component_basis IS DISTINCT FROM base_basis
    OR component_category IS DISTINCT FROM base_category
    OR component_from IS DISTINCT FROM base_from
    OR component_to IS DISTINCT FROM base_to
  ) THEN
    RAISE EXCEPTION 'quantity minimum base selectors must match the unit rate';
  END IF;
  IF component_kind = 'minimum_quantity_shortfall' AND EXISTS (
    SELECT 1 FROM supplier_cost_component_bases
     WHERE supplier_cost_component_id = NEW.supplier_cost_component_id
       AND id <> NEW.id
  ) THEN
    RAISE EXCEPTION 'quantity minimum accepts exactly one base';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: validate_supplier_cost_definition_mode_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_supplier_cost_definition_mode_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.mode = 'zero_cost' AND OLD.mode IS DISTINCT FROM 'zero_cost' AND EXISTS (
    SELECT 1 FROM supplier_cost_components c
     WHERE c.supplier_cost_definition_id = NEW.id
  ) THEN
    RAISE EXCEPTION 'zero-cost definitions cannot retain components';
  END IF;
  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: agencies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agencies (
    id uuid DEFAULT uuidv7() NOT NULL,
    name character varying NOT NULL,
    legal_name character varying,
    workspace_code character varying NOT NULL,
    country_code character varying(2) NOT NULL,
    default_currency character varying(3) NOT NULL,
    default_timezone character varying NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT agencies_country_code_format CHECK (((country_code)::text ~ '^[A-Z]{2}$'::text)),
    CONSTRAINT agencies_currency_format CHECK (((default_currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT agencies_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT agencies_name_not_blank CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT agencies_status_valid CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('suspended'::character varying)::text, ('closed'::character varying)::text]))),
    CONSTRAINT agencies_workspace_code_format CHECK (((workspace_code)::text ~ '^[a-z][a-z0-9-]{1,39}$'::text))
);


--
-- Name: agency_command_idempotency_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agency_command_idempotency_keys (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    command_name character varying(120) NOT NULL,
    idempotency_key character varying(120) NOT NULL,
    payload_digest character varying(128) NOT NULL,
    result_record_type character varying(120) NOT NULL,
    result_record_id uuid NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT agency_command_idempotency_keys_command_name CHECK (((btrim((command_name)::text) <> ''::text) AND (char_length((command_name)::text) <= 120))),
    CONSTRAINT agency_command_idempotency_keys_key CHECK (((btrim((idempotency_key)::text) <> ''::text) AND (char_length((idempotency_key)::text) <= 120))),
    CONSTRAINT agency_command_idempotency_keys_payload_digest CHECK (((btrim((payload_digest)::text) <> ''::text) AND (char_length((payload_digest)::text) <= 128))),
    CONSTRAINT agency_command_idempotency_keys_result_type CHECK (((btrim((result_record_type)::text) <> ''::text) AND (char_length((result_record_type)::text) <= 120)))
);


--
-- Name: agency_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agency_users (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    default_office_id uuid,
    email_address character varying NOT NULL,
    password_digest character varying,
    first_name character varying NOT NULL,
    last_name character varying NOT NULL,
    preferred_name character varying,
    title character varying,
    phone character varying,
    relationship character varying,
    access_role character varying NOT NULL,
    status character varying DEFAULT 'invited'::character varying NOT NULL,
    invitation_token_digest character varying,
    invitation_sent_at timestamp with time zone,
    invitation_expires_at timestamp with time zone,
    password_reset_token_digest character varying,
    password_reset_sent_at timestamp with time zone,
    password_reset_expires_at timestamp with time zone,
    credential_version integer DEFAULT 0 NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT agency_users_access_role_valid CHECK (((access_role)::text = ANY (ARRAY[('administrator'::character varying)::text, ('staff'::character varying)::text, ('viewer'::character varying)::text]))),
    CONSTRAINT agency_users_credential_version_nonnegative CHECK ((credential_version >= 0)),
    CONSTRAINT agency_users_email_normalized CHECK (((email_address)::text = lower(btrim((email_address)::text)))),
    CONSTRAINT agency_users_email_not_blank CHECK ((btrim((email_address)::text) <> ''::text)),
    CONSTRAINT agency_users_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT agency_users_name_not_blank CHECK (((btrim((first_name)::text) <> ''::text) AND (btrim((last_name)::text) <> ''::text))),
    CONSTRAINT agency_users_status_credentials CHECK (((((status)::text = 'invited'::text) AND (invitation_token_digest IS NOT NULL) AND (invitation_expires_at IS NOT NULL) AND (password_digest IS NULL)) OR (((status)::text = 'active'::text) AND (password_digest IS NOT NULL) AND (invitation_token_digest IS NULL)) OR (((status)::text = ANY (ARRAY[('suspended'::character varying)::text, ('closed'::character varying)::text])) AND (invitation_token_digest IS NULL)))),
    CONSTRAINT agency_users_status_valid CHECK (((status)::text = ANY (ARRAY[('invited'::character varying)::text, ('active'::character varying)::text, ('suspended'::character varying)::text, ('closed'::character varying)::text])))
);


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: arrangement_item_definitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.arrangement_item_definitions (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT arrangement_item_definition_supplier_arrangement_versi_not_null NOT NULL,
    arrangement_item_id uuid NOT NULL,
    name character varying(160) NOT NULL,
    description character varying(2000),
    category character varying NOT NULL,
    other_category_label character varying(80),
    default_service_provider_id uuid,
    "position" integer NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    capacity_management character varying,
    copied_from_id uuid,
    CONSTRAINT arrangement_item_definitions_capacity_management CHECK (((capacity_management IS NULL) OR ((capacity_management)::text = ANY ((ARRAY['managed'::character varying, 'unmanaged'::character varying])::text[])))),
    CONSTRAINT arrangement_item_definitions_category CHECK (((category)::text = ANY ((ARRAY['cruise'::character varying, 'lodging'::character varying, 'air'::character varying, 'ground_transportation'::character varying, 'dining'::character varying, 'activity_attraction'::character varying, 'insurance'::character varying, 'other'::character varying])::text[]))),
    CONSTRAINT arrangement_item_definitions_description CHECK (((description IS NULL) OR ((btrim((description)::text) <> ''::text) AND (char_length((description)::text) <= 2000)))),
    CONSTRAINT arrangement_item_definitions_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT arrangement_item_definitions_name CHECK (((btrim((name)::text) <> ''::text) AND (char_length((name)::text) <= 160))),
    CONSTRAINT arrangement_item_definitions_other_label CHECK (((((category)::text = 'other'::text) = (other_category_label IS NOT NULL)) AND ((other_category_label IS NULL) OR ((btrim((other_category_label)::text) <> ''::text) AND (char_length((other_category_label)::text) <= 80))))),
    CONSTRAINT arrangement_item_definitions_position_positive CHECK (("position" > 0))
);


--
-- Name: arrangement_item_setup_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.arrangement_item_setup_results (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    agency_command_idempotency_key_id uuid CONSTRAINT arrangement_item_setup_resu_agency_command_idempotency_not_null NOT NULL,
    arrangement_item_id uuid NOT NULL,
    service_occurrence_id uuid,
    supplier_resource_id uuid,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: arrangement_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.arrangement_items (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_events (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    action character varying NOT NULL,
    actor_kind character varying NOT NULL,
    actor_agency_user_id uuid,
    actor_identifier character varying,
    subject_type character varying,
    subject_id uuid,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT audit_events_actor_kind_valid CHECK (((actor_kind)::text = ANY (ARRAY[('agency_user'::character varying)::text, ('system'::character varying)::text]))),
    CONSTRAINT audit_events_actor_present CHECK (((((actor_kind)::text = 'agency_user'::text) AND (actor_agency_user_id IS NOT NULL) AND (actor_identifier IS NULL)) OR (((actor_kind)::text = 'system'::text) AND (actor_identifier IS NOT NULL) AND (btrim((actor_identifier)::text) <> ''::text) AND (actor_agency_user_id IS NULL))))
);


--
-- Name: capacity_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.capacity_events (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    supplier_arrangement_version_id uuid NOT NULL,
    arrangement_item_id uuid NOT NULL,
    service_occurrence_id uuid NOT NULL,
    supplier_resource_id uuid NOT NULL,
    capacity_pool_id uuid NOT NULL,
    supplying_supplier_id uuid NOT NULL,
    event_type character varying NOT NULL,
    quantity bigint NOT NULL,
    measurement_basis character varying NOT NULL,
    effective_on date NOT NULL,
    effective_time_zone character varying NOT NULL,
    applies_at timestamp with time zone NOT NULL,
    effective_sequence integer NOT NULL,
    recorded_at timestamp with time zone NOT NULL,
    evidence_kind character varying,
    evidence_on date,
    evidence_reference_note character varying(500),
    evidence_external_reference character varying(160),
    override boolean DEFAULT false NOT NULL,
    override_reason character varying(500),
    reinstates_event_id uuid,
    corrects_event_id uuid,
    capacity_reconciliation_id uuid,
    actor_id uuid NOT NULL,
    agency_command_idempotency_key_id uuid,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT capacity_events_correction_source_xor CHECK ((((event_type)::text <> ALL ((ARRAY['corrected_up'::character varying, 'corrected_down'::character varying])::text[])) OR ((corrects_event_id IS NOT NULL) <> (capacity_reconciliation_id IS NOT NULL)))),
    CONSTRAINT capacity_events_correction_sources_only CHECK ((((event_type)::text = ANY ((ARRAY['corrected_up'::character varying, 'corrected_down'::character varying])::text[])) OR ((corrects_event_id IS NULL) AND (capacity_reconciliation_id IS NULL)))),
    CONSTRAINT capacity_events_effective_time_zone CHECK ((btrim((effective_time_zone)::text) <> ''::text)),
    CONSTRAINT capacity_events_evidence_xor_override CHECK ((((override = false) AND (override_reason IS NULL) AND ((evidence_kind)::text = ANY ((ARRAY['contract'::character varying, 'supplier_confirmation'::character varying, 'supplier_message'::character varying, 'supplier_portal'::character varying, 'verbal_confirmation'::character varying, 'other'::character varying])::text[])) AND (evidence_on IS NOT NULL) AND (evidence_reference_note IS NOT NULL) AND (btrim((evidence_reference_note)::text) <> ''::text) AND (char_length((evidence_reference_note)::text) <= 500) AND ((evidence_external_reference IS NULL) OR ((btrim((evidence_external_reference)::text) <> ''::text) AND (char_length((evidence_external_reference)::text) <= 160)))) OR ((override = true) AND (override_reason IS NOT NULL) AND (btrim((override_reason)::text) <> ''::text) AND (char_length((override_reason)::text) <= 500) AND (evidence_kind IS NULL) AND (evidence_on IS NULL) AND (evidence_reference_note IS NULL) AND (evidence_external_reference IS NULL)))),
    CONSTRAINT capacity_events_measurement_basis CHECK (((measurement_basis)::text = ANY ((ARRAY['resource_units'::character varying, 'traveler_positions'::character varying])::text[]))),
    CONSTRAINT capacity_events_quantity_positive CHECK ((quantity > 0)),
    CONSTRAINT capacity_events_reinstates_pair CHECK ((((event_type)::text = 'reinstated'::text) = (reinstates_event_id IS NOT NULL))),
    CONSTRAINT capacity_events_sequence_positive CHECK ((effective_sequence > 0)),
    CONSTRAINT capacity_events_type CHECK (((event_type)::text = ANY ((ARRAY['established'::character varying, 'increased'::character varying, 'released'::character varying, 'reinstated'::character varying, 'withdrawn'::character varying, 'corrected_up'::character varying, 'corrected_down'::character varying])::text[])))
);


--
-- Name: capacity_pair_definitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.capacity_pair_definitions (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT capacity_pair_definitions_supplier_arrangement_version_not_null NOT NULL,
    arrangement_item_id uuid NOT NULL,
    service_occurrence_id uuid NOT NULL,
    supplier_resource_id uuid NOT NULL,
    classification character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    copied_from_id uuid,
    CONSTRAINT capacity_pair_definitions_classification CHECK (((classification)::text = ANY ((ARRAY['pooled'::character varying, 'not_applicable'::character varying])::text[]))),
    CONSTRAINT capacity_pair_definitions_lock_version CHECK ((lock_version >= 0))
);


--
-- Name: capacity_pool_definitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.capacity_pool_definitions (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT capacity_pool_definitions_supplier_arrangement_version_not_null NOT NULL,
    arrangement_item_id uuid NOT NULL,
    service_occurrence_id uuid NOT NULL,
    supplier_resource_id uuid NOT NULL,
    capacity_pair_definition_id uuid NOT NULL,
    capacity_pool_id uuid NOT NULL,
    label character varying(120) NOT NULL,
    normalized_label character varying(120) NOT NULL,
    notes character varying(2000),
    unit_label character varying(40) NOT NULL,
    proposed_opening_quantity bigint,
    evidence_kind character varying,
    evidence_on date,
    evidence_reference_note character varying(500),
    evidence_external_reference character varying(160),
    override boolean DEFAULT false NOT NULL,
    override_reason character varying(500),
    "position" integer NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    copied_from_id uuid,
    CONSTRAINT capacity_pool_defs_evidence_xor_override CHECK ((((override = false) AND (override_reason IS NULL) AND ((evidence_kind)::text = ANY ((ARRAY['contract'::character varying, 'supplier_confirmation'::character varying, 'supplier_message'::character varying, 'supplier_portal'::character varying, 'verbal_confirmation'::character varying, 'other'::character varying])::text[])) AND (evidence_on IS NOT NULL) AND (evidence_reference_note IS NOT NULL) AND (btrim((evidence_reference_note)::text) <> ''::text) AND (char_length((evidence_reference_note)::text) <= 500) AND ((evidence_external_reference IS NULL) OR ((btrim((evidence_external_reference)::text) <> ''::text) AND (char_length((evidence_external_reference)::text) <= 160)))) OR ((override = true) AND (override_reason IS NOT NULL) AND (btrim((override_reason)::text) <> ''::text) AND (char_length((override_reason)::text) <= 500) AND (evidence_kind IS NULL) AND (evidence_on IS NULL) AND (evidence_reference_note IS NULL) AND (evidence_external_reference IS NULL)) OR ((override = false) AND (override_reason IS NULL) AND (evidence_kind IS NULL) AND (evidence_on IS NULL) AND (evidence_reference_note IS NULL) AND (evidence_external_reference IS NULL)))),
    CONSTRAINT capacity_pool_defs_label CHECK (((btrim((label)::text) <> ''::text) AND (char_length((label)::text) <= 120))),
    CONSTRAINT capacity_pool_defs_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT capacity_pool_defs_normalized_label CHECK (((btrim((normalized_label)::text) <> ''::text) AND ((normalized_label)::text = lower(btrim((label)::text))) AND (char_length((normalized_label)::text) <= 120))),
    CONSTRAINT capacity_pool_defs_notes CHECK (((notes IS NULL) OR ((btrim((notes)::text) <> ''::text) AND (char_length((notes)::text) <= 2000)))),
    CONSTRAINT capacity_pool_defs_position_positive CHECK (("position" > 0)),
    CONSTRAINT capacity_pool_defs_proposed_qty CHECK (((proposed_opening_quantity IS NULL) OR (proposed_opening_quantity > 0))),
    CONSTRAINT capacity_pool_defs_unit_label CHECK (((btrim((unit_label)::text) <> ''::text) AND (char_length((unit_label)::text) <= 40)))
);


--
-- Name: capacity_pools; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.capacity_pools (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    arrangement_item_id uuid NOT NULL,
    service_occurrence_id uuid NOT NULL,
    supplier_resource_id uuid NOT NULL,
    supplying_supplier_id uuid NOT NULL,
    inventory_mode character varying NOT NULL,
    measurement_basis character varying NOT NULL,
    effective_time_zone character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT capacity_pools_effective_time_zone CHECK ((btrim((effective_time_zone)::text) <> ''::text)),
    CONSTRAINT capacity_pools_inventory_mode CHECK (((inventory_mode)::text = ANY ((ARRAY['block'::character varying, 'allotment'::character varying, 'on_request'::character varying, 'externally_managed'::character varying])::text[]))),
    CONSTRAINT capacity_pools_measurement_basis CHECK (((measurement_basis)::text = ANY ((ARRAY['resource_units'::character varying, 'traveler_positions'::character varying])::text[])))
);


--
-- Name: capacity_projections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.capacity_projections (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    arrangement_item_id uuid NOT NULL,
    service_occurrence_id uuid NOT NULL,
    supplier_resource_id uuid NOT NULL,
    capacity_pool_id uuid NOT NULL,
    current_supplier_capacity bigint DEFAULT 0 NOT NULL,
    last_event_id uuid,
    last_effective_on date,
    last_effective_sequence integer,
    last_recorded_at timestamp with time zone,
    next_applies_at timestamp with time zone,
    next_event_id uuid,
    rebuilt_at timestamp with time zone NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT capacity_projections_current_nonnegative CHECK ((current_supplier_capacity >= 0)),
    CONSTRAINT capacity_projections_lock_version CHECK ((lock_version >= 0))
);


--
-- Name: capacity_reconciliation_resolutions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.capacity_reconciliation_resolutions (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid CONSTRAINT capacity_reconciliation_resolu_supplier_arrangement_id_not_null NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT capacity_reconciliation_res_supplier_arrangement_versi_not_null NOT NULL,
    arrangement_item_id uuid CONSTRAINT capacity_reconciliation_resolution_arrangement_item_id_not_null NOT NULL,
    service_occurrence_id uuid CONSTRAINT capacity_reconciliation_resoluti_service_occurrence_id_not_null NOT NULL,
    supplier_resource_id uuid CONSTRAINT capacity_reconciliation_resolutio_supplier_resource_id_not_null NOT NULL,
    capacity_pool_id uuid NOT NULL,
    capacity_reconciliation_id uuid CONSTRAINT capacity_reconciliation_res_capacity_reconciliation_id_not_null NOT NULL,
    capacity_event_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    resolved_at timestamp with time zone NOT NULL,
    note character varying(500) NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT capacity_recon_resolutions_note CHECK (((btrim((note)::text) <> ''::text) AND (char_length((note)::text) <= 500)))
);


--
-- Name: capacity_reconciliations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.capacity_reconciliations (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT capacity_reconciliations_supplier_arrangement_version__not_null NOT NULL,
    arrangement_item_id uuid NOT NULL,
    service_occurrence_id uuid NOT NULL,
    supplier_resource_id uuid NOT NULL,
    capacity_pool_id uuid NOT NULL,
    observed_quantity bigint NOT NULL,
    observed_at timestamp with time zone NOT NULL,
    observed_time_zone character varying NOT NULL,
    ledger_quantity bigint NOT NULL,
    variance bigint NOT NULL,
    evidence_kind character varying,
    evidence_on date,
    evidence_reference_note character varying(500),
    evidence_external_reference character varying(160),
    override boolean DEFAULT false NOT NULL,
    override_reason character varying(500),
    actor_id uuid NOT NULL,
    recorded_at timestamp with time zone NOT NULL,
    agency_command_idempotency_key_id uuid,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT capacity_reconciliations_evidence_xor_override CHECK ((((override = false) AND (override_reason IS NULL) AND ((evidence_kind)::text = ANY ((ARRAY['contract'::character varying, 'supplier_confirmation'::character varying, 'supplier_message'::character varying, 'supplier_portal'::character varying, 'verbal_confirmation'::character varying, 'other'::character varying])::text[])) AND (evidence_on IS NOT NULL) AND (evidence_reference_note IS NOT NULL) AND (btrim((evidence_reference_note)::text) <> ''::text) AND (char_length((evidence_reference_note)::text) <= 500) AND ((evidence_external_reference IS NULL) OR ((btrim((evidence_external_reference)::text) <> ''::text) AND (char_length((evidence_external_reference)::text) <= 160)))) OR ((override = true) AND (override_reason IS NOT NULL) AND (btrim((override_reason)::text) <> ''::text) AND (char_length((override_reason)::text) <= 500) AND (evidence_kind IS NULL) AND (evidence_on IS NULL) AND (evidence_reference_note IS NULL) AND (evidence_external_reference IS NULL)))),
    CONSTRAINT capacity_reconciliations_ledger_nonnegative CHECK ((ledger_quantity >= 0)),
    CONSTRAINT capacity_reconciliations_observed_nonnegative CHECK ((observed_quantity >= 0)),
    CONSTRAINT capacity_reconciliations_observed_time_zone CHECK ((btrim((observed_time_zone)::text) <> ''::text)),
    CONSTRAINT capacity_reconciliations_variance CHECK ((variance = (observed_quantity - ledger_quantity)))
);


--
-- Name: client_organization_contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_organization_contacts (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_organization_id uuid NOT NULL,
    client_person_id uuid NOT NULL,
    starts_on date NOT NULL,
    ends_on date,
    title character varying,
    role_label character varying,
    "primary" boolean DEFAULT false NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT client_org_contacts_date_order CHECK (((ends_on IS NULL) OR (ends_on >= starts_on))),
    CONSTRAINT client_org_contacts_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT client_org_contacts_primary_requires_current CHECK (((ends_on IS NULL) OR (NOT "primary")))
);


--
-- Name: client_organization_email_addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_organization_email_addresses (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_organization_id uuid CONSTRAINT client_organization_email_addre_client_organization_id_not_null NOT NULL,
    label character varying(40),
    status character varying DEFAULT 'active'::character varying NOT NULL,
    preferred boolean DEFAULT false NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    address character varying NOT NULL,
    normalized_address text GENERATED ALWAYS AS (lower(btrim((address)::text))) STORED,
    CONSTRAINT client_org_email_addresses_label_length CHECK (((label IS NULL) OR (char_length((label)::text) <= 40))),
    CONSTRAINT client_org_email_addresses_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT client_org_email_addresses_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[]))),
    CONSTRAINT client_organization_email_addresses_normalized CHECK (((normalized_address = lower(btrim((address)::text))) AND (normalized_address <> ''::text)))
);


--
-- Name: client_organization_phone_numbers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_organization_phone_numbers (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_organization_id uuid CONSTRAINT client_organization_phone_numbe_client_organization_id_not_null NOT NULL,
    label character varying(40),
    status character varying DEFAULT 'active'::character varying NOT NULL,
    preferred boolean DEFAULT false NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    number character varying NOT NULL,
    normalized_number character varying NOT NULL,
    extension character varying,
    country_code character varying NOT NULL,
    phone_digits_reversed text GENERATED ALWAYS AS (reverse(SUBSTRING(normalized_number FROM 2))) STORED,
    CONSTRAINT client_org_phone_numbers_label_length CHECK (((label IS NULL) OR (char_length((label)::text) <= 40))),
    CONSTRAINT client_org_phone_numbers_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT client_org_phone_numbers_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[]))),
    CONSTRAINT client_organization_phone_numbers_country_shape CHECK (((country_code)::text ~ '^[A-Z]{2}$'::text)),
    CONSTRAINT client_organization_phone_numbers_e164_shape CHECK (((normalized_number)::text ~ '^\+[1-9][0-9]{0,14}$'::text)),
    CONSTRAINT client_organization_phone_numbers_extension CHECK (((extension IS NULL) OR ((extension)::text ~ '^[0-9]{1,10}$'::text)))
);


--
-- Name: client_organization_postal_addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_organization_postal_addresses (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_organization_id uuid CONSTRAINT client_organization_postal_addr_client_organization_id_not_null NOT NULL,
    label character varying(40),
    status character varying DEFAULT 'active'::character varying NOT NULL,
    preferred boolean DEFAULT false NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    line_1 character varying NOT NULL,
    line_2 character varying,
    locality character varying,
    region character varying,
    postal_code character varying,
    country_code character varying NOT NULL,
    postal_code_search_key text GENERATED ALWAYS AS (public.dd_search_normalize((postal_code)::text)) STORED,
    locality_search_key text GENERATED ALWAYS AS (public.dd_search_normalize((locality)::text)) STORED,
    CONSTRAINT client_org_postal_addresses_label_length CHECK (((label IS NULL) OR (char_length((label)::text) <= 40))),
    CONSTRAINT client_org_postal_addresses_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT client_org_postal_addresses_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[]))),
    CONSTRAINT client_organization_postal_addresses_country_shape CHECK (((country_code)::text ~ '^[A-Z]{2}$'::text)),
    CONSTRAINT client_organization_postal_addresses_line_1 CHECK ((btrim((line_1)::text) <> ''::text))
);


--
-- Name: client_organization_websites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_organization_websites (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_organization_id uuid NOT NULL,
    label character varying(40),
    status character varying DEFAULT 'active'::character varying NOT NULL,
    preferred boolean DEFAULT false NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    url character varying NOT NULL,
    normalized_url character varying NOT NULL,
    normalized_host character varying NOT NULL,
    CONSTRAINT client_org_websites_label_length CHECK (((label IS NULL) OR (char_length((label)::text) <= 40))),
    CONSTRAINT client_org_websites_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT client_org_websites_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[]))),
    CONSTRAINT client_organization_websites_normalized_host_present CHECK ((btrim((normalized_host)::text) <> ''::text)),
    CONSTRAINT client_organization_websites_normalized_url_present CHECK ((btrim((normalized_url)::text) <> ''::text)),
    CONSTRAINT client_organization_websites_url_present CHECK ((btrim((url)::text) <> ''::text))
);


--
-- Name: client_organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_organizations (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    display_name character varying NOT NULL,
    legal_name character varying,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    display_name_search_key text GENERATED ALWAYS AS (public.dd_search_normalize((display_name)::text)) STORED,
    legal_name_search_key text GENERATED ALWAYS AS (public.dd_search_normalize((legal_name)::text)) STORED,
    name_search_vector tsvector GENERATED ALWAYS AS (to_tsvector('simple'::regconfig, ((COALESCE(public.dd_search_normalize((display_name)::text), ''::text) || ' '::text) || COALESCE(public.dd_search_normalize((legal_name)::text), ''::text)))) STORED,
    CONSTRAINT client_organizations_display_name_present CHECK ((btrim((display_name)::text) <> ''::text)),
    CONSTRAINT client_organizations_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT client_organizations_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
);


--
-- Name: client_people; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_people (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    first_name character varying NOT NULL,
    middle_name character varying,
    last_name character varying NOT NULL,
    suffix character varying,
    preferred_name character varying,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    name_search_key text GENERATED ALWAYS AS (public.dd_search_normalize((((((((((first_name)::text || ' '::text) || (COALESCE(middle_name, ''::character varying))::text) || ' '::text) || (last_name)::text) || ' '::text) || (COALESCE(suffix, ''::character varying))::text) || ' '::text) || (COALESCE(preferred_name, ''::character varying))::text))) STORED,
    name_search_vector tsvector GENERATED ALWAYS AS (to_tsvector('simple'::regconfig, public.dd_search_normalize((((((((((first_name)::text || ' '::text) || (COALESCE(middle_name, ''::character varying))::text) || ' '::text) || (last_name)::text) || ' '::text) || (COALESCE(suffix, ''::character varying))::text) || ' '::text) || (COALESCE(preferred_name, ''::character varying))::text)))) STORED,
    CONSTRAINT client_people_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT client_people_names_present CHECK (((btrim((first_name)::text) <> ''::text) AND (btrim((last_name)::text) <> ''::text))),
    CONSTRAINT client_people_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
);


--
-- Name: client_person_email_addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_person_email_addresses (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_person_id uuid NOT NULL,
    label character varying(40),
    status character varying DEFAULT 'active'::character varying NOT NULL,
    preferred boolean DEFAULT false NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    address character varying NOT NULL,
    normalized_address text GENERATED ALWAYS AS (lower(btrim((address)::text))) STORED,
    CONSTRAINT client_person_email_addresses_label_length CHECK (((label IS NULL) OR (char_length((label)::text) <= 40))),
    CONSTRAINT client_person_email_addresses_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT client_person_email_addresses_normalized CHECK (((normalized_address = lower(btrim((address)::text))) AND (normalized_address <> ''::text))),
    CONSTRAINT client_person_email_addresses_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
);


--
-- Name: client_person_phone_numbers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_person_phone_numbers (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_person_id uuid NOT NULL,
    label character varying(40),
    status character varying DEFAULT 'active'::character varying NOT NULL,
    preferred boolean DEFAULT false NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    number character varying NOT NULL,
    normalized_number character varying NOT NULL,
    extension character varying,
    country_code character varying NOT NULL,
    phone_digits_reversed text GENERATED ALWAYS AS (reverse(SUBSTRING(normalized_number FROM 2))) STORED,
    CONSTRAINT client_person_phone_numbers_country_shape CHECK (((country_code)::text ~ '^[A-Z]{2}$'::text)),
    CONSTRAINT client_person_phone_numbers_e164_shape CHECK (((normalized_number)::text ~ '^\+[1-9][0-9]{0,14}$'::text)),
    CONSTRAINT client_person_phone_numbers_extension CHECK (((extension IS NULL) OR ((extension)::text ~ '^[0-9]{1,10}$'::text))),
    CONSTRAINT client_person_phone_numbers_label_length CHECK (((label IS NULL) OR (char_length((label)::text) <= 40))),
    CONSTRAINT client_person_phone_numbers_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT client_person_phone_numbers_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
);


--
-- Name: client_person_postal_addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_person_postal_addresses (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_person_id uuid NOT NULL,
    label character varying(40),
    status character varying DEFAULT 'active'::character varying NOT NULL,
    preferred boolean DEFAULT false NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    line_1 character varying NOT NULL,
    line_2 character varying,
    locality character varying,
    region character varying,
    postal_code character varying,
    country_code character varying NOT NULL,
    postal_code_search_key text GENERATED ALWAYS AS (public.dd_search_normalize((postal_code)::text)) STORED,
    locality_search_key text GENERATED ALWAYS AS (public.dd_search_normalize((locality)::text)) STORED,
    CONSTRAINT client_person_postal_addresses_country_shape CHECK (((country_code)::text ~ '^[A-Z]{2}$'::text)),
    CONSTRAINT client_person_postal_addresses_label_length CHECK (((label IS NULL) OR (char_length((label)::text) <= 40))),
    CONSTRAINT client_person_postal_addresses_line_1 CHECK ((btrim((line_1)::text) <> ''::text)),
    CONSTRAINT client_person_postal_addresses_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT client_person_postal_addresses_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
);


--
-- Name: clients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.clients (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_person_id uuid,
    client_reference character varying NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    client_organization_id uuid,
    CONSTRAINT clients_exactly_one_source CHECK ((num_nonnulls(client_person_id, client_organization_id) = 1)),
    CONSTRAINT clients_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT clients_reference_format CHECK (((client_reference)::text ~ '^CL-[0-9]{6}$'::text)),
    CONSTRAINT clients_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
);


--
-- Name: departures; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.departures (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_reference character varying(8),
    name character varying(160) NOT NULL,
    description character varying(2000),
    starts_on date,
    ends_on date,
    time_zone character varying,
    operating_currency character varying(3),
    responsible_office_id uuid,
    responsible_agency_user_id uuid,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    first_activated_at timestamp with time zone,
    departed_at timestamp with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    name_search_key text GENERATED ALWAYS AS (public.dd_search_normalize((name)::text)) STORED,
    CONSTRAINT departures_activation_completeness CHECK ((((status)::text = 'draft'::text) OR ((name IS NOT NULL) AND (btrim((name)::text) <> ''::text) AND (starts_on IS NOT NULL) AND (ends_on IS NOT NULL) AND (time_zone IS NOT NULL) AND (btrim((time_zone)::text) <> ''::text) AND (operating_currency IS NOT NULL) AND (responsible_office_id IS NOT NULL) AND (responsible_agency_user_id IS NOT NULL)))),
    CONSTRAINT departures_date_order CHECK (((starts_on IS NULL) OR (starts_on <= ends_on))),
    CONSTRAINT departures_dates_paired CHECK (((starts_on IS NULL) = (ends_on IS NULL))),
    CONSTRAINT departures_departed_at_pair CHECK ((((status)::text = 'departed'::text) = (departed_at IS NOT NULL))),
    CONSTRAINT departures_description CHECK (((description IS NULL) OR ((btrim((description)::text) <> ''::text) AND (char_length((description)::text) <= 2000)))),
    CONSTRAINT departures_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT departures_name CHECK (((name IS NOT NULL) AND (btrim((name)::text) <> ''::text) AND (char_length((name)::text) <= 160))),
    CONSTRAINT departures_non_draft_has_reference CHECK ((((status)::text = 'draft'::text) OR ((departure_reference IS NOT NULL) AND (first_activated_at IS NOT NULL)))),
    CONSTRAINT departures_operating_currency CHECK (((operating_currency IS NULL) OR ((operating_currency)::text ~ '^[A-Z]{3}$'::text))),
    CONSTRAINT departures_reference_activation_pair CHECK (((departure_reference IS NULL) = (first_activated_at IS NULL))),
    CONSTRAINT departures_reference_format CHECK (((departure_reference IS NULL) OR ((departure_reference)::text ~ '^D-[0-9]{6}$'::text))),
    CONSTRAINT departures_status CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'active'::character varying, 'departed'::character varying])::text[])))
);


--
-- Name: offices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offices (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    name character varying NOT NULL,
    code character varying NOT NULL,
    default_timezone character varying NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT offices_code_format CHECK (((code)::text ~ '^[A-Z][A-Z0-9]{1,9}$'::text)),
    CONSTRAINT offices_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT offices_name_not_blank CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT offices_status_valid CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('inactive'::character varying)::text])))
);


--
-- Name: reference_sequences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reference_sequences (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    namespace character varying NOT NULL,
    next_value bigint DEFAULT 1 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT reference_sequences_namespace CHECK (((namespace)::text = ANY ((ARRAY['client'::character varying, 'supplier'::character varying, 'departure'::character varying])::text[]))),
    CONSTRAINT reference_sequences_next_value CHECK (((next_value >= 1) AND (next_value <= 1000000)))
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: service_occurrence_definitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.service_occurrence_definitions (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT service_occurrence_definiti_supplier_arrangement_versi_not_null NOT NULL,
    arrangement_item_id uuid NOT NULL,
    service_occurrence_id uuid NOT NULL,
    name character varying(160) NOT NULL,
    description character varying(2000),
    starts_on date NOT NULL,
    ends_on date NOT NULL,
    starts_at_local time without time zone,
    ends_at_local time without time zone,
    time_zone character varying NOT NULL,
    service_provider_id uuid,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    copied_from_id uuid,
    CONSTRAINT service_occurrence_definitions_date_order CHECK ((starts_on <= ends_on)),
    CONSTRAINT service_occurrence_definitions_description CHECK (((description IS NULL) OR ((btrim((description)::text) <> ''::text) AND (char_length((description)::text) <= 2000)))),
    CONSTRAINT service_occurrence_definitions_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT service_occurrence_definitions_name CHECK (((btrim((name)::text) <> ''::text) AND (char_length((name)::text) <= 160))),
    CONSTRAINT service_occurrence_definitions_time_zone CHECK (((time_zone IS NOT NULL) AND (btrim((time_zone)::text) <> ''::text))),
    CONSTRAINT service_occurrence_definitions_times_paired CHECK (((starts_at_local IS NULL) = (ends_at_local IS NULL)))
);


--
-- Name: service_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.service_occurrences (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    arrangement_item_id uuid NOT NULL,
    status character varying DEFAULT 'planned'::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT service_occurrences_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT service_occurrences_status CHECK (((status)::text = ANY ((ARRAY['planned'::character varying, 'cancelled'::character varying])::text[])))
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_user_id uuid NOT NULL,
    office_id uuid,
    credential_version integer NOT NULL,
    ip_address character varying,
    user_agent character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: supplier_arrangement_activation_capacity_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_arrangement_activation_capacity_entries (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid CONSTRAINT supplier_arrangement_activation_capacity_ent_agency_id_not_null NOT NULL,
    departure_id uuid CONSTRAINT supplier_arrangement_activation_capacity__departure_id_not_null NOT NULL,
    supplier_arrangement_id uuid CONSTRAINT supplier_arrangement_activati_supplier_arrangement_id_not_null2 NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_arrangement_activ_supplier_arrangement_versi_not_null2 NOT NULL,
    supplier_arrangement_activation_id uuid CONSTRAINT supplier_arrangement_activ_supplier_arrangement_activ_not_null1 NOT NULL,
    capacity_pool_definition_id uuid CONSTRAINT supplier_arrangement_activa_capacity_pool_definition_i_not_null NOT NULL,
    capacity_pool_id uuid CONSTRAINT supplier_arrangement_activation_capac_capacity_pool_id_not_null NOT NULL,
    establishment_event_id uuid,
    entry_kind character varying CONSTRAINT supplier_arrangement_activation_capacity_en_entry_kind_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT supplier_arrangement_activation_capacity_en_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT supplier_arrangement_activation_capacity_en_updated_at_not_null NOT NULL,
    CONSTRAINT activation_capacity_entries_event_shape CHECK ((((entry_kind)::text = 'established'::text) = (establishment_event_id IS NOT NULL))),
    CONSTRAINT activation_capacity_entries_kind CHECK (((entry_kind)::text = ANY ((ARRAY['established'::character varying, 'carried'::character varying, 'nonnumeric'::character varying])::text[])))
);


--
-- Name: supplier_arrangement_activation_cost_selections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_arrangement_activation_cost_selections (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid CONSTRAINT supplier_arrangement_activation_cost_selecti_agency_id_not_null NOT NULL,
    departure_id uuid CONSTRAINT supplier_arrangement_activation_cost_sele_departure_id_not_null NOT NULL,
    supplier_arrangement_id uuid CONSTRAINT supplier_arrangement_activati_supplier_arrangement_id_not_null1 NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_arrangement_activ_supplier_arrangement_versi_not_null1 NOT NULL,
    supplier_arrangement_activation_id uuid CONSTRAINT supplier_arrangement_activa_supplier_arrangement_activ_not_null NOT NULL,
    supplier_cost_source_id uuid CONSTRAINT supplier_arrangement_activatio_supplier_cost_source_id_not_null NOT NULL,
    supplier_cost_definition_id uuid CONSTRAINT supplier_arrangement_activa_supplier_cost_definition_i_not_null NOT NULL,
    selection_kind character varying CONSTRAINT supplier_arrangement_activation_cost_se_selection_kind_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT supplier_arrangement_activation_cost_select_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT supplier_arrangement_activation_cost_select_updated_at_not_null NOT NULL,
    CONSTRAINT activation_cost_selections_kind CHECK (((selection_kind)::text = ANY ((ARRAY['contracted'::character varying, 'provisional_estimate'::character varying])::text[])))
);


--
-- Name: supplier_arrangement_activations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_arrangement_activations (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid CONSTRAINT supplier_arrangement_activatio_supplier_arrangement_id_not_null NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_arrangement_activa_supplier_arrangement_versi_not_null NOT NULL,
    activation_kind character varying NOT NULL,
    predecessor_version_id uuid,
    predecessor_activation_id uuid,
    supplier_confirmation_id uuid CONSTRAINT supplier_arrangement_activati_supplier_confirmation_id_not_null NOT NULL,
    actor_id uuid NOT NULL,
    activated_at timestamp with time zone NOT NULL,
    coverage_attestation_version character varying(40) CONSTRAINT supplier_arrangement_activa_coverage_attestation_versi_not_null NOT NULL,
    coverage_fingerprint character varying(128) NOT NULL,
    provisional_costs_acknowledged boolean DEFAULT false CONSTRAINT supplier_arrangement_activa_provisional_costs_acknowle_not_null NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    cost_source_coverage_acknowledged boolean DEFAULT false CONSTRAINT supplier_arrangement_activa_cost_source_coverage_ackno_not_null NOT NULL,
    commitment_trigger_coverage_acknowledged boolean DEFAULT false CONSTRAINT supplier_arrangement_activa_commitment_trigger_coverag_not_null NOT NULL,
    elapsed_deadlines_acknowledged boolean DEFAULT false CONSTRAINT supplier_arrangement_activa_elapsed_deadlines_acknowle_not_null NOT NULL,
    CONSTRAINT arrangement_activations_coverage_attestation_version CHECK (((btrim((coverage_attestation_version)::text) <> ''::text) AND (char_length((coverage_attestation_version)::text) <= 40))),
    CONSTRAINT arrangement_activations_coverage_fingerprint CHECK (((btrim((coverage_fingerprint)::text) <> ''::text) AND (char_length((coverage_fingerprint)::text) <= 128))),
    CONSTRAINT arrangement_activations_kind CHECK (((activation_kind)::text = ANY ((ARRAY['first'::character varying, 'successor'::character varying])::text[]))),
    CONSTRAINT arrangement_activations_predecessor_shape CHECK (((((activation_kind)::text = 'first'::text) AND (predecessor_version_id IS NULL) AND (predecessor_activation_id IS NULL)) OR (((activation_kind)::text = 'successor'::text) AND (predecessor_version_id IS NOT NULL) AND (predecessor_activation_id IS NOT NULL))))
);


--
-- Name: supplier_arrangement_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_arrangement_versions (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    version_number integer NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    abandoned_at timestamp with time zone,
    abandoned_reason character varying(500),
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    activated_at timestamp with time zone,
    superseded_at timestamp with time zone,
    copied_from_id uuid,
    CONSTRAINT supplier_arrangement_versions_abandoned_at_pair CHECK ((((status)::text = 'abandoned'::text) = (abandoned_at IS NOT NULL))),
    CONSTRAINT supplier_arrangement_versions_lifecycle_timestamps CHECK (((((status)::text = 'draft'::text) AND (activated_at IS NULL) AND (superseded_at IS NULL)) OR (((status)::text = 'activated'::text) AND (activated_at IS NOT NULL) AND (superseded_at IS NULL)) OR (((status)::text = 'superseded'::text) AND (activated_at IS NOT NULL) AND (superseded_at IS NOT NULL) AND (superseded_at >= activated_at)) OR (((status)::text = 'abandoned'::text) AND (activated_at IS NULL) AND (superseded_at IS NULL)))),
    CONSTRAINT supplier_arrangement_versions_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_arrangement_versions_number_positive CHECK ((version_number > 0)),
    CONSTRAINT supplier_arrangement_versions_reason CHECK (((abandoned_reason IS NULL) OR ((btrim((abandoned_reason)::text) <> ''::text) AND (char_length((abandoned_reason)::text) <= 500)))),
    CONSTRAINT supplier_arrangement_versions_reason_pair CHECK ((((status)::text = 'abandoned'::text) = (abandoned_reason IS NOT NULL))),
    CONSTRAINT supplier_arrangement_versions_status CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'activated'::character varying, 'superseded'::character varying, 'abandoned'::character varying])::text[])))
);


--
-- Name: supplier_arrangements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_arrangements (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    contracting_supplier_id uuid NOT NULL,
    supplier_contact_id uuid,
    name character varying(160) NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    abandoned_at timestamp with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    governing_version_id uuid,
    CONSTRAINT supplier_arrangements_abandoned_at_pair CHECK ((((status)::text = 'abandoned'::text) = (abandoned_at IS NOT NULL))),
    CONSTRAINT supplier_arrangements_active_governing_version CHECK ((((status)::text <> 'active'::text) OR (governing_version_id IS NOT NULL))),
    CONSTRAINT supplier_arrangements_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_arrangements_name CHECK (((btrim((name)::text) <> ''::text) AND (char_length((name)::text) <= 160))),
    CONSTRAINT supplier_arrangements_status CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'active'::character varying, 'ended'::character varying, 'abandoned'::character varying])::text[])))
);


--
-- Name: supplier_category_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_category_assignments (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_id uuid NOT NULL,
    category_code character varying NOT NULL,
    other_label character varying(80),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT supplier_category_assignments_code CHECK (((category_code)::text = ANY ((ARRAY['cruise_line'::character varying, 'lodging'::character varying, 'air'::character varying, 'ground_transportation'::character varying, 'tour_operator_dmc'::character varying, 'dining'::character varying, 'activity_attraction'::character varying, 'insurance'::character varying, 'other'::character varying])::text[]))),
    CONSTRAINT supplier_category_assignments_other_label CHECK (((((category_code)::text = 'other'::text) AND (other_label IS NOT NULL) AND ((other_label)::text = btrim((other_label)::text)) AND (btrim((other_label)::text) <> ''::text) AND (char_length((other_label)::text) <= 80)) OR (((category_code)::text <> 'other'::text) AND (other_label IS NULL))))
);


--
-- Name: supplier_commitment_dispositions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_commitment_dispositions (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid CONSTRAINT supplier_commitment_dispositio_supplier_arrangement_id_not_null NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_commitment_disposi_supplier_arrangement_versi_not_null NOT NULL,
    supplier_commitment_id uuid CONSTRAINT supplier_commitment_disposition_supplier_commitment_id_not_null NOT NULL,
    outcome character varying NOT NULL,
    supplier_commitment_evidence_coverage_id uuid,
    replacement_supplier_commitment_id uuid,
    reason character varying(2000),
    accepted_risk_acknowledged boolean DEFAULT false CONSTRAINT supplier_commitment_disposi_accepted_risk_acknowledged_not_null NOT NULL,
    actor_id uuid NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    recorded_at timestamp with time zone NOT NULL,
    agency_command_idempotency_key_id uuid,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT commitment_dispositions_outcome CHECK (((outcome)::text = ANY ((ARRAY['satisfied'::character varying, 'released'::character varying, 'waived'::character varying, 'cancelled'::character varying, 'superseded'::character varying])::text[]))),
    CONSTRAINT commitment_dispositions_outcome_proof CHECK (((((outcome)::text = ANY ((ARRAY['satisfied'::character varying, 'released'::character varying])::text[])) AND (supplier_commitment_evidence_coverage_id IS NOT NULL) AND (reason IS NULL) AND (accepted_risk_acknowledged = false) AND (replacement_supplier_commitment_id IS NULL)) OR (((outcome)::text = 'waived'::text) AND (supplier_commitment_evidence_coverage_id IS NULL) AND (reason IS NOT NULL) AND (btrim((reason)::text) <> ''::text) AND (accepted_risk_acknowledged = true) AND (replacement_supplier_commitment_id IS NULL)) OR (((outcome)::text = 'cancelled'::text) AND (supplier_commitment_evidence_coverage_id IS NULL) AND (accepted_risk_acknowledged = false) AND (replacement_supplier_commitment_id IS NULL)) OR (((outcome)::text = 'superseded'::text) AND (supplier_commitment_evidence_coverage_id IS NULL) AND (accepted_risk_acknowledged = false) AND (replacement_supplier_commitment_id IS NOT NULL) AND (replacement_supplier_commitment_id <> supplier_commitment_id)))),
    CONSTRAINT commitment_dispositions_reason_length CHECK (((reason IS NULL) OR (char_length((reason)::text) <= 2000)))
);


--
-- Name: supplier_commitment_evidence_coverage_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_commitment_evidence_coverage_members (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid CONSTRAINT supplier_commitment_evidence_coverage_member_agency_id_not_null NOT NULL,
    departure_id uuid CONSTRAINT supplier_commitment_evidence_coverage_mem_departure_id_not_null NOT NULL,
    supplier_arrangement_id uuid CONSTRAINT supplier_commitment_evidence__supplier_arrangement_id_not_null1 NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_commitment_eviden_supplier_arrangement_versi_not_null1 NOT NULL,
    supplier_commitment_evidence_coverage_id uuid CONSTRAINT supplier_commitment_evidenc_supplier_commitment_eviden_not_null NOT NULL,
    supplier_commitment_id uuid CONSTRAINT supplier_commitment_evidence_co_supplier_commitment_id_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT supplier_commitment_evidence_coverage_membe_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT supplier_commitment_evidence_coverage_membe_updated_at_not_null NOT NULL
);


--
-- Name: supplier_commitment_evidence_coverage_revocations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_commitment_evidence_coverage_revocations (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid CONSTRAINT supplier_commitment_evidence_coverage_revoca_agency_id_not_null NOT NULL,
    departure_id uuid CONSTRAINT supplier_commitment_evidence_coverage_rev_departure_id_not_null NOT NULL,
    supplier_arrangement_id uuid CONSTRAINT supplier_commitment_evidence__supplier_arrangement_id_not_null2 NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_commitment_eviden_supplier_arrangement_versi_not_null2 NOT NULL,
    supplier_commitment_evidence_coverage_id uuid CONSTRAINT supplier_commitment_eviden_supplier_commitment_eviden_not_null1 NOT NULL,
    reason character varying(2000) CONSTRAINT supplier_commitment_evidence_coverage_revocatio_reason_not_null NOT NULL,
    actor_id uuid CONSTRAINT supplier_commitment_evidence_coverage_revocat_actor_id_not_null NOT NULL,
    occurred_at timestamp with time zone CONSTRAINT supplier_commitment_evidence_coverage_revo_occurred_at_not_null NOT NULL,
    recorded_at timestamp with time zone CONSTRAINT supplier_commitment_evidence_coverage_revo_recorded_at_not_null NOT NULL,
    agency_command_idempotency_key_id uuid,
    created_at timestamp(6) with time zone CONSTRAINT supplier_commitment_evidence_coverage_revoc_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT supplier_commitment_evidence_coverage_revoc_updated_at_not_null NOT NULL,
    CONSTRAINT commitment_evidence_revocations_reason CHECK (((btrim((reason)::text) <> ''::text) AND (char_length((reason)::text) <= 2000)))
);


--
-- Name: supplier_commitment_evidence_coverages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_commitment_evidence_coverages (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid CONSTRAINT supplier_commitment_evidence_c_supplier_arrangement_id_not_null NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_commitment_evidenc_supplier_arrangement_versi_not_null NOT NULL,
    supplier_confirmation_id uuid CONSTRAINT supplier_commitment_evidence__supplier_confirmation_id_not_null NOT NULL,
    purpose character varying NOT NULL,
    actor_id uuid NOT NULL,
    recorded_at timestamp with time zone NOT NULL,
    agency_command_idempotency_key_id uuid,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT commitment_evidence_coverages_purpose CHECK (((purpose)::text = ANY ((ARRAY['satisfied'::character varying, 'released'::character varying])::text[])))
);


--
-- Name: supplier_commitment_evidence_member_disqualifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_commitment_evidence_member_disqualifications (
    id uuid DEFAULT uuidv7() CONSTRAINT supplier_commitment_evidence_member_disqualificatio_id_not_null NOT NULL,
    agency_id uuid CONSTRAINT supplier_commitment_evidence_member_disquali_agency_id_not_null NOT NULL,
    departure_id uuid CONSTRAINT supplier_commitment_evidence_member_disqu_departure_id_not_null NOT NULL,
    supplier_arrangement_id uuid CONSTRAINT supplier_commitment_evidence_m_supplier_arrangement_id_not_null NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_commitment_eviden_supplier_arrangement_versi_not_null3 NOT NULL,
    supplier_commitment_evidence_coverage_id uuid CONSTRAINT supplier_commitment_eviden_supplier_commitment_eviden_not_null2 NOT NULL,
    supplier_commitment_id uuid CONSTRAINT supplier_commitment_evidence_me_supplier_commitment_id_not_null NOT NULL,
    supplier_commitment_disposition_id uuid CONSTRAINT supplier_commitment_evidenc_supplier_commitment_dispos_not_null NOT NULL,
    supplier_commitment_reopening_id uuid CONSTRAINT supplier_commitment_evidenc_supplier_commitment_reopen_not_null NOT NULL,
    reason character varying(2000) CONSTRAINT supplier_commitment_evidence_member_disqualific_reason_not_null NOT NULL,
    actor_id uuid CONSTRAINT supplier_commitment_evidence_member_disqualif_actor_id_not_null NOT NULL,
    occurred_at timestamp with time zone CONSTRAINT supplier_commitment_evidence_member_disqua_occurred_at_not_null NOT NULL,
    recorded_at timestamp with time zone CONSTRAINT supplier_commitment_evidence_member_disqua_recorded_at_not_null NOT NULL,
    agency_command_idempotency_key_id uuid,
    created_at timestamp(6) with time zone CONSTRAINT supplier_commitment_evidence_member_disqual_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT supplier_commitment_evidence_member_disqual_updated_at_not_null NOT NULL,
    CONSTRAINT commitment_evidence_disqualifications_reason CHECK (((btrim((reason)::text) <> ''::text) AND (char_length((reason)::text) <= 2000)))
);


--
-- Name: supplier_commitment_reopenings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_commitment_reopenings (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_commitment_reopeni_supplier_arrangement_versi_not_null NOT NULL,
    supplier_commitment_id uuid NOT NULL,
    supplier_commitment_disposition_id uuid CONSTRAINT supplier_commitment_reopeni_supplier_commitment_dispos_not_null NOT NULL,
    reason character varying(2000) NOT NULL,
    actor_id uuid NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    recorded_at timestamp with time zone NOT NULL,
    agency_command_idempotency_key_id uuid,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT commitment_reopenings_reason CHECK (((btrim((reason)::text) <> ''::text) AND (char_length((reason)::text) <= 2000)))
);


--
-- Name: supplier_commitment_trigger_definitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_commitment_trigger_definitions (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid CONSTRAINT supplier_commitment_trigger_de_supplier_arrangement_id_not_null NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_commitment_trigger_supplier_arrangement_versi_not_null NOT NULL,
    arrangement_item_id uuid,
    service_occurrence_id uuid,
    supplier_resource_id uuid,
    capacity_pool_id uuid,
    supplier_cost_source_id uuid,
    committed_supplier_id uuid CONSTRAINT supplier_commitment_trigger_defi_committed_supplier_id_not_null NOT NULL,
    trigger_kind character varying NOT NULL,
    authority_shape character varying CONSTRAINT supplier_commitment_trigger_definition_authority_shape_not_null NOT NULL,
    description character varying(500) NOT NULL,
    fixed_quantity bigint,
    quantity_basis character varying,
    fixed_amount_minor_units bigint,
    currency character varying(3),
    supplier_cost_definition_id uuid,
    supplier_cost_component_id uuid,
    copied_from_id uuid,
    "position" integer NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT commitment_triggers_authority_fields CHECK (((((authority_shape)::text = 'fixed_quantity'::text) AND (fixed_quantity > 0) AND (quantity_basis IS NOT NULL) AND (fixed_amount_minor_units IS NULL) AND (currency IS NULL) AND (supplier_cost_definition_id IS NULL) AND (supplier_cost_component_id IS NULL)) OR (((authority_shape)::text = 'confirmed_quantity'::text) AND (fixed_quantity IS NULL) AND (quantity_basis IS NOT NULL) AND (fixed_amount_minor_units IS NULL) AND (currency IS NULL) AND (supplier_cost_definition_id IS NULL) AND (supplier_cost_component_id IS NULL)) OR (((authority_shape)::text = 'fixed_contracted_amount'::text) AND (fixed_quantity IS NULL) AND (quantity_basis IS NULL) AND (fixed_amount_minor_units IS NULL) AND (currency IS NOT NULL) AND (supplier_cost_definition_id IS NOT NULL) AND (supplier_cost_component_id IS NOT NULL)) OR (((authority_shape)::text = 'confirmed_amount'::text) AND (fixed_quantity IS NULL) AND (quantity_basis IS NULL) AND (fixed_amount_minor_units IS NULL) AND (currency IS NOT NULL) AND (supplier_cost_definition_id IS NULL) AND (supplier_cost_component_id IS NULL)) OR (((authority_shape)::text = 'contracted_unit_rate_times_confirmed_quantity'::text) AND (fixed_quantity IS NULL) AND (quantity_basis IS NOT NULL) AND (fixed_amount_minor_units IS NULL) AND (currency IS NOT NULL) AND (supplier_cost_definition_id IS NOT NULL) AND (supplier_cost_component_id IS NOT NULL)))),
    CONSTRAINT commitment_triggers_authority_shape CHECK (((authority_shape)::text = ANY ((ARRAY['fixed_quantity'::character varying, 'confirmed_quantity'::character varying, 'fixed_contracted_amount'::character varying, 'confirmed_amount'::character varying, 'contracted_unit_rate_times_confirmed_quantity'::character varying])::text[]))),
    CONSTRAINT commitment_triggers_currency CHECK (((currency IS NULL) OR ((currency)::text ~ '^[A-Z]{3}$'::text))),
    CONSTRAINT commitment_triggers_description CHECK (((btrim((description)::text) <> ''::text) AND (char_length((description)::text) <= 500))),
    CONSTRAINT commitment_triggers_kind CHECK (((trigger_kind)::text = ANY ((ARRAY['arrangement_confirmation'::character varying, 'reservation_confirmation'::character varying])::text[]))),
    CONSTRAINT commitment_triggers_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT commitment_triggers_position_positive CHECK (("position" > 0)),
    CONSTRAINT commitment_triggers_quantity_basis CHECK (((quantity_basis IS NULL) OR ((quantity_basis)::text = ANY ((ARRAY['resource_units'::character varying, 'traveler_positions'::character varying])::text[])))),
    CONSTRAINT commitment_triggers_scope_shape CHECK ((((service_occurrence_id IS NULL) OR (arrangement_item_id IS NOT NULL)) AND ((supplier_resource_id IS NULL) OR (arrangement_item_id IS NOT NULL)) AND ((capacity_pool_id IS NULL) OR ((arrangement_item_id IS NOT NULL) AND (service_occurrence_id IS NOT NULL) AND (supplier_resource_id IS NOT NULL)))))
);


--
-- Name: supplier_commitments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_commitments (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    supplier_arrangement_version_id uuid NOT NULL,
    supplier_arrangement_activation_id uuid,
    supplier_commitment_trigger_definition_id uuid,
    supplier_confirmation_id uuid,
    committed_supplier_id uuid NOT NULL,
    arrangement_item_id uuid,
    service_occurrence_id uuid,
    supplier_resource_id uuid,
    capacity_pool_id uuid,
    supplier_cost_source_id uuid,
    commitment_type character varying NOT NULL,
    description character varying(500) NOT NULL,
    quantity bigint,
    quantity_basis character varying,
    amount_minor_units bigint,
    currency character varying(3),
    calculation_snapshot character varying(2000) NOT NULL,
    actor_id uuid NOT NULL,
    opened_at timestamp with time zone NOT NULL,
    agency_command_idempotency_key_id uuid,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    supplier_reservation_id uuid,
    supplier_reservation_revision_id uuid,
    supplier_reservation_scope_id uuid,
    supplier_reservation_event_id uuid,
    opening_kind character varying DEFAULT 'confirmation_trigger'::character varying NOT NULL,
    supplier_deadline_occurrence_id uuid,
    supplier_deadline_commitment_definition_line_id uuid,
    CONSTRAINT supplier_commitments_authority_shape CHECK (((((commitment_type)::text = 'quantity'::text) AND (quantity IS NOT NULL) AND (amount_minor_units IS NULL)) OR (((commitment_type)::text = 'monetary'::text) AND (quantity IS NULL) AND (amount_minor_units IS NOT NULL)) OR (((commitment_type)::text = 'quantity_and_monetary'::text) AND (quantity IS NOT NULL) AND (amount_minor_units IS NOT NULL)))),
    CONSTRAINT supplier_commitments_calculation_snapshot CHECK (((btrim((calculation_snapshot)::text) <> ''::text) AND (char_length((calculation_snapshot)::text) <= 2000))),
    CONSTRAINT supplier_commitments_description CHECK (((btrim((description)::text) <> ''::text) AND (char_length((description)::text) <= 500))),
    CONSTRAINT supplier_commitments_money_shape CHECK ((((amount_minor_units IS NULL) = (currency IS NULL)) AND ((amount_minor_units IS NULL) OR (amount_minor_units >= 0)))),
    CONSTRAINT supplier_commitments_opening_kind CHECK (((opening_kind)::text = ANY ((ARRAY['confirmation_trigger'::character varying, 'deadline_requirement'::character varying])::text[]))),
    CONSTRAINT supplier_commitments_opening_shape CHECK (((((opening_kind)::text = 'confirmation_trigger'::text) AND (supplier_commitment_trigger_definition_id IS NOT NULL) AND (supplier_confirmation_id IS NOT NULL) AND (supplier_deadline_occurrence_id IS NULL) AND (supplier_deadline_commitment_definition_line_id IS NULL)) OR (((opening_kind)::text = 'deadline_requirement'::text) AND (supplier_commitment_trigger_definition_id IS NULL) AND (supplier_confirmation_id IS NULL) AND (supplier_deadline_occurrence_id IS NOT NULL) AND (supplier_deadline_commitment_definition_line_id IS NOT NULL)))),
    CONSTRAINT supplier_commitments_quantity_shape CHECK ((((quantity IS NULL) = (quantity_basis IS NULL)) AND ((quantity IS NULL) OR (quantity > 0)))),
    CONSTRAINT supplier_commitments_reservation_shape CHECK ((((supplier_reservation_id IS NULL) AND (supplier_reservation_revision_id IS NULL) AND (supplier_reservation_scope_id IS NULL) AND (supplier_reservation_event_id IS NULL)) OR ((supplier_reservation_id IS NOT NULL) AND (supplier_reservation_revision_id IS NOT NULL) AND (supplier_reservation_scope_id IS NOT NULL) AND (supplier_reservation_event_id IS NOT NULL)))),
    CONSTRAINT supplier_commitments_type CHECK (((commitment_type)::text = ANY ((ARRAY['quantity'::character varying, 'monetary'::character varying, 'quantity_and_monetary'::character varying])::text[])))
);


--
-- Name: supplier_confirmation_activation_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_confirmation_activation_links (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid CONSTRAINT supplier_confirmation_activati_supplier_arrangement_id_not_null NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_confirmation_activ_supplier_arrangement_versi_not_null NOT NULL,
    supplier_confirmation_id uuid CONSTRAINT supplier_confirmation_activat_supplier_confirmation_id_not_null NOT NULL,
    supplier_arrangement_activation_id uuid CONSTRAINT supplier_confirmation_activ_supplier_arrangement_activ_not_null NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: supplier_confirmation_capacity_event_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_confirmation_capacity_event_links (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid CONSTRAINT supplier_confirmation_capacity_event_link_departure_id_not_null NOT NULL,
    supplier_arrangement_id uuid CONSTRAINT supplier_confirmation_capacity_supplier_arrangement_id_not_null NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_confirmation_capac_supplier_arrangement_versi_not_null NOT NULL,
    supplier_confirmation_id uuid CONSTRAINT supplier_confirmation_capacit_supplier_confirmation_id_not_null NOT NULL,
    capacity_event_id uuid CONSTRAINT supplier_confirmation_capacity_event_capacity_event_id_not_null NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: supplier_confirmation_commitment_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_confirmation_commitment_links (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid CONSTRAINT supplier_confirmation_commitme_supplier_arrangement_id_not_null NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_confirmation_commi_supplier_arrangement_versi_not_null NOT NULL,
    supplier_confirmation_id uuid CONSTRAINT supplier_confirmation_commitm_supplier_confirmation_id_not_null NOT NULL,
    supplier_commitment_id uuid CONSTRAINT supplier_confirmation_commitmen_supplier_commitment_id_not_null NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: supplier_confirmation_identifier_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_confirmation_identifier_links (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid CONSTRAINT supplier_confirmation_identifi_supplier_arrangement_id_not_null NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_confirmation_ident_supplier_arrangement_versi_not_null NOT NULL,
    supplier_confirmation_id uuid CONSTRAINT supplier_confirmation_identif_supplier_confirmation_id_not_null NOT NULL,
    supplier_issued_identifier_id uuid CONSTRAINT supplier_confirmation_ident_supplier_issued_identifier_not_null NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: supplier_confirmation_reservation_response_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_confirmation_reservation_response_links (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid CONSTRAINT supplier_confirmation_reservation_response_l_agency_id_not_null NOT NULL,
    departure_id uuid CONSTRAINT supplier_confirmation_reservation_respons_departure_id_not_null NOT NULL,
    supplier_arrangement_id uuid CONSTRAINT supplier_confirmation_reservat_supplier_arrangement_id_not_null NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_confirmation_reser_supplier_arrangement_versi_not_null NOT NULL,
    supplier_confirmation_id uuid CONSTRAINT supplier_confirmation_reserva_supplier_confirmation_id_not_null NOT NULL,
    supplier_reservation_id uuid CONSTRAINT supplier_confirmation_reservat_supplier_reservation_id_not_null NOT NULL,
    supplier_reservation_revision_id uuid CONSTRAINT supplier_confirmation_reser_supplier_reservation_revis_not_null NOT NULL,
    supplier_reservation_event_id uuid CONSTRAINT supplier_confirmation_reser_supplier_reservation_event_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT supplier_confirmation_reservation_response__created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT supplier_confirmation_reservation_response__updated_at_not_null NOT NULL
);


--
-- Name: supplier_confirmation_reservation_scope_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_confirmation_reservation_scope_links (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid CONSTRAINT supplier_confirmation_reservation_scope_link_agency_id_not_null NOT NULL,
    departure_id uuid CONSTRAINT supplier_confirmation_reservation_scope_l_departure_id_not_null NOT NULL,
    supplier_arrangement_id uuid CONSTRAINT supplier_confirmation_reserva_supplier_arrangement_id_not_null1 NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_confirmation_rese_supplier_arrangement_versi_not_null1 NOT NULL,
    supplier_confirmation_id uuid CONSTRAINT supplier_confirmation_reserv_supplier_confirmation_id_not_null1 NOT NULL,
    supplier_reservation_id uuid CONSTRAINT supplier_confirmation_reserva_supplier_reservation_id_not_null1 NOT NULL,
    supplier_reservation_revision_id uuid CONSTRAINT supplier_confirmation_rese_supplier_reservation_revis_not_null1 NOT NULL,
    supplier_reservation_scope_id uuid CONSTRAINT supplier_confirmation_reser_supplier_reservation_scope_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT supplier_confirmation_reservation_scope_lin_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT supplier_confirmation_reservation_scope_lin_updated_at_not_null NOT NULL
);


--
-- Name: supplier_confirmations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_confirmations (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    supplier_arrangement_version_id uuid NOT NULL,
    confirming_supplier_id uuid NOT NULL,
    evidence_kind character varying NOT NULL,
    other_evidence_label character varying(80),
    evidence_on date NOT NULL,
    channel character varying NOT NULL,
    reference_note character varying(500) NOT NULL,
    confirmed_without_identifier_reason character varying(500),
    actor_id uuid NOT NULL,
    recorded_at timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT supplier_confirmations_channel CHECK (((btrim((channel)::text) <> ''::text) AND (char_length((channel)::text) <= 80))),
    CONSTRAINT supplier_confirmations_confirmed_without_identifier_reason CHECK (((confirmed_without_identifier_reason IS NULL) OR ((btrim((confirmed_without_identifier_reason)::text) <> ''::text) AND (char_length((confirmed_without_identifier_reason)::text) <= 500)))),
    CONSTRAINT supplier_confirmations_evidence_kind CHECK (((evidence_kind)::text = ANY ((ARRAY['contract'::character varying, 'supplier_confirmation'::character varying, 'supplier_message'::character varying, 'supplier_portal'::character varying, 'verbal_confirmation'::character varying, 'supplier_release'::character varying, 'contract_release'::character varying, 'other'::character varying])::text[]))),
    CONSTRAINT supplier_confirmations_other_evidence_label CHECK (((other_evidence_label IS NULL) OR ((btrim((other_evidence_label)::text) <> ''::text) AND (char_length((other_evidence_label)::text) <= 80)))),
    CONSTRAINT supplier_confirmations_other_label_pair CHECK ((((evidence_kind)::text = 'other'::text) = (other_evidence_label IS NOT NULL))),
    CONSTRAINT supplier_confirmations_reference_note CHECK (((btrim((reference_note)::text) <> ''::text) AND (char_length((reference_note)::text) <= 500)))
);


--
-- Name: supplier_contact_email_addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_contact_email_addresses (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_contact_id uuid NOT NULL,
    label character varying(40),
    status character varying DEFAULT 'active'::character varying NOT NULL,
    preferred boolean DEFAULT false NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    address character varying NOT NULL,
    normalized_address text GENERATED ALWAYS AS (lower(btrim((address)::text))) STORED,
    CONSTRAINT supplier_contact_email_addresses_label_length CHECK (((label IS NULL) OR (char_length((label)::text) <= 40))),
    CONSTRAINT supplier_contact_email_addresses_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_contact_email_addresses_normalized CHECK (((normalized_address = lower(btrim((address)::text))) AND (normalized_address <> ''::text))),
    CONSTRAINT supplier_contact_email_addresses_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
);


--
-- Name: supplier_contact_phone_numbers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_contact_phone_numbers (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_contact_id uuid NOT NULL,
    label character varying(40),
    status character varying DEFAULT 'active'::character varying NOT NULL,
    preferred boolean DEFAULT false NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    number character varying NOT NULL,
    normalized_number character varying NOT NULL,
    extension character varying,
    country_code character varying NOT NULL,
    phone_digits_reversed text GENERATED ALWAYS AS (reverse(SUBSTRING(normalized_number FROM 2))) STORED,
    CONSTRAINT supplier_contact_phone_numbers_country_shape CHECK (((country_code)::text ~ '^[A-Z]{2}$'::text)),
    CONSTRAINT supplier_contact_phone_numbers_e164_shape CHECK (((normalized_number)::text ~ '^\+[1-9][0-9]{0,14}$'::text)),
    CONSTRAINT supplier_contact_phone_numbers_extension CHECK (((extension IS NULL) OR ((extension)::text ~ '^[0-9]{1,10}$'::text))),
    CONSTRAINT supplier_contact_phone_numbers_label_length CHECK (((label IS NULL) OR (char_length((label)::text) <= 40))),
    CONSTRAINT supplier_contact_phone_numbers_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_contact_phone_numbers_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
);


--
-- Name: supplier_contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_contacts (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_id uuid NOT NULL,
    first_name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL,
    title character varying(120),
    department character varying(120),
    role_label character varying(80),
    preferred boolean DEFAULT false NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    first_name_search_key text GENERATED ALWAYS AS (public.dd_search_normalize((first_name)::text)) STORED,
    last_name_search_key text GENERATED ALWAYS AS (public.dd_search_normalize((last_name)::text)) STORED,
    full_name_search_key text GENERATED ALWAYS AS (public.dd_search_normalize((((first_name)::text || ' '::text) || (last_name)::text))) STORED,
    name_search_vector tsvector GENERATED ALWAYS AS (to_tsvector('simple'::regconfig, public.dd_search_normalize((((first_name)::text || ' '::text) || (last_name)::text)))) STORED,
    CONSTRAINT supplier_contacts_department CHECK (((department IS NULL) OR ((btrim((department)::text) <> ''::text) AND (char_length((department)::text) <= 120)))),
    CONSTRAINT supplier_contacts_first_name CHECK (((btrim((first_name)::text) <> ''::text) AND (char_length((first_name)::text) <= 100))),
    CONSTRAINT supplier_contacts_last_name CHECK (((btrim((last_name)::text) <> ''::text) AND (char_length((last_name)::text) <= 100))),
    CONSTRAINT supplier_contacts_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_contacts_role_label CHECK (((role_label IS NULL) OR ((btrim((role_label)::text) <> ''::text) AND (char_length((role_label)::text) <= 80)))),
    CONSTRAINT supplier_contacts_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[]))),
    CONSTRAINT supplier_contacts_title CHECK (((title IS NULL) OR ((btrim((title)::text) <> ''::text) AND (char_length((title)::text) <= 120))))
);


--
-- Name: supplier_cost_component_bases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_cost_component_bases (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_cost_component_bas_supplier_arrangement_versi_not_null NOT NULL,
    supplier_cost_definition_id uuid CONSTRAINT supplier_cost_component_bas_supplier_cost_definition_i_not_null NOT NULL,
    supplier_cost_component_id uuid CONSTRAINT supplier_cost_component_bas_supplier_cost_component_id_not_null NOT NULL,
    base_component_id uuid NOT NULL,
    direction character varying NOT NULL,
    "position" integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    copied_from_id uuid,
    CONSTRAINT supplier_cost_component_bases_direction CHECK (((direction)::text = ANY ((ARRAY['add'::character varying, 'subtract'::character varying])::text[]))),
    CONSTRAINT supplier_cost_component_bases_position_positive CHECK (("position" > 0))
);


--
-- Name: supplier_cost_components; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_cost_components (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_cost_components_supplier_arrangement_version__not_null NOT NULL,
    supplier_cost_definition_id uuid NOT NULL,
    label character varying(160) NOT NULL,
    economic_role character varying NOT NULL,
    calculation_kind character varying NOT NULL,
    amount_minor_units bigint,
    rate numeric(20,10),
    minimum_minor_units bigint,
    minimum_quantity bigint,
    quantity_basis character varying,
    participant_category_id uuid,
    occupancy_position_from integer,
    occupancy_position_to integer,
    percentage_treatment character varying,
    pass_through boolean DEFAULT false NOT NULL,
    "position" integer NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    copied_from_id uuid,
    CONSTRAINT supplier_cost_components_amount_nonnegative CHECK (((amount_minor_units IS NULL) OR (amount_minor_units >= 0))),
    CONSTRAINT supplier_cost_components_calculation_kind CHECK (((calculation_kind)::text = ANY ((ARRAY['fixed'::character varying, 'unit_rate'::character varying, 'percentage'::character varying, 'minimum_amount_shortfall'::character varying, 'minimum_quantity_shortfall'::character varying])::text[]))),
    CONSTRAINT supplier_cost_components_category_basis CHECK (((participant_category_id IS NULL) OR ((quantity_basis)::text = ANY ((ARRAY['persons'::character varying, 'person_nights'::character varying, 'occupancy_positions'::character varying, 'occupancy_position_nights'::character varying])::text[])))),
    CONSTRAINT supplier_cost_components_economic_role CHECK (((economic_role)::text = ANY ((ARRAY['supplier_charge'::character varying, 'supplier_credit'::character varying, 'expected_commission'::character varying, 'informational_allocation'::character varying])::text[]))),
    CONSTRAINT supplier_cost_components_included_role CHECK ((((percentage_treatment)::text <> 'included'::text) OR ((economic_role)::text = 'informational_allocation'::text))),
    CONSTRAINT supplier_cost_components_kind_shape CHECK (((((calculation_kind)::text = 'fixed'::text) AND (amount_minor_units IS NOT NULL) AND (rate IS NULL) AND (minimum_minor_units IS NULL) AND (minimum_quantity IS NULL) AND (quantity_basis IS NULL) AND (participant_category_id IS NULL) AND (occupancy_position_from IS NULL) AND (occupancy_position_to IS NULL) AND (percentage_treatment IS NULL)) OR (((calculation_kind)::text = 'unit_rate'::text) AND (amount_minor_units IS NOT NULL) AND (quantity_basis IS NOT NULL) AND (rate IS NULL) AND (minimum_minor_units IS NULL) AND (minimum_quantity IS NULL) AND (percentage_treatment IS NULL)) OR (((calculation_kind)::text = 'percentage'::text) AND (rate IS NOT NULL) AND ((percentage_treatment)::text = ANY ((ARRAY['additive'::character varying, 'included'::character varying])::text[])) AND (amount_minor_units IS NULL) AND (minimum_minor_units IS NULL) AND (minimum_quantity IS NULL) AND (quantity_basis IS NULL) AND (participant_category_id IS NULL) AND (occupancy_position_from IS NULL) AND (occupancy_position_to IS NULL)) OR (((calculation_kind)::text = 'minimum_amount_shortfall'::text) AND (minimum_minor_units IS NOT NULL) AND ((economic_role)::text = 'supplier_charge'::text) AND (amount_minor_units IS NULL) AND (rate IS NULL) AND (minimum_quantity IS NULL) AND (quantity_basis IS NULL) AND (participant_category_id IS NULL) AND (occupancy_position_from IS NULL) AND (occupancy_position_to IS NULL) AND (percentage_treatment IS NULL)) OR (((calculation_kind)::text = 'minimum_quantity_shortfall'::text) AND (minimum_quantity IS NOT NULL) AND (quantity_basis IS NOT NULL) AND ((economic_role)::text = 'supplier_charge'::text) AND (amount_minor_units IS NULL) AND (rate IS NULL) AND (minimum_minor_units IS NULL) AND (percentage_treatment IS NULL)))),
    CONSTRAINT supplier_cost_components_label CHECK (((btrim((label)::text) <> ''::text) AND (char_length((label)::text) <= 160))),
    CONSTRAINT supplier_cost_components_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_cost_components_minimum_nonnegative CHECK (((minimum_minor_units IS NULL) OR (minimum_minor_units >= 0))),
    CONSTRAINT supplier_cost_components_minimum_quantity_positive CHECK (((minimum_quantity IS NULL) OR (minimum_quantity > 0))),
    CONSTRAINT supplier_cost_components_occupancy_basis CHECK (((occupancy_position_from IS NULL) OR ((quantity_basis)::text = ANY ((ARRAY['occupancy_positions'::character varying, 'occupancy_position_nights'::character varying])::text[])))),
    CONSTRAINT supplier_cost_components_pass_through_role CHECK (((NOT pass_through) OR ((economic_role)::text <> 'expected_commission'::text))),
    CONSTRAINT supplier_cost_components_position_positive CHECK (("position" > 0)),
    CONSTRAINT supplier_cost_components_position_selector CHECK ((((occupancy_position_from IS NULL) OR (occupancy_position_from > 0)) AND ((occupancy_position_to IS NULL) OR (occupancy_position_to > 0)) AND ((occupancy_position_to IS NULL) OR (occupancy_position_from IS NOT NULL)) AND ((occupancy_position_to IS NULL) OR (occupancy_position_to >= occupancy_position_from)))),
    CONSTRAINT supplier_cost_components_quantity_basis CHECK (((quantity_basis IS NULL) OR ((quantity_basis)::text = ANY ((ARRAY['resource_units'::character varying, 'persons'::character varying, 'nights'::character varying, 'resource_nights'::character varying, 'person_nights'::character varying, 'occupancy_positions'::character varying, 'occupancy_position_nights'::character varying, 'single_occupancy_units'::character varying, 'single_occupancy_nights'::character varying])::text[])))),
    CONSTRAINT supplier_cost_components_rate_nonnegative CHECK (((rate IS NULL) OR (rate >= (0)::numeric)))
);


--
-- Name: supplier_cost_definitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_cost_definitions (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_cost_definitions_supplier_arrangement_version_not_null NOT NULL,
    supplier_cost_source_id uuid NOT NULL,
    stage character varying NOT NULL,
    status character varying DEFAULT 'working'::character varying NOT NULL,
    mode character varying DEFAULT 'calculated'::character varying NOT NULL,
    currency character varying(3) NOT NULL,
    rounding_mode character varying DEFAULT 'half_up'::character varying NOT NULL,
    zero_cost_reason character varying(500),
    forecast_ready_by_id uuid,
    forecast_ready_at timestamp with time zone,
    readiness_provenance character varying(500),
    readiness_fingerprint character varying(128),
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    copied_from_id uuid,
    CONSTRAINT supplier_cost_definitions_currency CHECK (((currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT supplier_cost_definitions_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_cost_definitions_mode CHECK (((mode)::text = ANY ((ARRAY['calculated'::character varying, 'zero_cost'::character varying])::text[]))),
    CONSTRAINT supplier_cost_definitions_readiness_provenance CHECK (((readiness_provenance IS NULL) OR ((btrim((readiness_provenance)::text) <> ''::text) AND (char_length((readiness_provenance)::text) <= 500)))),
    CONSTRAINT supplier_cost_definitions_readiness_shape CHECK (((((status)::text = 'working'::text) AND (forecast_ready_by_id IS NULL) AND (forecast_ready_at IS NULL) AND (readiness_fingerprint IS NULL) AND (readiness_provenance IS NULL)) OR (((status)::text = 'forecast_ready'::text) AND (forecast_ready_by_id IS NOT NULL) AND (forecast_ready_at IS NOT NULL) AND (readiness_fingerprint IS NOT NULL) AND (btrim((readiness_fingerprint)::text) <> ''::text) AND (char_length((readiness_fingerprint)::text) <= 128) AND (((stage)::text <> 'contracted'::text) OR (readiness_provenance IS NOT NULL))))),
    CONSTRAINT supplier_cost_definitions_rounding_mode CHECK (((rounding_mode)::text = 'half_up'::text)),
    CONSTRAINT supplier_cost_definitions_stage CHECK (((stage)::text = ANY ((ARRAY['estimate'::character varying, 'contracted'::character varying])::text[]))),
    CONSTRAINT supplier_cost_definitions_status CHECK (((status)::text = ANY ((ARRAY['working'::character varying, 'forecast_ready'::character varying])::text[]))),
    CONSTRAINT supplier_cost_definitions_zero_cost_reason CHECK (((zero_cost_reason IS NULL) OR ((btrim((zero_cost_reason)::text) <> ''::text) AND (char_length((zero_cost_reason)::text) <= 500)))),
    CONSTRAINT supplier_cost_definitions_zero_reason_pair CHECK ((((mode)::text = 'zero_cost'::text) = (zero_cost_reason IS NOT NULL)))
);


--
-- Name: supplier_cost_occupancy_profile_positions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_cost_occupancy_profile_positions (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid CONSTRAINT supplier_cost_occupancy_profi_supplier_arrangement_id_not_null1 NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_cost_occupancy_pr_supplier_arrangement_versi_not_null1 NOT NULL,
    arrangement_item_id uuid CONSTRAINT supplier_cost_occupancy_profile_po_arrangement_item_id_not_null NOT NULL,
    supplier_cost_usage_assumption_id uuid CONSTRAINT supplier_cost_occupancy_pr_supplier_cost_usage_assump_not_null1 NOT NULL,
    supplier_cost_occupancy_profile_id uuid CONSTRAINT supplier_cost_occupancy_pro_supplier_cost_occupancy_pr_not_null NOT NULL,
    participant_category_id uuid CONSTRAINT supplier_cost_occupancy_profil_participant_category_id_not_null NOT NULL,
    occupancy_position integer CONSTRAINT supplier_cost_occupancy_profile_pos_occupancy_position_not_null NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    copied_from_id uuid,
    CONSTRAINT supplier_cost_profile_positions_positive CHECK ((occupancy_position > 0))
);


--
-- Name: supplier_cost_occupancy_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_cost_occupancy_profiles (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid CONSTRAINT supplier_cost_occupancy_profil_supplier_arrangement_id_not_null NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_cost_occupancy_pro_supplier_arrangement_versi_not_null NOT NULL,
    arrangement_item_id uuid NOT NULL,
    supplier_cost_usage_assumption_id uuid CONSTRAINT supplier_cost_occupancy_pro_supplier_cost_usage_assump_not_null NOT NULL,
    label character varying(120) NOT NULL,
    resource_unit_count bigint NOT NULL,
    "position" integer NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    copied_from_id uuid,
    CONSTRAINT supplier_cost_occupancy_profiles_label CHECK (((btrim((label)::text) <> ''::text) AND (char_length((label)::text) <= 120))),
    CONSTRAINT supplier_cost_occupancy_profiles_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_cost_occupancy_profiles_position_positive CHECK (("position" > 0)),
    CONSTRAINT supplier_cost_profiles_unit_count_positive CHECK ((resource_unit_count > 0))
);


--
-- Name: supplier_cost_participant_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_cost_participant_categories (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid CONSTRAINT supplier_cost_participant_cate_supplier_arrangement_id_not_null NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_cost_participant_c_supplier_arrangement_versi_not_null NOT NULL,
    arrangement_item_id uuid CONSTRAINT supplier_cost_participant_categori_arrangement_item_id_not_null NOT NULL,
    label character varying(80) NOT NULL,
    "position" integer NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    copied_from_id uuid,
    CONSTRAINT supplier_cost_participant_categories_label CHECK (((btrim((label)::text) <> ''::text) AND (char_length((label)::text) <= 80))),
    CONSTRAINT supplier_cost_participant_categories_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_cost_participant_categories_position_positive CHECK (("position" > 0))
);


--
-- Name: supplier_cost_sources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_cost_sources (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    supplier_arrangement_version_id uuid NOT NULL,
    arrangement_item_id uuid,
    service_occurrence_id uuid,
    supplier_resource_id uuid,
    charging_supplier_id uuid NOT NULL,
    label character varying(160) NOT NULL,
    notes character varying(2000),
    "position" integer NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    copied_from_id uuid,
    CONSTRAINT supplier_cost_sources_context_shape CHECK ((((arrangement_item_id IS NULL) AND (service_occurrence_id IS NULL) AND (supplier_resource_id IS NULL)) OR (arrangement_item_id IS NOT NULL))),
    CONSTRAINT supplier_cost_sources_label CHECK (((btrim((label)::text) <> ''::text) AND (char_length((label)::text) <= 160))),
    CONSTRAINT supplier_cost_sources_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_cost_sources_notes CHECK (((notes IS NULL) OR ((btrim((notes)::text) <> ''::text) AND (char_length((notes)::text) <= 2000)))),
    CONSTRAINT supplier_cost_sources_position_positive CHECK (("position" > 0))
);


--
-- Name: supplier_cost_usage_assumptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_cost_usage_assumptions (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid CONSTRAINT supplier_cost_usage_assumption_supplier_arrangement_id_not_null NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_cost_usage_assumpt_supplier_arrangement_versi_not_null NOT NULL,
    arrangement_item_id uuid NOT NULL,
    service_occurrence_id uuid,
    supplier_resource_id uuid,
    expected_resource_units bigint,
    expected_persons bigint,
    expected_billable_nights bigint,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    copied_from_id uuid,
    CONSTRAINT supplier_cost_assumptions_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_cost_assumptions_quantities_nonnegative CHECK ((((expected_resource_units IS NULL) OR (expected_resource_units >= 0)) AND ((expected_persons IS NULL) OR (expected_persons >= 0)) AND ((expected_billable_nights IS NULL) OR (expected_billable_nights >= 0))))
);


--
-- Name: supplier_deadline_commitment_definition_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_deadline_commitment_definition_lines (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid CONSTRAINT supplier_deadline_commitment_definition_line_agency_id_not_null NOT NULL,
    departure_id uuid CONSTRAINT supplier_deadline_commitment_definition_l_departure_id_not_null NOT NULL,
    supplier_arrangement_id uuid CONSTRAINT supplier_deadline_commitment_d_supplier_arrangement_id_not_null NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_deadline_commitmen_supplier_arrangement_versi_not_null NOT NULL,
    supplier_deadline_definition_id uuid CONSTRAINT supplier_deadline_commitmen_supplier_deadline_definiti_not_null NOT NULL,
    committed_supplier_id uuid CONSTRAINT supplier_deadline_commitment_def_committed_supplier_id_not_null NOT NULL,
    authority_shape character varying CONSTRAINT supplier_deadline_commitment_definitio_authority_shape_not_null NOT NULL,
    description character varying(500) CONSTRAINT supplier_deadline_commitment_definition_li_description_not_null NOT NULL,
    fixed_quantity bigint,
    quantity_basis character varying,
    fixed_amount_minor_units bigint,
    currency character varying(3),
    supplier_cost_source_id uuid,
    supplier_cost_definition_id uuid,
    supplier_cost_component_id uuid,
    "position" integer NOT NULL,
    lock_version integer DEFAULT 0 CONSTRAINT supplier_deadline_commitment_definition_l_lock_version_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT supplier_deadline_commitment_definition_lin_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT supplier_deadline_commitment_definition_lin_updated_at_not_null NOT NULL,
    CONSTRAINT deadline_commitment_lines_authority_fields CHECK (((((authority_shape)::text = 'fixed_quantity'::text) AND (fixed_quantity > 0) AND (quantity_basis IS NOT NULL) AND (fixed_amount_minor_units IS NULL) AND (currency IS NULL) AND (supplier_cost_definition_id IS NULL) AND (supplier_cost_component_id IS NULL)) OR (((authority_shape)::text = 'fixed_contracted_amount'::text) AND (fixed_quantity IS NULL) AND (quantity_basis IS NULL) AND (fixed_amount_minor_units IS NULL) AND (currency IS NOT NULL) AND (supplier_cost_definition_id IS NOT NULL) AND (supplier_cost_component_id IS NOT NULL)))),
    CONSTRAINT deadline_commitment_lines_authority_shape CHECK (((authority_shape)::text = ANY ((ARRAY['fixed_quantity'::character varying, 'fixed_contracted_amount'::character varying])::text[]))),
    CONSTRAINT deadline_commitment_lines_currency CHECK (((currency IS NULL) OR ((currency)::text ~ '^[A-Z]{3}$'::text))),
    CONSTRAINT deadline_commitment_lines_description CHECK (((btrim((description)::text) <> ''::text) AND (char_length((description)::text) <= 500))),
    CONSTRAINT deadline_commitment_lines_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT deadline_commitment_lines_position_positive CHECK (("position" > 0)),
    CONSTRAINT deadline_commitment_lines_quantity_basis CHECK (((quantity_basis IS NULL) OR ((quantity_basis)::text = ANY ((ARRAY['resource_units'::character varying, 'traveler_positions'::character varying])::text[]))))
);


--
-- Name: supplier_deadline_definition_coverage_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_deadline_definition_coverage_links (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid CONSTRAINT supplier_deadline_definition_coverage_lin_departure_id_not_null NOT NULL,
    supplier_arrangement_id uuid CONSTRAINT supplier_deadline_definition_c_supplier_arrangement_id_not_null NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_deadline_definiti_supplier_arrangement_versi_not_null1 NOT NULL,
    supplier_deadline_definition_id uuid CONSTRAINT supplier_deadline_definitio_supplier_deadline_definiti_not_null NOT NULL,
    arrangement_item_id uuid,
    service_occurrence_id uuid,
    supplier_resource_id uuid,
    capacity_pool_id uuid,
    "position" integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT deadline_coverage_links_exactly_one_target CHECK ((((arrangement_item_id IS NOT NULL) AND (service_occurrence_id IS NULL) AND (supplier_resource_id IS NULL) AND (capacity_pool_id IS NULL)) OR ((arrangement_item_id IS NOT NULL) AND (service_occurrence_id IS NOT NULL) AND (supplier_resource_id IS NULL) AND (capacity_pool_id IS NULL)) OR ((arrangement_item_id IS NOT NULL) AND (supplier_resource_id IS NOT NULL) AND (service_occurrence_id IS NULL) AND (capacity_pool_id IS NULL)) OR ((arrangement_item_id IS NOT NULL) AND (service_occurrence_id IS NOT NULL) AND (supplier_resource_id IS NOT NULL) AND (capacity_pool_id IS NOT NULL)))),
    CONSTRAINT deadline_coverage_links_position_positive CHECK (("position" > 0))
);


--
-- Name: supplier_deadline_definitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_deadline_definitions (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_deadline_definitio_supplier_arrangement_versi_not_null NOT NULL,
    deadline_type character varying NOT NULL,
    other_label character varying(120),
    kind character varying NOT NULL,
    rule_shape character varying NOT NULL,
    rule_parameters jsonb DEFAULT '{}'::jsonb NOT NULL,
    "precision" character varying NOT NULL,
    time_zone character varying(64) NOT NULL,
    cardinality character varying DEFAULT 'one_shared'::character varying NOT NULL,
    warning_lead_days integer,
    "position" integer NOT NULL,
    description character varying(500),
    copied_from_id uuid,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT deadline_definitions_cardinality CHECK (((cardinality)::text = ANY ((ARRAY['one_shared'::character varying, 'per_source'::character varying])::text[]))),
    CONSTRAINT deadline_definitions_description CHECK (((description IS NULL) OR ((btrim((description)::text) <> ''::text) AND (char_length((description)::text) <= 500)))),
    CONSTRAINT deadline_definitions_kind CHECK (((kind)::text = ANY ((ARRAY['actionable'::character varying, 'informational'::character varying])::text[]))),
    CONSTRAINT deadline_definitions_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT deadline_definitions_other_label CHECK (((((deadline_type)::text = 'other'::text) AND (other_label IS NOT NULL) AND (btrim((other_label)::text) <> ''::text)) OR (((deadline_type)::text <> 'other'::text) AND (other_label IS NULL)))),
    CONSTRAINT deadline_definitions_other_label_length CHECK (((other_label IS NULL) OR ((btrim((other_label)::text) <> ''::text) AND (char_length((other_label)::text) <= 120)))),
    CONSTRAINT deadline_definitions_position_positive CHECK (("position" > 0)),
    CONSTRAINT deadline_definitions_precision CHECK ((("precision")::text = ANY ((ARRAY['date_only'::character varying, 'local_date_time'::character varying])::text[]))),
    CONSTRAINT deadline_definitions_rule_shape CHECK (((rule_shape)::text = ANY ((ARRAY['fixed_date'::character varying, 'fixed_local_datetime'::character varying, 'days_before_departure'::character varying, 'days_after_departure'::character varying, 'hours_before_departure'::character varying, 'hours_after_departure'::character varying, 'earlier_of'::character varying, 'later_of'::character varying])::text[]))),
    CONSTRAINT deadline_definitions_time_zone CHECK (((btrim((time_zone)::text) <> ''::text) AND (char_length((time_zone)::text) <= 64))),
    CONSTRAINT deadline_definitions_type CHECK (((deadline_type)::text = ANY ((ARRAY['deposit_due'::character varying, 'option_or_release_date'::character varying, 'rooming_list_due'::character varying, 'legal_names_due'::character varying, 'final_count_due'::character varying, 'final_schedule_or_departure_time_due'::character varying, 'cancellation_cutoff'::character varying, 'accessibility_confirmation_due'::character varying, 'other'::character varying])::text[]))),
    CONSTRAINT deadline_definitions_warning_lead CHECK (((warning_lead_days IS NULL) OR (warning_lead_days >= 0)))
);


--
-- Name: supplier_deadline_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_deadline_occurrences (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_deadline_occurrenc_supplier_arrangement_versi_not_null NOT NULL,
    supplier_deadline_definition_id uuid CONSTRAINT supplier_deadline_occurrenc_supplier_deadline_definiti_not_null NOT NULL,
    supplier_arrangement_activation_id uuid,
    deadline_type character varying NOT NULL,
    other_label character varying(120),
    kind character varying NOT NULL,
    rule_shape character varying NOT NULL,
    rule_parameters_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    rule_inputs_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    "precision" character varying NOT NULL,
    time_zone character varying(64) NOT NULL,
    cardinality character varying NOT NULL,
    coverage_snapshot jsonb DEFAULT '[]'::jsonb NOT NULL,
    calculated_on date,
    calculated_at timestamp with time zone,
    materialization_key character varying(256) NOT NULL,
    predecessor_occurrence_id uuid,
    superseded_at timestamp with time zone,
    actor_id uuid NOT NULL,
    materialized_at timestamp with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT deadline_occurrences_cardinality CHECK (((cardinality)::text = ANY ((ARRAY['one_shared'::character varying, 'per_source'::character varying])::text[]))),
    CONSTRAINT deadline_occurrences_kind CHECK (((kind)::text = ANY ((ARRAY['actionable'::character varying, 'informational'::character varying])::text[]))),
    CONSTRAINT deadline_occurrences_materialization_key CHECK (((btrim((materialization_key)::text) <> ''::text) AND (char_length((materialization_key)::text) <= 256))),
    CONSTRAINT deadline_occurrences_precision CHECK ((("precision")::text = ANY ((ARRAY['date_only'::character varying, 'local_date_time'::character varying])::text[]))),
    CONSTRAINT deadline_occurrences_precision_exclusivity CHECK ((((("precision")::text = 'date_only'::text) AND (calculated_on IS NOT NULL) AND (calculated_at IS NULL)) OR ((("precision")::text = 'local_date_time'::text) AND (calculated_at IS NOT NULL) AND (calculated_on IS NULL)))),
    CONSTRAINT deadline_occurrences_rule_shape CHECK (((rule_shape)::text = ANY ((ARRAY['fixed_date'::character varying, 'fixed_local_datetime'::character varying, 'days_before_departure'::character varying, 'days_after_departure'::character varying, 'hours_before_departure'::character varying, 'hours_after_departure'::character varying, 'earlier_of'::character varying, 'later_of'::character varying])::text[]))),
    CONSTRAINT deadline_occurrences_time_zone CHECK (((btrim((time_zone)::text) <> ''::text) AND (char_length((time_zone)::text) <= 64))),
    CONSTRAINT deadline_occurrences_type CHECK (((deadline_type)::text = ANY ((ARRAY['deposit_due'::character varying, 'option_or_release_date'::character varying, 'rooming_list_due'::character varying, 'legal_names_due'::character varying, 'final_count_due'::character varying, 'final_schedule_or_departure_time_due'::character varying, 'cancellation_cutoff'::character varying, 'accessibility_confirmation_due'::character varying, 'other'::character varying])::text[])))
);


--
-- Name: supplier_deadline_projections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_deadline_projections (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_deadline_projectio_supplier_arrangement_versi_not_null NOT NULL,
    supplier_deadline_occurrence_id uuid CONSTRAINT supplier_deadline_projectio_supplier_deadline_occurren_not_null NOT NULL,
    status character varying NOT NULL,
    due_on date,
    due_at timestamp with time zone,
    warning_starts_at timestamp with time zone,
    overdue_at timestamp with time zone NOT NULL,
    refreshed_at timestamp with time zone NOT NULL,
    next_transition_at timestamp with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT deadline_projections_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT deadline_projections_status CHECK (((status)::text = ANY ((ARRAY['upcoming'::character varying, 'warning'::character varying, 'due'::character varying, 'overdue'::character varying])::text[])))
);


--
-- Name: supplier_email_addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_email_addresses (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_id uuid NOT NULL,
    label character varying(40),
    status character varying DEFAULT 'active'::character varying NOT NULL,
    preferred boolean DEFAULT false NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    address character varying NOT NULL,
    normalized_address text GENERATED ALWAYS AS (lower(btrim((address)::text))) STORED,
    CONSTRAINT supplier_email_addresses_label_length CHECK (((label IS NULL) OR (char_length((label)::text) <= 40))),
    CONSTRAINT supplier_email_addresses_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_email_addresses_normalized CHECK (((normalized_address = lower(btrim((address)::text))) AND (normalized_address <> ''::text))),
    CONSTRAINT supplier_email_addresses_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
);


--
-- Name: supplier_issued_identifiers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_issued_identifiers (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    supplier_id uuid NOT NULL,
    issuer_context character varying(80) NOT NULL,
    identifier_type character varying NOT NULL,
    other_type_label character varying(80),
    display_value character varying(160) NOT NULL,
    normalized_value character varying(160) NOT NULL,
    first_supplier_confirmation_id uuid CONSTRAINT supplier_issued_identifiers_first_supplier_confirmatio_not_null NOT NULL,
    supersedes_id uuid,
    superseded_at timestamp with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    supplier_reservation_id uuid,
    CONSTRAINT supplier_identifiers_display_value CHECK (((btrim((display_value)::text) <> ''::text) AND (char_length((display_value)::text) <= 160))),
    CONSTRAINT supplier_identifiers_issuer_context CHECK (((btrim((issuer_context)::text) <> ''::text) AND (char_length((issuer_context)::text) <= 80))),
    CONSTRAINT supplier_identifiers_normalized_value CHECK (((btrim((normalized_value)::text) <> ''::text) AND (char_length((normalized_value)::text) <= 160))),
    CONSTRAINT supplier_identifiers_other_label_pair CHECK ((((identifier_type)::text = 'other'::text) = (other_type_label IS NOT NULL))),
    CONSTRAINT supplier_identifiers_other_type_label CHECK (((other_type_label IS NULL) OR ((btrim((other_type_label)::text) <> ''::text) AND (char_length((other_type_label)::text) <= 80)))),
    CONSTRAINT supplier_identifiers_supersession_pair CHECK (((superseded_at IS NULL) OR (supersedes_id IS NULL))),
    CONSTRAINT supplier_identifiers_type CHECK (((identifier_type)::text = ANY ((ARRAY['group_number'::character varying, 'reservation_number'::character varying, 'confirmation_number'::character varying, 'policy_number'::character varying, 'other'::character varying])::text[])))
);


--
-- Name: supplier_locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_locations (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_id uuid NOT NULL,
    name character varying(160) NOT NULL,
    timezone character varying,
    address_line_1 character varying,
    address_line_2 character varying,
    address_locality character varying,
    address_region character varying,
    address_postal_code character varying,
    address_country_code character varying,
    phone_number character varying,
    phone_normalized_number character varying,
    phone_extension character varying,
    phone_country_code character varying,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    name_search_key text GENERATED ALWAYS AS (public.dd_search_normalize((name)::text)) STORED,
    locality_search_key text GENERATED ALWAYS AS (public.dd_search_normalize((address_locality)::text)) STORED,
    postal_code_search_key text GENERATED ALWAYS AS (public.dd_search_normalize((address_postal_code)::text)) STORED,
    postal_address_search_key text GENERATED ALWAYS AS (
CASE
    WHEN (address_line_1 IS NULL) THEN NULL::text
    ELSE ((((((((((COALESCE(public.dd_search_normalize((address_line_1)::text), ''::text) || ''::text) || COALESCE(public.dd_search_normalize((address_line_2)::text), ''::text)) || ''::text) || COALESCE(public.dd_search_normalize((address_locality)::text), ''::text)) || ''::text) || COALESCE(public.dd_search_normalize((address_region)::text), ''::text)) || ''::text) || COALESCE(public.dd_search_normalize((address_postal_code)::text), ''::text)) || ''::text) || COALESCE(upper((address_country_code)::text), ''::text))
END) STORED,
    name_search_vector tsvector GENERATED ALWAYS AS (to_tsvector('simple'::regconfig, public.dd_search_normalize((name)::text))) STORED,
    CONSTRAINT supplier_locations_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_locations_name CHECK (((btrim((name)::text) <> ''::text) AND (char_length((name)::text) <= 160))),
    CONSTRAINT supplier_locations_no_unit_separator CHECK ((((address_line_1 IS NULL) OR (POSITION((''::text) IN (address_line_1)) = 0)) AND ((address_line_2 IS NULL) OR (POSITION((''::text) IN (address_line_2)) = 0)) AND ((address_locality IS NULL) OR (POSITION((''::text) IN (address_locality)) = 0)) AND ((address_region IS NULL) OR (POSITION((''::text) IN (address_region)) = 0)) AND ((address_postal_code IS NULL) OR (POSITION((''::text) IN (address_postal_code)) = 0)))),
    CONSTRAINT supplier_locations_phone_shape CHECK ((((phone_number IS NULL) AND (phone_normalized_number IS NULL) AND (phone_extension IS NULL) AND (phone_country_code IS NULL)) OR ((phone_number IS NOT NULL) AND (btrim((phone_number)::text) <> ''::text) AND (phone_normalized_number IS NOT NULL) AND ((phone_normalized_number)::text ~ '^\+[1-9][0-9]{0,14}$'::text) AND (phone_country_code IS NOT NULL) AND ((phone_country_code)::text ~ '^[A-Z]{2}$'::text) AND ((phone_extension IS NULL) OR ((phone_extension)::text ~ '^[0-9]{1,10}$'::text))))),
    CONSTRAINT supplier_locations_postal_shape CHECK ((((address_line_1 IS NULL) AND (address_line_2 IS NULL) AND (address_locality IS NULL) AND (address_region IS NULL) AND (address_postal_code IS NULL) AND (address_country_code IS NULL)) OR ((address_line_1 IS NOT NULL) AND (btrim((address_line_1)::text) <> ''::text) AND (address_country_code IS NOT NULL) AND ((address_country_code)::text ~ '^[A-Z]{2}$'::text)))),
    CONSTRAINT supplier_locations_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
);


--
-- Name: supplier_phone_numbers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_phone_numbers (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_id uuid NOT NULL,
    label character varying(40),
    status character varying DEFAULT 'active'::character varying NOT NULL,
    preferred boolean DEFAULT false NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    number character varying NOT NULL,
    normalized_number character varying NOT NULL,
    extension character varying,
    country_code character varying NOT NULL,
    phone_digits_reversed text GENERATED ALWAYS AS (reverse(SUBSTRING(normalized_number FROM 2))) STORED,
    CONSTRAINT supplier_phone_numbers_country_shape CHECK (((country_code)::text ~ '^[A-Z]{2}$'::text)),
    CONSTRAINT supplier_phone_numbers_e164_shape CHECK (((normalized_number)::text ~ '^\+[1-9][0-9]{0,14}$'::text)),
    CONSTRAINT supplier_phone_numbers_extension CHECK (((extension IS NULL) OR ((extension)::text ~ '^[0-9]{1,10}$'::text))),
    CONSTRAINT supplier_phone_numbers_label_length CHECK (((label IS NULL) OR (char_length((label)::text) <= 40))),
    CONSTRAINT supplier_phone_numbers_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_phone_numbers_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
);


--
-- Name: supplier_postal_addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_postal_addresses (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_id uuid NOT NULL,
    label character varying(40),
    status character varying DEFAULT 'active'::character varying NOT NULL,
    preferred boolean DEFAULT false NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    line_1 character varying NOT NULL,
    line_2 character varying,
    locality character varying,
    region character varying,
    postal_code character varying,
    country_code character varying NOT NULL,
    postal_code_search_key text GENERATED ALWAYS AS (public.dd_search_normalize((postal_code)::text)) STORED,
    locality_search_key text GENERATED ALWAYS AS (public.dd_search_normalize((locality)::text)) STORED,
    CONSTRAINT supplier_postal_addresses_country_shape CHECK (((country_code)::text ~ '^[A-Z]{2}$'::text)),
    CONSTRAINT supplier_postal_addresses_label_length CHECK (((label IS NULL) OR (char_length((label)::text) <= 40))),
    CONSTRAINT supplier_postal_addresses_line_1 CHECK ((btrim((line_1)::text) <> ''::text)),
    CONSTRAINT supplier_postal_addresses_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_postal_addresses_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
);


--
-- Name: supplier_reservation_event_scope_outcomes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_reservation_event_scope_outcomes (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid CONSTRAINT supplier_reservation_event_sco_supplier_arrangement_id_not_null NOT NULL,
    supplier_reservation_id uuid CONSTRAINT supplier_reservation_event_sco_supplier_reservation_id_not_null NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_reservation_event__supplier_arrangement_versi_not_null NOT NULL,
    supplier_reservation_revision_id uuid CONSTRAINT supplier_reservation_event__supplier_reservation_revis_not_null NOT NULL,
    supplier_reservation_event_id uuid CONSTRAINT supplier_reservation_event__supplier_reservation_event_not_null NOT NULL,
    supplier_reservation_scope_id uuid CONSTRAINT supplier_reservation_event__supplier_reservation_scope_not_null NOT NULL,
    outcome_kind character varying NOT NULL,
    quantity bigint,
    quantity_basis character varying,
    supplier_note character varying(500),
    decline_reason character varying(500),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT reservation_outcomes_decline_reason CHECK ((((outcome_kind)::text = 'declined'::text) = (decline_reason IS NOT NULL))),
    CONSTRAINT reservation_outcomes_decline_reason_text CHECK (((decline_reason IS NULL) OR ((btrim((decline_reason)::text) <> ''::text) AND (char_length((decline_reason)::text) <= 500)))),
    CONSTRAINT reservation_outcomes_kind CHECK (((outcome_kind)::text = ANY ((ARRAY['requested'::character varying, 'withdrawn'::character varying, 'cancelled'::character varying, 'confirmed'::character varying, 'declined'::character varying, 'counterproposed'::character varying])::text[]))),
    CONSTRAINT reservation_outcomes_quantity_shape CHECK ((((quantity IS NULL) AND (quantity_basis IS NULL)) OR ((quantity > 0) AND ((quantity_basis)::text = ANY ((ARRAY['resource_units'::character varying, 'traveler_positions'::character varying])::text[]))))),
    CONSTRAINT reservation_outcomes_supplier_note CHECK (((supplier_note IS NULL) OR ((btrim((supplier_note)::text) <> ''::text) AND (char_length((supplier_note)::text) <= 500))))
);


--
-- Name: supplier_reservation_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_reservation_events (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    supplier_reservation_id uuid NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_reservation_events_supplier_arrangement_versi_not_null NOT NULL,
    supplier_reservation_revision_id uuid CONSTRAINT supplier_reservation_events_supplier_reservation_revis_not_null NOT NULL,
    event_kind character varying NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    recorded_at timestamp with time zone NOT NULL,
    actor_id uuid NOT NULL,
    supplier_contact_id uuid,
    channel character varying(80),
    safe_contact_snapshot character varying(500),
    reference_note character varying(500),
    reason character varying(500),
    scope_fingerprint character varying(128),
    agency_command_idempotency_key_id uuid,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT reservation_events_channel CHECK (((channel IS NULL) OR ((btrim((channel)::text) <> ''::text) AND (char_length((channel)::text) <= 80)))),
    CONSTRAINT reservation_events_kind CHECK (((event_kind)::text = ANY ((ARRAY['request'::character varying, 'withdrawal'::character varying, 'cancellation'::character varying, 'response'::character varying, 'revision'::character varying])::text[]))),
    CONSTRAINT reservation_events_reason CHECK (((reason IS NULL) OR ((btrim((reason)::text) <> ''::text) AND (char_length((reason)::text) <= 500)))),
    CONSTRAINT reservation_events_reference_note CHECK (((reference_note IS NULL) OR ((btrim((reference_note)::text) <> ''::text) AND (char_length((reference_note)::text) <= 500)))),
    CONSTRAINT reservation_events_required_context CHECK (((((event_kind)::text = ANY ((ARRAY['request'::character varying, 'response'::character varying])::text[])) AND (channel IS NOT NULL) AND (reference_note IS NOT NULL)) OR (((event_kind)::text = ANY ((ARRAY['withdrawal'::character varying, 'cancellation'::character varying])::text[])) AND (reason IS NOT NULL)) OR ((event_kind)::text = 'revision'::text))),
    CONSTRAINT reservation_events_safe_contact_snapshot CHECK (((safe_contact_snapshot IS NULL) OR ((btrim((safe_contact_snapshot)::text) <> ''::text) AND (char_length((safe_contact_snapshot)::text) <= 500)))),
    CONSTRAINT reservation_events_scope_fingerprint CHECK (((scope_fingerprint IS NULL) OR ((btrim((scope_fingerprint)::text) <> ''::text) AND (char_length((scope_fingerprint)::text) <= 128))))
);


--
-- Name: supplier_reservation_projections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_reservation_projections (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid CONSTRAINT supplier_reservation_projectio_supplier_arrangement_id_not_null NOT NULL,
    supplier_reservation_id uuid CONSTRAINT supplier_reservation_projectio_supplier_reservation_id_not_null NOT NULL,
    current_revision_id uuid,
    state character varying NOT NULL,
    planned_scope_count integer DEFAULT 0 NOT NULL,
    pending_scope_count integer DEFAULT 0 NOT NULL,
    confirmed_scope_count integer DEFAULT 0 NOT NULL,
    counterproposed_scope_count integer DEFAULT 0 CONSTRAINT supplier_reservation_projec_counterproposed_scope_coun_not_null NOT NULL,
    declined_scope_count integer DEFAULT 0 NOT NULL,
    withdrawn_scope_count integer DEFAULT 0 NOT NULL,
    cancelled_scope_count integer DEFAULT 0 NOT NULL,
    rebuilt_at timestamp with time zone NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT reservation_projections_counts_nonnegative CHECK (((planned_scope_count >= 0) AND (pending_scope_count >= 0) AND (confirmed_scope_count >= 0) AND (counterproposed_scope_count >= 0) AND (declined_scope_count >= 0) AND (withdrawn_scope_count >= 0) AND (cancelled_scope_count >= 0))),
    CONSTRAINT reservation_projections_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT reservation_projections_state CHECK (((state)::text = ANY ((ARRAY['planned'::character varying, 'requested'::character varying, 'partially_confirmed'::character varying, 'confirmed'::character varying, 'declined'::character varying, 'withdrawn'::character varying, 'cancelled'::character varying])::text[])))
);


--
-- Name: supplier_reservation_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_reservation_revisions (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    supplier_reservation_id uuid NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_reservation_revisi_supplier_arrangement_versi_not_null NOT NULL,
    revision_number integer NOT NULL,
    status character varying NOT NULL,
    actor_id uuid NOT NULL,
    requested_at timestamp with time zone,
    abandoned_at timestamp with time zone,
    abandoned_reason character varying(500),
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT reservation_revisions_abandoned_reason CHECK (((abandoned_reason IS NULL) OR ((btrim((abandoned_reason)::text) <> ''::text) AND (char_length((abandoned_reason)::text) <= 500)))),
    CONSTRAINT reservation_revisions_lifecycle_shape CHECK (((((status)::text = 'planned'::text) AND (requested_at IS NULL) AND (abandoned_at IS NULL) AND (abandoned_reason IS NULL)) OR (((status)::text = 'requested'::text) AND (requested_at IS NOT NULL) AND (abandoned_at IS NULL) AND (abandoned_reason IS NULL)) OR (((status)::text = 'superseded'::text) AND (requested_at IS NOT NULL) AND (abandoned_at IS NULL) AND (abandoned_reason IS NULL)) OR (((status)::text = 'abandoned'::text) AND (requested_at IS NULL) AND (abandoned_at IS NOT NULL) AND (abandoned_reason IS NOT NULL)))),
    CONSTRAINT reservation_revisions_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT reservation_revisions_number_positive CHECK ((revision_number > 0)),
    CONSTRAINT reservation_revisions_status CHECK (((status)::text = ANY ((ARRAY['planned'::character varying, 'requested'::character varying, 'superseded'::character varying, 'abandoned'::character varying])::text[])))
);


--
-- Name: supplier_reservation_scopes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_reservation_scopes (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    supplier_reservation_id uuid NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_reservation_scopes_supplier_arrangement_versi_not_null NOT NULL,
    supplier_reservation_revision_id uuid CONSTRAINT supplier_reservation_scopes_supplier_reservation_revis_not_null NOT NULL,
    "position" integer NOT NULL,
    target_kind character varying NOT NULL,
    arrangement_item_id uuid,
    service_occurrence_id uuid,
    supplier_resource_id uuid,
    capacity_pool_id uuid,
    label character varying(160),
    requested_quantity bigint,
    quantity_basis character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT reservation_scopes_label CHECK (((label IS NULL) OR ((btrim((label)::text) <> ''::text) AND (char_length((label)::text) <= 160)))),
    CONSTRAINT reservation_scopes_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT reservation_scopes_position_positive CHECK (("position" > 0)),
    CONSTRAINT reservation_scopes_quantity_shape CHECK ((((requested_quantity IS NULL) AND (quantity_basis IS NULL)) OR ((requested_quantity > 0) AND ((quantity_basis)::text = ANY ((ARRAY['resource_units'::character varying, 'traveler_positions'::character varying])::text[]))))),
    CONSTRAINT reservation_scopes_target_kind CHECK (((target_kind)::text = ANY ((ARRAY['arrangement'::character varying, 'item'::character varying, 'occurrence'::character varying, 'resource'::character varying, 'capacity_pool'::character varying])::text[]))),
    CONSTRAINT reservation_scopes_target_shape CHECK (((((target_kind)::text = 'arrangement'::text) AND (arrangement_item_id IS NULL) AND (service_occurrence_id IS NULL) AND (supplier_resource_id IS NULL) AND (capacity_pool_id IS NULL)) OR (((target_kind)::text = 'item'::text) AND (arrangement_item_id IS NOT NULL) AND (service_occurrence_id IS NULL) AND (supplier_resource_id IS NULL) AND (capacity_pool_id IS NULL)) OR (((target_kind)::text = 'occurrence'::text) AND (arrangement_item_id IS NOT NULL) AND (service_occurrence_id IS NOT NULL) AND (supplier_resource_id IS NULL) AND (capacity_pool_id IS NULL)) OR (((target_kind)::text = 'resource'::text) AND (arrangement_item_id IS NOT NULL) AND (service_occurrence_id IS NULL) AND (supplier_resource_id IS NOT NULL) AND (capacity_pool_id IS NULL)) OR (((target_kind)::text = 'capacity_pool'::text) AND (arrangement_item_id IS NOT NULL) AND (service_occurrence_id IS NOT NULL) AND (supplier_resource_id IS NOT NULL) AND (capacity_pool_id IS NOT NULL))))
);


--
-- Name: supplier_reservations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_reservations (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    booking_supplier_id uuid NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT supplier_reservations_lock_version CHECK ((lock_version >= 0))
);


--
-- Name: supplier_resource_definitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_resource_definitions (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    supplier_arrangement_version_id uuid CONSTRAINT supplier_resource_definitio_supplier_arrangement_versi_not_null NOT NULL,
    arrangement_item_id uuid NOT NULL,
    supplier_resource_id uuid NOT NULL,
    name character varying(160) NOT NULL,
    description character varying(2000),
    "position" integer NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    copied_from_id uuid,
    CONSTRAINT supplier_resource_definitions_description CHECK (((description IS NULL) OR ((btrim((description)::text) <> ''::text) AND (char_length((description)::text) <= 2000)))),
    CONSTRAINT supplier_resource_definitions_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_resource_definitions_name CHECK (((btrim((name)::text) <> ''::text) AND (char_length((name)::text) <= 160))),
    CONSTRAINT supplier_resource_definitions_position_positive CHECK (("position" > 0))
);


--
-- Name: supplier_resources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_resources (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    arrangement_item_id uuid NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: supplier_websites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_websites (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_id uuid NOT NULL,
    label character varying(40),
    status character varying DEFAULT 'active'::character varying NOT NULL,
    preferred boolean DEFAULT false NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    url character varying NOT NULL,
    normalized_url character varying NOT NULL,
    normalized_host character varying NOT NULL,
    CONSTRAINT supplier_websites_label_length CHECK (((label IS NULL) OR (char_length((label)::text) <= 40))),
    CONSTRAINT supplier_websites_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_websites_normalized_host_present CHECK ((btrim((normalized_host)::text) <> ''::text)),
    CONSTRAINT supplier_websites_normalized_url_present CHECK ((btrim((normalized_url)::text) <> ''::text)),
    CONSTRAINT supplier_websites_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[]))),
    CONSTRAINT supplier_websites_url_present CHECK ((btrim((url)::text) <> ''::text))
);


--
-- Name: suppliers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.suppliers (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    kind character varying NOT NULL,
    supplier_reference character varying(10) NOT NULL,
    display_name character varying,
    legal_name character varying,
    first_name character varying,
    last_name character varying,
    doing_business_as character varying,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    display_name_search_key text GENERATED ALWAYS AS (public.dd_search_normalize((display_name)::text)) STORED,
    legal_name_search_key text GENERATED ALWAYS AS (public.dd_search_normalize((legal_name)::text)) STORED,
    first_name_search_key text GENERATED ALWAYS AS (public.dd_search_normalize((first_name)::text)) STORED,
    last_name_search_key text GENERATED ALWAYS AS (public.dd_search_normalize((last_name)::text)) STORED,
    doing_business_as_search_key text GENERATED ALWAYS AS (public.dd_search_normalize((doing_business_as)::text)) STORED,
    individual_full_name_search_key text GENERATED ALWAYS AS (
CASE
    WHEN ((kind)::text = 'individual'::text) THEN public.dd_search_normalize((((first_name)::text || ' '::text) || (last_name)::text))
    ELSE NULL::text
END) STORED,
    name_search_vector tsvector GENERATED ALWAYS AS (to_tsvector('simple'::regconfig, ((((((((COALESCE(public.dd_search_normalize((display_name)::text), ''::text) || ' '::text) || COALESCE(public.dd_search_normalize((legal_name)::text), ''::text)) || ' '::text) || COALESCE(public.dd_search_normalize((first_name)::text), ''::text)) || ' '::text) || COALESCE(public.dd_search_normalize((last_name)::text), ''::text)) || ' '::text) || COALESCE(public.dd_search_normalize((doing_business_as)::text), ''::text)))) STORED,
    CONSTRAINT suppliers_kind CHECK (((kind)::text = ANY ((ARRAY['organization'::character varying, 'individual'::character varying])::text[]))),
    CONSTRAINT suppliers_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT suppliers_name_shape CHECK (((((kind)::text = 'organization'::text) AND (display_name IS NOT NULL) AND (btrim((display_name)::text) <> ''::text) AND (first_name IS NULL) AND (last_name IS NULL)) OR (((kind)::text = 'individual'::text) AND (first_name IS NOT NULL) AND (btrim((first_name)::text) <> ''::text) AND (last_name IS NOT NULL) AND (btrim((last_name)::text) <> ''::text) AND (display_name IS NULL) AND (legal_name IS NULL)))),
    CONSTRAINT suppliers_reference_format CHECK (((supplier_reference)::text ~ '^SUP-[0-9]{6}$'::text)),
    CONSTRAINT suppliers_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
);


--
-- Name: agencies agencies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agencies
    ADD CONSTRAINT agencies_pkey PRIMARY KEY (id);


--
-- Name: agency_command_idempotency_keys agency_command_idempotency_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agency_command_idempotency_keys
    ADD CONSTRAINT agency_command_idempotency_keys_pkey PRIMARY KEY (id);


--
-- Name: agency_users agency_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agency_users
    ADD CONSTRAINT agency_users_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: arrangement_item_definitions arrangement_item_definitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arrangement_item_definitions
    ADD CONSTRAINT arrangement_item_definitions_pkey PRIMARY KEY (id);


--
-- Name: arrangement_item_definitions arrangement_item_definitions_position_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arrangement_item_definitions
    ADD CONSTRAINT arrangement_item_definitions_position_unique UNIQUE (supplier_arrangement_version_id, "position") DEFERRABLE INITIALLY DEFERRED;


--
-- Name: arrangement_item_setup_results arrangement_item_setup_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arrangement_item_setup_results
    ADD CONSTRAINT arrangement_item_setup_results_pkey PRIMARY KEY (id);


--
-- Name: arrangement_items arrangement_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arrangement_items
    ADD CONSTRAINT arrangement_items_pkey PRIMARY KEY (id);


--
-- Name: audit_events audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_pkey PRIMARY KEY (id);


--
-- Name: capacity_events capacity_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_events
    ADD CONSTRAINT capacity_events_pkey PRIMARY KEY (id);


--
-- Name: capacity_pair_definitions capacity_pair_definitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pair_definitions
    ADD CONSTRAINT capacity_pair_definitions_pkey PRIMARY KEY (id);


--
-- Name: capacity_pool_definitions capacity_pool_definitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pool_definitions
    ADD CONSTRAINT capacity_pool_definitions_pkey PRIMARY KEY (id);


--
-- Name: capacity_pool_definitions capacity_pool_defs_position_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pool_definitions
    ADD CONSTRAINT capacity_pool_defs_position_unique UNIQUE (supplier_arrangement_version_id, capacity_pair_definition_id, "position") DEFERRABLE INITIALLY DEFERRED;


--
-- Name: capacity_pools capacity_pools_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pools
    ADD CONSTRAINT capacity_pools_pkey PRIMARY KEY (id);


--
-- Name: capacity_projections capacity_projections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_projections
    ADD CONSTRAINT capacity_projections_pkey PRIMARY KEY (id);


--
-- Name: capacity_reconciliation_resolutions capacity_reconciliation_resolutions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_reconciliation_resolutions
    ADD CONSTRAINT capacity_reconciliation_resolutions_pkey PRIMARY KEY (id);


--
-- Name: capacity_reconciliations capacity_reconciliations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_reconciliations
    ADD CONSTRAINT capacity_reconciliations_pkey PRIMARY KEY (id);


--
-- Name: client_organization_contacts client_org_contacts_no_overlapping_history; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_organization_contacts
    ADD CONSTRAINT client_org_contacts_no_overlapping_history EXCLUDE USING gist (agency_id WITH =, client_organization_id WITH =, client_person_id WITH =, daterange(starts_on, COALESCE((ends_on + 1), 'infinity'::date), '[)'::text) WITH &&);


--
-- Name: client_organization_contacts client_organization_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_organization_contacts
    ADD CONSTRAINT client_organization_contacts_pkey PRIMARY KEY (id);


--
-- Name: client_organization_email_addresses client_organization_email_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_organization_email_addresses
    ADD CONSTRAINT client_organization_email_addresses_pkey PRIMARY KEY (id);


--
-- Name: client_organization_phone_numbers client_organization_phone_numbers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_organization_phone_numbers
    ADD CONSTRAINT client_organization_phone_numbers_pkey PRIMARY KEY (id);


--
-- Name: client_organization_postal_addresses client_organization_postal_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_organization_postal_addresses
    ADD CONSTRAINT client_organization_postal_addresses_pkey PRIMARY KEY (id);


--
-- Name: client_organization_websites client_organization_websites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_organization_websites
    ADD CONSTRAINT client_organization_websites_pkey PRIMARY KEY (id);


--
-- Name: client_organizations client_organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_organizations
    ADD CONSTRAINT client_organizations_pkey PRIMARY KEY (id);


--
-- Name: client_people client_people_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_people
    ADD CONSTRAINT client_people_pkey PRIMARY KEY (id);


--
-- Name: client_person_email_addresses client_person_email_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_person_email_addresses
    ADD CONSTRAINT client_person_email_addresses_pkey PRIMARY KEY (id);


--
-- Name: client_person_phone_numbers client_person_phone_numbers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_person_phone_numbers
    ADD CONSTRAINT client_person_phone_numbers_pkey PRIMARY KEY (id);


--
-- Name: client_person_postal_addresses client_person_postal_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_person_postal_addresses
    ADD CONSTRAINT client_person_postal_addresses_pkey PRIMARY KEY (id);


--
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id);


--
-- Name: departures departures_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departures
    ADD CONSTRAINT departures_pkey PRIMARY KEY (id);


--
-- Name: offices offices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offices
    ADD CONSTRAINT offices_pkey PRIMARY KEY (id);


--
-- Name: reference_sequences reference_sequences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reference_sequences
    ADD CONSTRAINT reference_sequences_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: service_occurrence_definitions service_occurrence_definitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_occurrence_definitions
    ADD CONSTRAINT service_occurrence_definitions_pkey PRIMARY KEY (id);


--
-- Name: service_occurrences service_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_occurrences
    ADD CONSTRAINT service_occurrences_pkey PRIMARY KEY (id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: supplier_arrangement_activation_capacity_entries supplier_arrangement_activation_capacity_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangement_activation_capacity_entries
    ADD CONSTRAINT supplier_arrangement_activation_capacity_entries_pkey PRIMARY KEY (id);


--
-- Name: supplier_arrangement_activation_cost_selections supplier_arrangement_activation_cost_selections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangement_activation_cost_selections
    ADD CONSTRAINT supplier_arrangement_activation_cost_selections_pkey PRIMARY KEY (id);


--
-- Name: supplier_arrangement_activations supplier_arrangement_activations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangement_activations
    ADD CONSTRAINT supplier_arrangement_activations_pkey PRIMARY KEY (id);


--
-- Name: supplier_arrangement_versions supplier_arrangement_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangement_versions
    ADD CONSTRAINT supplier_arrangement_versions_pkey PRIMARY KEY (id);


--
-- Name: supplier_arrangements supplier_arrangements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangements
    ADD CONSTRAINT supplier_arrangements_pkey PRIMARY KEY (id);


--
-- Name: supplier_category_assignments supplier_category_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_category_assignments
    ADD CONSTRAINT supplier_category_assignments_pkey PRIMARY KEY (id);


--
-- Name: supplier_commitment_dispositions supplier_commitment_dispositions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_dispositions
    ADD CONSTRAINT supplier_commitment_dispositions_pkey PRIMARY KEY (id);


--
-- Name: supplier_commitment_evidence_coverage_members supplier_commitment_evidence_coverage_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_evidence_coverage_members
    ADD CONSTRAINT supplier_commitment_evidence_coverage_members_pkey PRIMARY KEY (id);


--
-- Name: supplier_commitment_evidence_coverage_revocations supplier_commitment_evidence_coverage_revocations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_evidence_coverage_revocations
    ADD CONSTRAINT supplier_commitment_evidence_coverage_revocations_pkey PRIMARY KEY (id);


--
-- Name: supplier_commitment_evidence_coverages supplier_commitment_evidence_coverages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_evidence_coverages
    ADD CONSTRAINT supplier_commitment_evidence_coverages_pkey PRIMARY KEY (id);


--
-- Name: supplier_commitment_evidence_member_disqualifications supplier_commitment_evidence_member_disqualifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_evidence_member_disqualifications
    ADD CONSTRAINT supplier_commitment_evidence_member_disqualifications_pkey PRIMARY KEY (id);


--
-- Name: supplier_commitment_reopenings supplier_commitment_reopenings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_reopenings
    ADD CONSTRAINT supplier_commitment_reopenings_pkey PRIMARY KEY (id);


--
-- Name: supplier_commitment_trigger_definitions supplier_commitment_trigger_definitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_trigger_definitions
    ADD CONSTRAINT supplier_commitment_trigger_definitions_pkey PRIMARY KEY (id);


--
-- Name: supplier_commitments supplier_commitments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_pkey PRIMARY KEY (id);


--
-- Name: supplier_confirmation_activation_links supplier_confirmation_activation_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_activation_links
    ADD CONSTRAINT supplier_confirmation_activation_links_pkey PRIMARY KEY (id);


--
-- Name: supplier_confirmation_capacity_event_links supplier_confirmation_capacity_event_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_capacity_event_links
    ADD CONSTRAINT supplier_confirmation_capacity_event_links_pkey PRIMARY KEY (id);


--
-- Name: supplier_confirmation_commitment_links supplier_confirmation_commitment_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_commitment_links
    ADD CONSTRAINT supplier_confirmation_commitment_links_pkey PRIMARY KEY (id);


--
-- Name: supplier_confirmation_identifier_links supplier_confirmation_identifier_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_identifier_links
    ADD CONSTRAINT supplier_confirmation_identifier_links_pkey PRIMARY KEY (id);


--
-- Name: supplier_confirmation_reservation_response_links supplier_confirmation_reservation_response_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_reservation_response_links
    ADD CONSTRAINT supplier_confirmation_reservation_response_links_pkey PRIMARY KEY (id);


--
-- Name: supplier_confirmation_reservation_scope_links supplier_confirmation_reservation_scope_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_reservation_scope_links
    ADD CONSTRAINT supplier_confirmation_reservation_scope_links_pkey PRIMARY KEY (id);


--
-- Name: supplier_confirmations supplier_confirmations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmations
    ADD CONSTRAINT supplier_confirmations_pkey PRIMARY KEY (id);


--
-- Name: supplier_contact_email_addresses supplier_contact_email_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_contact_email_addresses
    ADD CONSTRAINT supplier_contact_email_addresses_pkey PRIMARY KEY (id);


--
-- Name: supplier_contact_phone_numbers supplier_contact_phone_numbers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_contact_phone_numbers
    ADD CONSTRAINT supplier_contact_phone_numbers_pkey PRIMARY KEY (id);


--
-- Name: supplier_contacts supplier_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_contacts
    ADD CONSTRAINT supplier_contacts_pkey PRIMARY KEY (id);


--
-- Name: supplier_cost_participant_categories supplier_cost_categories_position_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_participant_categories
    ADD CONSTRAINT supplier_cost_categories_position_unique UNIQUE (supplier_arrangement_version_id, arrangement_item_id, "position") DEFERRABLE INITIALLY DEFERRED;


--
-- Name: supplier_cost_component_bases supplier_cost_component_bases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_component_bases
    ADD CONSTRAINT supplier_cost_component_bases_pkey PRIMARY KEY (id);


--
-- Name: supplier_cost_components supplier_cost_components_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_components
    ADD CONSTRAINT supplier_cost_components_pkey PRIMARY KEY (id);


--
-- Name: supplier_cost_definitions supplier_cost_definitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_definitions
    ADD CONSTRAINT supplier_cost_definitions_pkey PRIMARY KEY (id);


--
-- Name: supplier_cost_occupancy_profile_positions supplier_cost_occupancy_profile_positions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_occupancy_profile_positions
    ADD CONSTRAINT supplier_cost_occupancy_profile_positions_pkey PRIMARY KEY (id);


--
-- Name: supplier_cost_occupancy_profiles supplier_cost_occupancy_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_occupancy_profiles
    ADD CONSTRAINT supplier_cost_occupancy_profiles_pkey PRIMARY KEY (id);


--
-- Name: supplier_cost_participant_categories supplier_cost_participant_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_participant_categories
    ADD CONSTRAINT supplier_cost_participant_categories_pkey PRIMARY KEY (id);


--
-- Name: supplier_cost_occupancy_profiles supplier_cost_profiles_position_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_occupancy_profiles
    ADD CONSTRAINT supplier_cost_profiles_position_unique UNIQUE (supplier_cost_usage_assumption_id, "position") DEFERRABLE INITIALLY DEFERRED;


--
-- Name: supplier_cost_sources supplier_cost_sources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_sources
    ADD CONSTRAINT supplier_cost_sources_pkey PRIMARY KEY (id);


--
-- Name: supplier_cost_sources supplier_cost_sources_position_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_sources
    ADD CONSTRAINT supplier_cost_sources_position_unique UNIQUE NULLS NOT DISTINCT (supplier_arrangement_version_id, arrangement_item_id, "position") DEFERRABLE INITIALLY DEFERRED;


--
-- Name: supplier_cost_usage_assumptions supplier_cost_usage_assumptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_usage_assumptions
    ADD CONSTRAINT supplier_cost_usage_assumptions_pkey PRIMARY KEY (id);


--
-- Name: supplier_deadline_commitment_definition_lines supplier_deadline_commitment_definition_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_commitment_definition_lines
    ADD CONSTRAINT supplier_deadline_commitment_definition_lines_pkey PRIMARY KEY (id);


--
-- Name: supplier_deadline_definition_coverage_links supplier_deadline_definition_coverage_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_definition_coverage_links
    ADD CONSTRAINT supplier_deadline_definition_coverage_links_pkey PRIMARY KEY (id);


--
-- Name: supplier_deadline_definitions supplier_deadline_definitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_definitions
    ADD CONSTRAINT supplier_deadline_definitions_pkey PRIMARY KEY (id);


--
-- Name: supplier_deadline_occurrences supplier_deadline_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_occurrences
    ADD CONSTRAINT supplier_deadline_occurrences_pkey PRIMARY KEY (id);


--
-- Name: supplier_deadline_projections supplier_deadline_projections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_projections
    ADD CONSTRAINT supplier_deadline_projections_pkey PRIMARY KEY (id);


--
-- Name: supplier_email_addresses supplier_email_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_email_addresses
    ADD CONSTRAINT supplier_email_addresses_pkey PRIMARY KEY (id);


--
-- Name: supplier_issued_identifiers supplier_issued_identifiers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_issued_identifiers
    ADD CONSTRAINT supplier_issued_identifiers_pkey PRIMARY KEY (id);


--
-- Name: supplier_locations supplier_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_locations
    ADD CONSTRAINT supplier_locations_pkey PRIMARY KEY (id);


--
-- Name: supplier_phone_numbers supplier_phone_numbers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_phone_numbers
    ADD CONSTRAINT supplier_phone_numbers_pkey PRIMARY KEY (id);


--
-- Name: supplier_postal_addresses supplier_postal_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_postal_addresses
    ADD CONSTRAINT supplier_postal_addresses_pkey PRIMARY KEY (id);


--
-- Name: supplier_reservation_event_scope_outcomes supplier_reservation_event_scope_outcomes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_event_scope_outcomes
    ADD CONSTRAINT supplier_reservation_event_scope_outcomes_pkey PRIMARY KEY (id);


--
-- Name: supplier_reservation_events supplier_reservation_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_events
    ADD CONSTRAINT supplier_reservation_events_pkey PRIMARY KEY (id);


--
-- Name: supplier_reservation_projections supplier_reservation_projections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_projections
    ADD CONSTRAINT supplier_reservation_projections_pkey PRIMARY KEY (id);


--
-- Name: supplier_reservation_revisions supplier_reservation_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_revisions
    ADD CONSTRAINT supplier_reservation_revisions_pkey PRIMARY KEY (id);


--
-- Name: supplier_reservation_scopes supplier_reservation_scopes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_scopes
    ADD CONSTRAINT supplier_reservation_scopes_pkey PRIMARY KEY (id);


--
-- Name: supplier_reservations supplier_reservations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservations
    ADD CONSTRAINT supplier_reservations_pkey PRIMARY KEY (id);


--
-- Name: supplier_resource_definitions supplier_resource_definitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_resource_definitions
    ADD CONSTRAINT supplier_resource_definitions_pkey PRIMARY KEY (id);


--
-- Name: supplier_resource_definitions supplier_resource_definitions_position_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_resource_definitions
    ADD CONSTRAINT supplier_resource_definitions_position_unique UNIQUE (supplier_arrangement_version_id, arrangement_item_id, "position") DEFERRABLE INITIALLY DEFERRED;


--
-- Name: supplier_resources supplier_resources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_resources
    ADD CONSTRAINT supplier_resources_pkey PRIMARY KEY (id);


--
-- Name: supplier_websites supplier_websites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_websites
    ADD CONSTRAINT supplier_websites_pkey PRIMARY KEY (id);


--
-- Name: suppliers suppliers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suppliers
    ADD CONSTRAINT suppliers_pkey PRIMARY KEY (id);


--
-- Name: capacity_pairs_copied_from_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX capacity_pairs_copied_from_idx ON public.capacity_pair_definitions USING btree (copied_from_id);


--
-- Name: capacity_pairs_lineage_owner_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX capacity_pairs_lineage_owner_idx ON public.capacity_pair_definitions USING btree (id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: capacity_pool_defs_copied_from_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX capacity_pool_defs_copied_from_idx ON public.capacity_pool_definitions USING btree (copied_from_id);


--
-- Name: capacity_pool_defs_lineage_owner_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX capacity_pool_defs_lineage_owner_idx ON public.capacity_pool_definitions USING btree (id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: idx_on_agency_id_272858808f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_agency_id_272858808f ON public.supplier_confirmation_reservation_response_links USING btree (agency_id);


--
-- Name: idx_on_agency_id_47e72d1a5f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_agency_id_47e72d1a5f ON public.supplier_arrangement_activation_cost_selections USING btree (agency_id);


--
-- Name: idx_on_agency_id_751f094529; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_agency_id_751f094529 ON public.supplier_confirmation_reservation_scope_links USING btree (agency_id);


--
-- Name: idx_on_agency_id_be0266867f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_agency_id_be0266867f ON public.supplier_arrangement_activation_capacity_entries USING btree (agency_id);


--
-- Name: index_activation_capacity_entries_on_activation_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_activation_capacity_entries_on_activation_entry ON public.supplier_arrangement_activation_capacity_entries USING btree (supplier_arrangement_activation_id, capacity_pool_definition_id);


--
-- Name: index_activation_capacity_entries_on_id_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_activation_capacity_entries_on_id_agency ON public.supplier_arrangement_activation_capacity_entries USING btree (id, agency_id);


--
-- Name: index_activation_capacity_entries_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_activation_capacity_entries_on_id_departure_agency ON public.supplier_arrangement_activation_capacity_entries USING btree (id, departure_id, agency_id);


--
-- Name: index_activation_capacity_entries_on_version_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_activation_capacity_entries_on_version_owner ON public.supplier_arrangement_activation_capacity_entries USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_activation_cost_selections_on_activation_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_activation_cost_selections_on_activation_entry ON public.supplier_arrangement_activation_cost_selections USING btree (supplier_arrangement_activation_id, supplier_cost_source_id);


--
-- Name: index_activation_cost_selections_on_id_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_activation_cost_selections_on_id_agency ON public.supplier_arrangement_activation_cost_selections USING btree (id, agency_id);


--
-- Name: index_activation_cost_selections_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_activation_cost_selections_on_id_departure_agency ON public.supplier_arrangement_activation_cost_selections USING btree (id, departure_id, agency_id);


--
-- Name: index_activation_cost_selections_on_version_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_activation_cost_selections_on_version_owner ON public.supplier_arrangement_activation_cost_selections USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_agencies_on_workspace_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agencies_on_workspace_code ON public.agencies USING btree (workspace_code);


--
-- Name: index_agency_command_idempotency_keys_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agency_command_idempotency_keys_on_agency_id ON public.agency_command_idempotency_keys USING btree (agency_id);


--
-- Name: index_agency_users_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agency_users_on_agency_id ON public.agency_users USING btree (agency_id);


--
-- Name: index_agency_users_on_agency_id_and_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agency_users_on_agency_id_and_email ON public.agency_users USING btree (agency_id, email_address);


--
-- Name: index_agency_users_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agency_users_on_id_and_agency_id ON public.agency_users USING btree (id, agency_id);


--
-- Name: index_agency_users_on_invitation_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agency_users_on_invitation_token_digest ON public.agency_users USING btree (invitation_token_digest) WHERE (invitation_token_digest IS NOT NULL);


--
-- Name: index_agency_users_on_password_reset_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agency_users_on_password_reset_token_digest ON public.agency_users USING btree (password_reset_token_digest) WHERE (password_reset_token_digest IS NOT NULL);


--
-- Name: index_arrangement_activations_on_departure_history; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_arrangement_activations_on_departure_history ON public.supplier_arrangement_activations USING btree (agency_id, departure_id, supplier_arrangement_id, activated_at);


--
-- Name: index_arrangement_activations_on_departure_latch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_arrangement_activations_on_departure_latch ON public.supplier_arrangement_activations USING btree (agency_id, departure_id);


--
-- Name: index_arrangement_activations_on_id_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_arrangement_activations_on_id_agency ON public.supplier_arrangement_activations USING btree (id, agency_id);


--
-- Name: index_arrangement_activations_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_arrangement_activations_on_id_departure_agency ON public.supplier_arrangement_activations USING btree (id, departure_id, agency_id);


--
-- Name: index_arrangement_activations_on_version; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_arrangement_activations_on_version ON public.supplier_arrangement_activations USING btree (supplier_arrangement_version_id);


--
-- Name: index_arrangement_activations_on_version_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_arrangement_activations_on_version_owner ON public.supplier_arrangement_activations USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_arrangement_item_definitions_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_arrangement_item_definitions_on_agency_id ON public.arrangement_item_definitions USING btree (agency_id);


--
-- Name: index_arrangement_item_definitions_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_arrangement_item_definitions_on_id_and_agency_id ON public.arrangement_item_definitions USING btree (id, agency_id);


--
-- Name: index_arrangement_item_definitions_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_arrangement_item_definitions_on_id_departure_agency ON public.arrangement_item_definitions USING btree (id, departure_id, agency_id);


--
-- Name: index_arrangement_item_definitions_on_version_and_stable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_arrangement_item_definitions_on_version_and_stable_id ON public.arrangement_item_definitions USING btree (supplier_arrangement_version_id, arrangement_item_id);


--
-- Name: index_arrangement_item_setup_results_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_arrangement_item_setup_results_on_agency_id ON public.arrangement_item_setup_results USING btree (agency_id);


--
-- Name: index_arrangement_item_setup_results_on_arrangement_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_arrangement_item_setup_results_on_arrangement_item_id ON public.arrangement_item_setup_results USING btree (arrangement_item_id);


--
-- Name: index_arrangement_item_setup_results_on_service_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_arrangement_item_setup_results_on_service_occurrence_id ON public.arrangement_item_setup_results USING btree (service_occurrence_id);


--
-- Name: index_arrangement_item_setup_results_on_supplier_resource_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_arrangement_item_setup_results_on_supplier_resource_id ON public.arrangement_item_setup_results USING btree (supplier_resource_id);


--
-- Name: index_arrangement_items_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_arrangement_items_on_agency_id ON public.arrangement_items USING btree (agency_id);


--
-- Name: index_arrangement_items_on_full_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_arrangement_items_on_full_owner ON public.arrangement_items USING btree (id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_arrangement_items_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_arrangement_items_on_id_and_agency_id ON public.arrangement_items USING btree (id, agency_id);


--
-- Name: index_arrangement_items_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_arrangement_items_on_id_departure_agency ON public.arrangement_items USING btree (id, departure_id, agency_id);


--
-- Name: index_arrangement_versions_on_lineage_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_arrangement_versions_on_lineage_owner ON public.supplier_arrangement_versions USING btree (id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_audit_events_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_agency_id ON public.audit_events USING btree (agency_id);


--
-- Name: index_audit_events_on_agency_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_agency_id_and_created_at ON public.audit_events USING btree (agency_id, created_at);


--
-- Name: index_capacity_events_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_capacity_events_on_agency_id ON public.capacity_events USING btree (agency_id);


--
-- Name: index_capacity_events_on_applicability; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_capacity_events_on_applicability ON public.capacity_events USING btree (capacity_pool_id, applies_at, effective_on, effective_sequence);


--
-- Name: index_capacity_events_on_applies_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_capacity_events_on_applies_at ON public.capacity_events USING btree (applies_at, capacity_pool_id);


--
-- Name: index_capacity_events_on_business_replay_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_capacity_events_on_business_replay_order ON public.capacity_events USING btree (capacity_pool_id, effective_on, effective_sequence, recorded_at, id);


--
-- Name: index_capacity_events_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_events_on_id_and_agency_id ON public.capacity_events USING btree (id, agency_id);


--
-- Name: index_capacity_events_on_id_pool_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_events_on_id_pool_agency ON public.capacity_events USING btree (id, capacity_pool_id, agency_id);


--
-- Name: index_capacity_events_on_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_capacity_events_on_idempotency_key ON public.capacity_events USING btree (agency_command_idempotency_key_id) WHERE (agency_command_idempotency_key_id IS NOT NULL);


--
-- Name: index_capacity_events_on_pool_date_sequence; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_events_on_pool_date_sequence ON public.capacity_events USING btree (capacity_pool_id, effective_on, effective_sequence);


--
-- Name: index_capacity_events_on_version_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_events_on_version_owner ON public.capacity_events USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_capacity_events_one_established_per_pool; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_events_one_established_per_pool ON public.capacity_events USING btree (capacity_pool_id) WHERE ((event_type)::text = 'established'::text);


--
-- Name: index_capacity_pair_definitions_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_capacity_pair_definitions_on_agency_id ON public.capacity_pair_definitions USING btree (agency_id);


--
-- Name: index_capacity_pairs_on_full_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_pairs_on_full_owner ON public.capacity_pair_definitions USING btree (id, service_occurrence_id, supplier_resource_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_capacity_pairs_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_pairs_on_id_and_agency_id ON public.capacity_pair_definitions USING btree (id, agency_id);


--
-- Name: index_capacity_pairs_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_pairs_on_id_departure_agency ON public.capacity_pair_definitions USING btree (id, departure_id, agency_id);


--
-- Name: index_capacity_pairs_on_item_coverage; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_capacity_pairs_on_item_coverage ON public.capacity_pair_definitions USING btree (supplier_arrangement_version_id, arrangement_item_id, service_occurrence_id, supplier_resource_id);


--
-- Name: index_capacity_pairs_on_version_occurrence_resource; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_pairs_on_version_occurrence_resource ON public.capacity_pair_definitions USING btree (supplier_arrangement_version_id, service_occurrence_id, supplier_resource_id);


--
-- Name: index_capacity_pool_definitions_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_capacity_pool_definitions_on_agency_id ON public.capacity_pool_definitions USING btree (agency_id);


--
-- Name: index_capacity_pool_defs_on_activation_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_pool_defs_on_activation_owner ON public.capacity_pool_definitions USING btree (id, capacity_pool_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_capacity_pool_defs_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_pool_defs_on_id_and_agency_id ON public.capacity_pool_definitions USING btree (id, agency_id);


--
-- Name: index_capacity_pool_defs_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_pool_defs_on_id_departure_agency ON public.capacity_pool_definitions USING btree (id, departure_id, agency_id);


--
-- Name: index_capacity_pool_defs_on_pool_and_version; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_pool_defs_on_pool_and_version ON public.capacity_pool_definitions USING btree (capacity_pool_id, supplier_arrangement_version_id);


--
-- Name: index_capacity_pool_defs_on_position_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_capacity_pool_defs_on_position_lookup ON public.capacity_pool_definitions USING btree (supplier_arrangement_version_id, capacity_pair_definition_id, "position");


--
-- Name: index_capacity_pool_defs_on_unique_label; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_pool_defs_on_unique_label ON public.capacity_pool_definitions USING btree (supplier_arrangement_version_id, capacity_pair_definition_id, normalized_label);


--
-- Name: index_capacity_pools_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_capacity_pools_on_agency_id ON public.capacity_pools USING btree (agency_id);


--
-- Name: index_capacity_pools_on_full_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_pools_on_full_owner ON public.capacity_pools USING btree (id, service_occurrence_id, supplier_resource_id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_capacity_pools_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_pools_on_id_and_agency_id ON public.capacity_pools USING btree (id, agency_id);


--
-- Name: index_capacity_pools_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_pools_on_id_departure_agency ON public.capacity_pools USING btree (id, departure_id, agency_id);


--
-- Name: index_capacity_pools_on_pair_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_capacity_pools_on_pair_lookup ON public.capacity_pools USING btree (supplier_arrangement_id, arrangement_item_id, service_occurrence_id, supplier_resource_id);


--
-- Name: index_capacity_pools_on_supplier_dependency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_capacity_pools_on_supplier_dependency ON public.capacity_pools USING btree (agency_id, supplying_supplier_id, id);


--
-- Name: index_capacity_projections_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_capacity_projections_on_agency_id ON public.capacity_projections USING btree (agency_id);


--
-- Name: index_capacity_projections_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_projections_on_id_and_agency_id ON public.capacity_projections USING btree (id, agency_id);


--
-- Name: index_capacity_projections_on_next_applies_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_capacity_projections_on_next_applies_at ON public.capacity_projections USING btree (next_applies_at, capacity_pool_id) WHERE (next_applies_at IS NOT NULL);


--
-- Name: index_capacity_projections_on_pool; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_projections_on_pool ON public.capacity_projections USING btree (capacity_pool_id);


--
-- Name: index_capacity_recon_resolutions_on_history; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_capacity_recon_resolutions_on_history ON public.capacity_reconciliation_resolutions USING btree (capacity_pool_id, capacity_reconciliation_id, resolved_at, id);


--
-- Name: index_capacity_recon_resolutions_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_recon_resolutions_on_id_and_agency_id ON public.capacity_reconciliation_resolutions USING btree (id, agency_id);


--
-- Name: index_capacity_recon_resolutions_on_recon_event; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_recon_resolutions_on_recon_event ON public.capacity_reconciliation_resolutions USING btree (capacity_reconciliation_id, capacity_event_id);


--
-- Name: index_capacity_reconciliation_resolutions_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_capacity_reconciliation_resolutions_on_agency_id ON public.capacity_reconciliation_resolutions USING btree (agency_id);


--
-- Name: index_capacity_reconciliations_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_capacity_reconciliations_on_agency_id ON public.capacity_reconciliations USING btree (agency_id);


--
-- Name: index_capacity_reconciliations_on_discrepancy; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_capacity_reconciliations_on_discrepancy ON public.capacity_reconciliations USING btree (capacity_pool_id, id) WHERE (variance <> 0);


--
-- Name: index_capacity_reconciliations_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_reconciliations_on_id_and_agency_id ON public.capacity_reconciliations USING btree (id, agency_id);


--
-- Name: index_capacity_reconciliations_on_id_pool_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_reconciliations_on_id_pool_agency ON public.capacity_reconciliations USING btree (id, capacity_pool_id, agency_id);


--
-- Name: index_capacity_reconciliations_on_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_reconciliations_on_idempotency_key ON public.capacity_reconciliations USING btree (agency_command_idempotency_key_id) WHERE (agency_command_idempotency_key_id IS NOT NULL);


--
-- Name: index_capacity_reconciliations_on_pool_observed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_capacity_reconciliations_on_pool_observed ON public.capacity_reconciliations USING btree (capacity_pool_id, observed_at, id);


--
-- Name: index_client_org_contacts_on_organization_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_org_contacts_on_organization_and_agency ON public.client_organization_contacts USING btree (client_organization_id, agency_id);


--
-- Name: index_client_org_contacts_on_person_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_org_contacts_on_person_and_agency ON public.client_organization_contacts USING btree (client_person_id, agency_id);


--
-- Name: index_client_org_contacts_one_current_pair; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_org_contacts_one_current_pair ON public.client_organization_contacts USING btree (agency_id, client_organization_id, client_person_id) WHERE (ends_on IS NULL);


--
-- Name: index_client_org_contacts_one_current_primary; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_org_contacts_one_current_primary ON public.client_organization_contacts USING btree (agency_id, client_organization_id) WHERE ((ends_on IS NULL) AND "primary");


--
-- Name: index_client_org_email_addresses_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_org_email_addresses_on_id_and_agency_id ON public.client_organization_email_addresses USING btree (id, agency_id);


--
-- Name: index_client_org_email_addresses_on_one_preferred_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_org_email_addresses_on_one_preferred_active ON public.client_organization_email_addresses USING btree (agency_id, client_organization_id) WHERE (preferred AND ((status)::text = 'active'::text));


--
-- Name: index_client_org_email_addresses_on_organization_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_org_email_addresses_on_organization_and_agency ON public.client_organization_email_addresses USING btree (client_organization_id, agency_id);


--
-- Name: index_client_org_emails_on_agency_and_normalized; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_org_emails_on_agency_and_normalized ON public.client_organization_email_addresses USING btree (agency_id, normalized_address);


--
-- Name: index_client_org_phone_numbers_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_org_phone_numbers_on_id_and_agency_id ON public.client_organization_phone_numbers USING btree (id, agency_id);


--
-- Name: index_client_org_phone_numbers_on_one_preferred_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_org_phone_numbers_on_one_preferred_active ON public.client_organization_phone_numbers USING btree (agency_id, client_organization_id) WHERE (preferred AND ((status)::text = 'active'::text));


--
-- Name: index_client_org_phone_numbers_on_organization_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_org_phone_numbers_on_organization_and_agency ON public.client_organization_phone_numbers USING btree (client_organization_id, agency_id);


--
-- Name: index_client_org_phones_on_agency_and_e164; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_org_phones_on_agency_and_e164 ON public.client_organization_phone_numbers USING btree (agency_id, normalized_number);


--
-- Name: index_client_org_phones_on_agency_and_reversed_digits; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_org_phones_on_agency_and_reversed_digits ON public.client_organization_phone_numbers USING btree (agency_id, phone_digits_reversed text_pattern_ops);


--
-- Name: index_client_org_postal_addresses_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_org_postal_addresses_on_id_and_agency_id ON public.client_organization_postal_addresses USING btree (id, agency_id);


--
-- Name: index_client_org_postal_addresses_on_one_preferred_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_org_postal_addresses_on_one_preferred_active ON public.client_organization_postal_addresses USING btree (agency_id, client_organization_id) WHERE (preferred AND ((status)::text = 'active'::text));


--
-- Name: index_client_org_postal_addresses_on_organization_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_org_postal_addresses_on_organization_and_agency ON public.client_organization_postal_addresses USING btree (client_organization_id, agency_id);


--
-- Name: index_client_org_postals_on_agency_and_locality; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_org_postals_on_agency_and_locality ON public.client_organization_postal_addresses USING btree (agency_id, locality_search_key text_pattern_ops);


--
-- Name: index_client_org_postals_on_agency_and_postal_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_org_postals_on_agency_and_postal_code ON public.client_organization_postal_addresses USING btree (agency_id, postal_code_search_key);


--
-- Name: index_client_org_websites_on_agency_and_host; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_org_websites_on_agency_and_host ON public.client_organization_websites USING btree (agency_id, normalized_host);


--
-- Name: index_client_org_websites_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_org_websites_on_id_and_agency_id ON public.client_organization_websites USING btree (id, agency_id);


--
-- Name: index_client_org_websites_on_one_preferred_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_org_websites_on_one_preferred_active ON public.client_organization_websites USING btree (agency_id, client_organization_id) WHERE (preferred AND ((status)::text = 'active'::text));


--
-- Name: index_client_org_websites_on_organization_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_org_websites_on_organization_and_agency ON public.client_organization_websites USING btree (client_organization_id, agency_id);


--
-- Name: index_client_organization_contacts_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_organization_contacts_on_agency_id ON public.client_organization_contacts USING btree (agency_id);


--
-- Name: index_client_organization_contacts_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_organization_contacts_on_id_and_agency_id ON public.client_organization_contacts USING btree (id, agency_id);


--
-- Name: index_client_organization_email_addresses_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_organization_email_addresses_on_agency_id ON public.client_organization_email_addresses USING btree (agency_id);


--
-- Name: index_client_organization_phone_numbers_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_organization_phone_numbers_on_agency_id ON public.client_organization_phone_numbers USING btree (agency_id);


--
-- Name: index_client_organization_postal_addresses_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_organization_postal_addresses_on_agency_id ON public.client_organization_postal_addresses USING btree (agency_id);


--
-- Name: index_client_organization_websites_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_organization_websites_on_agency_id ON public.client_organization_websites USING btree (agency_id);


--
-- Name: index_client_organizations_on_agency_and_display_name_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_organizations_on_agency_and_display_name_key ON public.client_organizations USING btree (agency_id, display_name_search_key);


--
-- Name: index_client_organizations_on_agency_and_legal_name_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_organizations_on_agency_and_legal_name_key ON public.client_organizations USING btree (agency_id, legal_name_search_key);


--
-- Name: index_client_organizations_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_organizations_on_agency_id ON public.client_organizations USING btree (agency_id);


--
-- Name: index_client_organizations_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_organizations_on_id_and_agency_id ON public.client_organizations USING btree (id, agency_id);


--
-- Name: index_client_organizations_on_name_search_vector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_organizations_on_name_search_vector ON public.client_organizations USING gin (name_search_vector);


--
-- Name: index_client_people_on_agency_and_name_search_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_people_on_agency_and_name_search_key ON public.client_people USING btree (agency_id, name_search_key);


--
-- Name: index_client_people_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_people_on_agency_id ON public.client_people USING btree (agency_id);


--
-- Name: index_client_people_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_people_on_id_and_agency_id ON public.client_people USING btree (id, agency_id);


--
-- Name: index_client_people_on_name_search_vector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_people_on_name_search_vector ON public.client_people USING gin (name_search_vector);


--
-- Name: index_client_person_email_addresses_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_person_email_addresses_on_agency_id ON public.client_person_email_addresses USING btree (agency_id);


--
-- Name: index_client_person_email_addresses_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_person_email_addresses_on_id_and_agency_id ON public.client_person_email_addresses USING btree (id, agency_id);


--
-- Name: index_client_person_email_addresses_on_one_preferred_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_person_email_addresses_on_one_preferred_active ON public.client_person_email_addresses USING btree (agency_id, client_person_id) WHERE (preferred AND ((status)::text = 'active'::text));


--
-- Name: index_client_person_email_addresses_on_person_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_person_email_addresses_on_person_and_agency ON public.client_person_email_addresses USING btree (client_person_id, agency_id);


--
-- Name: index_client_person_emails_on_agency_and_normalized; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_person_emails_on_agency_and_normalized ON public.client_person_email_addresses USING btree (agency_id, normalized_address);


--
-- Name: index_client_person_phone_numbers_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_person_phone_numbers_on_agency_id ON public.client_person_phone_numbers USING btree (agency_id);


--
-- Name: index_client_person_phone_numbers_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_person_phone_numbers_on_id_and_agency_id ON public.client_person_phone_numbers USING btree (id, agency_id);


--
-- Name: index_client_person_phone_numbers_on_one_preferred_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_person_phone_numbers_on_one_preferred_active ON public.client_person_phone_numbers USING btree (agency_id, client_person_id) WHERE (preferred AND ((status)::text = 'active'::text));


--
-- Name: index_client_person_phone_numbers_on_person_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_person_phone_numbers_on_person_and_agency ON public.client_person_phone_numbers USING btree (client_person_id, agency_id);


--
-- Name: index_client_person_phones_on_agency_and_e164; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_person_phones_on_agency_and_e164 ON public.client_person_phone_numbers USING btree (agency_id, normalized_number);


--
-- Name: index_client_person_phones_on_agency_and_reversed_digits; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_person_phones_on_agency_and_reversed_digits ON public.client_person_phone_numbers USING btree (agency_id, phone_digits_reversed text_pattern_ops);


--
-- Name: index_client_person_postal_addresses_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_person_postal_addresses_on_agency_id ON public.client_person_postal_addresses USING btree (agency_id);


--
-- Name: index_client_person_postal_addresses_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_person_postal_addresses_on_id_and_agency_id ON public.client_person_postal_addresses USING btree (id, agency_id);


--
-- Name: index_client_person_postal_addresses_on_one_preferred_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_person_postal_addresses_on_one_preferred_active ON public.client_person_postal_addresses USING btree (agency_id, client_person_id) WHERE (preferred AND ((status)::text = 'active'::text));


--
-- Name: index_client_person_postal_addresses_on_person_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_person_postal_addresses_on_person_and_agency ON public.client_person_postal_addresses USING btree (client_person_id, agency_id);


--
-- Name: index_client_person_postals_on_agency_and_locality; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_person_postals_on_agency_and_locality ON public.client_person_postal_addresses USING btree (agency_id, locality_search_key text_pattern_ops);


--
-- Name: index_client_person_postals_on_agency_and_postal_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_person_postals_on_agency_and_postal_code ON public.client_person_postal_addresses USING btree (agency_id, postal_code_search_key);


--
-- Name: index_clients_on_agency_and_reference; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_clients_on_agency_and_reference ON public.clients USING btree (agency_id, client_reference);


--
-- Name: index_clients_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_agency_id ON public.clients USING btree (agency_id);


--
-- Name: index_clients_on_client_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_clients_on_client_organization_id ON public.clients USING btree (client_organization_id) WHERE (client_organization_id IS NOT NULL);


--
-- Name: index_clients_on_client_person_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_clients_on_client_person_id ON public.clients USING btree (client_person_id);


--
-- Name: index_clients_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_clients_on_id_and_agency_id ON public.clients USING btree (id, agency_id);


--
-- Name: index_cmt_disp_on_id_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cmt_disp_on_id_agency ON public.supplier_commitment_dispositions USING btree (id, agency_id);


--
-- Name: index_cmt_disp_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cmt_disp_on_id_departure_agency ON public.supplier_commitment_dispositions USING btree (id, departure_id, agency_id);


--
-- Name: index_cmt_ev_cov_on_id_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cmt_ev_cov_on_id_agency ON public.supplier_commitment_evidence_coverages USING btree (id, agency_id);


--
-- Name: index_cmt_ev_cov_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cmt_ev_cov_on_id_departure_agency ON public.supplier_commitment_evidence_coverages USING btree (id, departure_id, agency_id);


--
-- Name: index_cmt_ev_disq_on_id_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cmt_ev_disq_on_id_agency ON public.supplier_commitment_evidence_member_disqualifications USING btree (id, agency_id);


--
-- Name: index_cmt_ev_disq_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cmt_ev_disq_on_id_departure_agency ON public.supplier_commitment_evidence_member_disqualifications USING btree (id, departure_id, agency_id);


--
-- Name: index_cmt_ev_mem_on_id_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cmt_ev_mem_on_id_agency ON public.supplier_commitment_evidence_coverage_members USING btree (id, agency_id);


--
-- Name: index_cmt_ev_mem_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cmt_ev_mem_on_id_departure_agency ON public.supplier_commitment_evidence_coverage_members USING btree (id, departure_id, agency_id);


--
-- Name: index_cmt_ev_rev_on_id_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cmt_ev_rev_on_id_agency ON public.supplier_commitment_evidence_coverage_revocations USING btree (id, agency_id);


--
-- Name: index_cmt_ev_rev_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cmt_ev_rev_on_id_departure_agency ON public.supplier_commitment_evidence_coverage_revocations USING btree (id, departure_id, agency_id);


--
-- Name: index_cmt_reopen_on_id_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cmt_reopen_on_id_agency ON public.supplier_commitment_reopenings USING btree (id, agency_id);


--
-- Name: index_cmt_reopen_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cmt_reopen_on_id_departure_agency ON public.supplier_commitment_reopenings USING btree (id, departure_id, agency_id);


--
-- Name: index_command_idempotency_on_agency_command_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_command_idempotency_on_agency_command_key ON public.agency_command_idempotency_keys USING btree (agency_id, command_name, idempotency_key);


--
-- Name: index_commitment_dispositions_on_commitment_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commitment_dispositions_on_commitment_owner ON public.supplier_commitment_dispositions USING btree (id, supplier_commitment_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_commitment_dispositions_on_commitment_timeline; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_commitment_dispositions_on_commitment_timeline ON public.supplier_commitment_dispositions USING btree (supplier_commitment_id, recorded_at, id);


--
-- Name: index_commitment_dispositions_on_coverage_member_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commitment_dispositions_on_coverage_member_owner ON public.supplier_commitment_dispositions USING btree (id, supplier_commitment_evidence_coverage_id, supplier_commitment_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_commitment_dispositions_on_version_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commitment_dispositions_on_version_owner ON public.supplier_commitment_dispositions USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_commitment_evidence_coverages_on_version_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commitment_evidence_coverages_on_version_owner ON public.supplier_commitment_evidence_coverages USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_commitment_evidence_disqualifications_on_coverage_member; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commitment_evidence_disqualifications_on_coverage_member ON public.supplier_commitment_evidence_member_disqualifications USING btree (supplier_commitment_evidence_coverage_id, supplier_commitment_id);


--
-- Name: index_commitment_evidence_disqualifications_on_disposition; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commitment_evidence_disqualifications_on_disposition ON public.supplier_commitment_evidence_member_disqualifications USING btree (supplier_commitment_disposition_id);


--
-- Name: index_commitment_evidence_disqualifications_on_reopening; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commitment_evidence_disqualifications_on_reopening ON public.supplier_commitment_evidence_member_disqualifications USING btree (supplier_commitment_reopening_id);


--
-- Name: index_commitment_evidence_disqualifications_on_version_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commitment_evidence_disqualifications_on_version_owner ON public.supplier_commitment_evidence_member_disqualifications USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_commitment_evidence_members_on_coverage_commitment; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commitment_evidence_members_on_coverage_commitment ON public.supplier_commitment_evidence_coverage_members USING btree (supplier_commitment_evidence_coverage_id, supplier_commitment_id);


--
-- Name: index_commitment_evidence_members_on_coverage_commitment_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commitment_evidence_members_on_coverage_commitment_owner ON public.supplier_commitment_evidence_coverage_members USING btree (supplier_commitment_evidence_coverage_id, supplier_commitment_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_commitment_evidence_members_on_version_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commitment_evidence_members_on_version_owner ON public.supplier_commitment_evidence_coverage_members USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_commitment_evidence_revocations_on_coverage; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commitment_evidence_revocations_on_coverage ON public.supplier_commitment_evidence_coverage_revocations USING btree (supplier_commitment_evidence_coverage_id);


--
-- Name: index_commitment_evidence_revocations_on_version_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commitment_evidence_revocations_on_version_owner ON public.supplier_commitment_evidence_coverage_revocations USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_commitment_reopenings_on_disposition; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commitment_reopenings_on_disposition ON public.supplier_commitment_reopenings USING btree (supplier_commitment_disposition_id);


--
-- Name: index_commitment_reopenings_on_disposition_commitment_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commitment_reopenings_on_disposition_commitment_owner ON public.supplier_commitment_reopenings USING btree (id, supplier_commitment_disposition_id, supplier_commitment_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_commitment_reopenings_on_version_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commitment_reopenings_on_version_owner ON public.supplier_commitment_reopenings USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_commitment_triggers_on_full_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commitment_triggers_on_full_owner ON public.supplier_commitment_trigger_definitions USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_commitment_triggers_on_id_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commitment_triggers_on_id_agency ON public.supplier_commitment_trigger_definitions USING btree (id, agency_id);


--
-- Name: index_commitment_triggers_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commitment_triggers_on_id_departure_agency ON public.supplier_commitment_trigger_definitions USING btree (id, departure_id, agency_id);


--
-- Name: index_commitment_triggers_on_lineage_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commitment_triggers_on_lineage_owner ON public.supplier_commitment_trigger_definitions USING btree (id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_commitment_triggers_on_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commitment_triggers_on_position ON public.supplier_commitment_trigger_definitions USING btree (supplier_arrangement_version_id, "position");


--
-- Name: index_commitment_triggers_on_version_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commitment_triggers_on_version_owner ON public.supplier_commitment_trigger_definitions USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_confirmation_activation_links_on_id_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_confirmation_activation_links_on_id_agency ON public.supplier_confirmation_activation_links USING btree (id, agency_id);


--
-- Name: index_confirmation_activation_links_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_confirmation_activation_links_on_id_departure_agency ON public.supplier_confirmation_activation_links USING btree (id, departure_id, agency_id);


--
-- Name: index_confirmation_activation_links_on_pair; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_confirmation_activation_links_on_pair ON public.supplier_confirmation_activation_links USING btree (supplier_confirmation_id, supplier_arrangement_activation_id);


--
-- Name: index_confirmation_activation_links_on_version_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_confirmation_activation_links_on_version_owner ON public.supplier_confirmation_activation_links USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_confirmation_capacity_event_links_on_id_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_confirmation_capacity_event_links_on_id_agency ON public.supplier_confirmation_capacity_event_links USING btree (id, agency_id);


--
-- Name: index_confirmation_capacity_event_links_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_confirmation_capacity_event_links_on_id_departure_agency ON public.supplier_confirmation_capacity_event_links USING btree (id, departure_id, agency_id);


--
-- Name: index_confirmation_capacity_event_links_on_pair; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_confirmation_capacity_event_links_on_pair ON public.supplier_confirmation_capacity_event_links USING btree (supplier_confirmation_id, capacity_event_id);


--
-- Name: index_confirmation_capacity_event_links_on_version_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_confirmation_capacity_event_links_on_version_owner ON public.supplier_confirmation_capacity_event_links USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_confirmation_commitment_links_on_id_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_confirmation_commitment_links_on_id_agency ON public.supplier_confirmation_commitment_links USING btree (id, agency_id);


--
-- Name: index_confirmation_commitment_links_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_confirmation_commitment_links_on_id_departure_agency ON public.supplier_confirmation_commitment_links USING btree (id, departure_id, agency_id);


--
-- Name: index_confirmation_commitment_links_on_pair; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_confirmation_commitment_links_on_pair ON public.supplier_confirmation_commitment_links USING btree (supplier_confirmation_id, supplier_commitment_id);


--
-- Name: index_confirmation_commitment_links_on_version_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_confirmation_commitment_links_on_version_owner ON public.supplier_confirmation_commitment_links USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_confirmation_identifier_links_on_id_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_confirmation_identifier_links_on_id_agency ON public.supplier_confirmation_identifier_links USING btree (id, agency_id);


--
-- Name: index_confirmation_identifier_links_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_confirmation_identifier_links_on_id_departure_agency ON public.supplier_confirmation_identifier_links USING btree (id, departure_id, agency_id);


--
-- Name: index_confirmation_identifier_links_on_pair; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_confirmation_identifier_links_on_pair ON public.supplier_confirmation_identifier_links USING btree (supplier_confirmation_id, supplier_issued_identifier_id);


--
-- Name: index_confirmation_identifier_links_on_version_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_confirmation_identifier_links_on_version_owner ON public.supplier_confirmation_identifier_links USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_confirmation_response_links_on_pair; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_confirmation_response_links_on_pair ON public.supplier_confirmation_reservation_response_links USING btree (supplier_confirmation_id, supplier_reservation_event_id);


--
-- Name: index_confirmation_scope_links_on_pair; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_confirmation_scope_links_on_pair ON public.supplier_confirmation_reservation_scope_links USING btree (supplier_confirmation_id, supplier_reservation_scope_id);


--
-- Name: index_ddl_cov_on_id_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ddl_cov_on_id_agency ON public.supplier_deadline_definition_coverage_links USING btree (id, agency_id);


--
-- Name: index_ddl_cov_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ddl_cov_on_id_departure_agency ON public.supplier_deadline_definition_coverage_links USING btree (id, departure_id, agency_id);


--
-- Name: index_ddl_defs_on_id_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ddl_defs_on_id_agency ON public.supplier_deadline_definitions USING btree (id, agency_id);


--
-- Name: index_ddl_defs_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ddl_defs_on_id_departure_agency ON public.supplier_deadline_definitions USING btree (id, departure_id, agency_id);


--
-- Name: index_ddl_lines_on_id_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ddl_lines_on_id_agency ON public.supplier_deadline_commitment_definition_lines USING btree (id, agency_id);


--
-- Name: index_ddl_lines_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ddl_lines_on_id_departure_agency ON public.supplier_deadline_commitment_definition_lines USING btree (id, departure_id, agency_id);


--
-- Name: index_ddl_occ_on_id_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ddl_occ_on_id_agency ON public.supplier_deadline_occurrences USING btree (id, agency_id);


--
-- Name: index_ddl_occ_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ddl_occ_on_id_departure_agency ON public.supplier_deadline_occurrences USING btree (id, departure_id, agency_id);


--
-- Name: index_deadline_commitment_lines_on_definition_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_deadline_commitment_lines_on_definition_position ON public.supplier_deadline_commitment_definition_lines USING btree (supplier_deadline_definition_id, "position");


--
-- Name: index_deadline_commitment_lines_on_full_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_deadline_commitment_lines_on_full_owner ON public.supplier_deadline_commitment_definition_lines USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_deadline_coverage_links_on_definition_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_deadline_coverage_links_on_definition_position ON public.supplier_deadline_definition_coverage_links USING btree (supplier_deadline_definition_id, "position");


--
-- Name: index_deadline_coverage_links_on_full_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_deadline_coverage_links_on_full_owner ON public.supplier_deadline_definition_coverage_links USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_deadline_definitions_on_full_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_deadline_definitions_on_full_owner ON public.supplier_deadline_definitions USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_deadline_definitions_on_lineage_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_deadline_definitions_on_lineage_owner ON public.supplier_deadline_definitions USING btree (id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_deadline_definitions_on_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_deadline_definitions_on_position ON public.supplier_deadline_definitions USING btree (supplier_arrangement_version_id, "position");


--
-- Name: index_deadline_occurrences_on_calculated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_deadline_occurrences_on_calculated_at ON public.supplier_deadline_occurrences USING btree (agency_id, calculated_at, id);


--
-- Name: index_deadline_occurrences_on_calculated_on; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_deadline_occurrences_on_calculated_on ON public.supplier_deadline_occurrences USING btree (agency_id, calculated_on, id);


--
-- Name: index_deadline_occurrences_on_full_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_deadline_occurrences_on_full_owner ON public.supplier_deadline_occurrences USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_deadline_occurrences_on_lineage_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_deadline_occurrences_on_lineage_owner ON public.supplier_deadline_occurrences USING btree (id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_deadline_occurrences_on_materialization_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_deadline_occurrences_on_materialization_key ON public.supplier_deadline_occurrences USING btree (supplier_arrangement_version_id, materialization_key);


--
-- Name: index_deadline_projections_on_id_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_deadline_projections_on_id_agency ON public.supplier_deadline_projections USING btree (id, agency_id);


--
-- Name: index_deadline_projections_on_next_transition; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_deadline_projections_on_next_transition ON public.supplier_deadline_projections USING btree (agency_id, next_transition_at, id);


--
-- Name: index_deadline_projections_on_occurrence; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_deadline_projections_on_occurrence ON public.supplier_deadline_projections USING btree (supplier_deadline_occurrence_id);


--
-- Name: index_departures_on_agency_and_name_search_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departures_on_agency_and_name_search_key ON public.departures USING btree (agency_id, name_search_key text_pattern_ops);


--
-- Name: index_departures_on_agency_and_reference; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_departures_on_agency_and_reference ON public.departures USING btree (agency_id, departure_reference) WHERE (departure_reference IS NOT NULL);


--
-- Name: index_departures_on_agency_ends_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departures_on_agency_ends_on_id ON public.departures USING btree (agency_id, ends_on, id);


--
-- Name: index_departures_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departures_on_agency_id ON public.departures USING btree (agency_id);


--
-- Name: index_departures_on_agency_office_starts_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departures_on_agency_office_starts_on_id ON public.departures USING btree (agency_id, responsible_office_id, starts_on, id);


--
-- Name: index_departures_on_agency_starts_on_name_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departures_on_agency_starts_on_name_id ON public.departures USING btree (agency_id, starts_on, name_search_key, id);


--
-- Name: index_departures_on_agency_status_starts_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departures_on_agency_status_starts_on_id ON public.departures USING btree (agency_id, status, starts_on, id);


--
-- Name: index_departures_on_agency_user_starts_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departures_on_agency_user_starts_on_id ON public.departures USING btree (agency_id, responsible_agency_user_id, starts_on, id);


--
-- Name: index_departures_on_id_agency_currency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_departures_on_id_agency_currency ON public.departures USING btree (id, agency_id, operating_currency);


--
-- Name: index_departures_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_departures_on_id_and_agency_id ON public.departures USING btree (id, agency_id);


--
-- Name: index_idempotency_keys_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_idempotency_keys_on_id_and_agency_id ON public.agency_command_idempotency_keys USING btree (id, agency_id);


--
-- Name: index_item_definitions_on_exact_version_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_item_definitions_on_exact_version_owner ON public.arrangement_item_definitions USING btree (arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_item_setup_results_on_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_item_setup_results_on_idempotency_key ON public.arrangement_item_setup_results USING btree (agency_command_idempotency_key_id);


--
-- Name: index_occurrence_definitions_on_exact_version_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_occurrence_definitions_on_exact_version_owner ON public.service_occurrence_definitions USING btree (service_occurrence_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_offices_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_offices_on_agency_id ON public.offices USING btree (agency_id);


--
-- Name: index_offices_on_agency_id_and_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_offices_on_agency_id_and_code ON public.offices USING btree (agency_id, code);


--
-- Name: index_offices_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_offices_on_id_and_agency_id ON public.offices USING btree (id, agency_id);


--
-- Name: index_reference_sequences_on_agency_and_namespace; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reference_sequences_on_agency_and_namespace ON public.reference_sequences USING btree (agency_id, namespace);


--
-- Name: index_reference_sequences_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reference_sequences_on_agency_id ON public.reference_sequences USING btree (agency_id);


--
-- Name: index_reservation_events_on_idempotency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reservation_events_on_idempotency ON public.supplier_reservation_events USING btree (agency_command_idempotency_key_id, agency_id) WHERE (agency_command_idempotency_key_id IS NOT NULL);


--
-- Name: index_reservation_events_on_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reservation_events_on_owner ON public.supplier_reservation_events USING btree (id, supplier_reservation_revision_id, supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_reservation_events_on_timeline; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reservation_events_on_timeline ON public.supplier_reservation_events USING btree (supplier_reservation_id, recorded_at, id);


--
-- Name: index_reservation_outcomes_on_event_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reservation_outcomes_on_event_scope ON public.supplier_reservation_event_scope_outcomes USING btree (supplier_reservation_event_id, supplier_reservation_scope_id);


--
-- Name: index_reservation_outcomes_on_scope_timeline; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reservation_outcomes_on_scope_timeline ON public.supplier_reservation_event_scope_outcomes USING btree (supplier_reservation_id, supplier_reservation_scope_id, created_at, id);


--
-- Name: index_reservation_projections_on_arrangement_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reservation_projections_on_arrangement_state ON public.supplier_reservation_projections USING btree (agency_id, supplier_arrangement_id, state, supplier_reservation_id);


--
-- Name: index_reservation_projections_on_reservation; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reservation_projections_on_reservation ON public.supplier_reservation_projections USING btree (supplier_reservation_id);


--
-- Name: index_reservation_response_links_on_full_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reservation_response_links_on_full_owner ON public.supplier_confirmation_reservation_response_links USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_reservation_response_links_on_id_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reservation_response_links_on_id_agency ON public.supplier_confirmation_reservation_response_links USING btree (id, agency_id);


--
-- Name: index_reservation_revisions_on_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reservation_revisions_on_number ON public.supplier_reservation_revisions USING btree (supplier_reservation_id, revision_number);


--
-- Name: index_reservation_revisions_on_one_planned; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reservation_revisions_on_one_planned ON public.supplier_reservation_revisions USING btree (supplier_reservation_id, status) WHERE ((status)::text = 'planned'::text);


--
-- Name: index_reservation_revisions_on_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reservation_revisions_on_owner ON public.supplier_reservation_revisions USING btree (id, supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_reservation_scope_links_on_full_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reservation_scope_links_on_full_owner ON public.supplier_confirmation_reservation_scope_links USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_reservation_scope_links_on_id_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reservation_scope_links_on_id_agency ON public.supplier_confirmation_reservation_scope_links USING btree (id, agency_id);


--
-- Name: index_reservation_scopes_on_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reservation_scopes_on_owner ON public.supplier_reservation_scopes USING btree (id, supplier_reservation_revision_id, supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_reservation_scopes_on_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reservation_scopes_on_position ON public.supplier_reservation_scopes USING btree (supplier_reservation_revision_id, "position");


--
-- Name: index_reservation_scopes_on_target; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reservation_scopes_on_target ON public.supplier_reservation_scopes USING btree (supplier_reservation_revision_id, target_kind, arrangement_item_id, service_occurrence_id, supplier_resource_id, capacity_pool_id) NULLS NOT DISTINCT;


--
-- Name: index_resource_definitions_on_exact_version_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_resource_definitions_on_exact_version_owner ON public.supplier_resource_definitions USING btree (supplier_resource_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_service_occurrence_definitions_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_service_occurrence_definitions_on_agency_id ON public.service_occurrence_definitions USING btree (agency_id);


--
-- Name: index_service_occurrence_definitions_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_service_occurrence_definitions_on_id_and_agency_id ON public.service_occurrence_definitions USING btree (id, agency_id);


--
-- Name: index_service_occurrence_definitions_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_service_occurrence_definitions_on_id_departure_agency ON public.service_occurrence_definitions USING btree (id, departure_id, agency_id);


--
-- Name: index_service_occurrence_definitions_on_version_and_stable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_service_occurrence_definitions_on_version_and_stable_id ON public.service_occurrence_definitions USING btree (supplier_arrangement_version_id, service_occurrence_id);


--
-- Name: index_service_occurrences_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_service_occurrences_on_agency_id ON public.service_occurrences USING btree (agency_id);


--
-- Name: index_service_occurrences_on_full_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_service_occurrences_on_full_owner ON public.service_occurrences USING btree (id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_service_occurrences_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_service_occurrences_on_id_and_agency_id ON public.service_occurrences USING btree (id, agency_id);


--
-- Name: index_service_occurrences_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_service_occurrences_on_id_departure_agency ON public.service_occurrences USING btree (id, departure_id, agency_id);


--
-- Name: index_service_occurrences_on_item_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_service_occurrences_on_item_owner ON public.service_occurrences USING btree (id, arrangement_item_id, agency_id);


--
-- Name: index_sessions_on_agency_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_agency_user_id ON public.sessions USING btree (agency_user_id);


--
-- Name: index_sessions_on_office_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_office_id ON public.sessions USING btree (office_id);


--
-- Name: index_supplier_arrangement_activations_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_arrangement_activations_on_agency_id ON public.supplier_arrangement_activations USING btree (agency_id);


--
-- Name: index_supplier_arrangement_versions_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_arrangement_versions_on_agency_id ON public.supplier_arrangement_versions USING btree (agency_id);


--
-- Name: index_supplier_arrangement_versions_on_full_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_arrangement_versions_on_full_owner ON public.supplier_arrangement_versions USING btree (id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_supplier_arrangement_versions_on_id_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_arrangement_versions_on_id_and_agency ON public.supplier_arrangement_versions USING btree (id, agency_id);


--
-- Name: index_supplier_arrangement_versions_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_arrangement_versions_on_id_departure_agency ON public.supplier_arrangement_versions USING btree (id, departure_id, agency_id);


--
-- Name: index_supplier_arrangement_versions_on_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_arrangement_versions_on_number ON public.supplier_arrangement_versions USING btree (supplier_arrangement_id, version_number);


--
-- Name: index_supplier_arrangement_versions_one_activated; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_arrangement_versions_one_activated ON public.supplier_arrangement_versions USING btree (supplier_arrangement_id) WHERE ((status)::text = 'activated'::text);


--
-- Name: index_supplier_arrangement_versions_one_draft; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_arrangement_versions_one_draft ON public.supplier_arrangement_versions USING btree (supplier_arrangement_id) WHERE ((status)::text = 'draft'::text);


--
-- Name: index_supplier_arrangements_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_arrangements_on_agency_id ON public.supplier_arrangements USING btree (agency_id);


--
-- Name: index_supplier_arrangements_on_departure_list; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_arrangements_on_departure_list ON public.supplier_arrangements USING btree (agency_id, departure_id, status, name, id);


--
-- Name: index_supplier_arrangements_on_governing_version; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_arrangements_on_governing_version ON public.supplier_arrangements USING btree (governing_version_id, id, departure_id, agency_id) WHERE (governing_version_id IS NOT NULL);


--
-- Name: index_supplier_arrangements_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_arrangements_on_id_and_agency_id ON public.supplier_arrangements USING btree (id, agency_id);


--
-- Name: index_supplier_arrangements_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_arrangements_on_id_departure_agency ON public.supplier_arrangements USING btree (id, departure_id, agency_id);


--
-- Name: index_supplier_arrangements_on_supplier_dependencies; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_arrangements_on_supplier_dependencies ON public.supplier_arrangements USING btree (agency_id, contracting_supplier_id, status, id);


--
-- Name: index_supplier_category_assignments_on_agency_and_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_category_assignments_on_agency_and_code ON public.supplier_category_assignments USING btree (agency_id, category_code);


--
-- Name: index_supplier_category_assignments_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_category_assignments_on_agency_id ON public.supplier_category_assignments USING btree (agency_id);


--
-- Name: index_supplier_category_assignments_on_agency_supplier_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_category_assignments_on_agency_supplier_code ON public.supplier_category_assignments USING btree (agency_id, supplier_id, category_code);


--
-- Name: index_supplier_category_assignments_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_category_assignments_on_id_and_agency_id ON public.supplier_category_assignments USING btree (id, agency_id);


--
-- Name: index_supplier_commitment_trigger_definitions_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_commitment_trigger_definitions_on_agency_id ON public.supplier_commitment_trigger_definitions USING btree (agency_id);


--
-- Name: index_supplier_commitments_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_commitments_on_agency_id ON public.supplier_commitments USING btree (agency_id);


--
-- Name: index_supplier_commitments_on_confirmation_trigger; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_commitments_on_confirmation_trigger ON public.supplier_commitments USING btree (supplier_confirmation_id, supplier_commitment_trigger_definition_id) WHERE ((opening_kind)::text = 'confirmation_trigger'::text);


--
-- Name: index_supplier_commitments_on_deadline_opening; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_commitments_on_deadline_opening ON public.supplier_commitments USING btree (supplier_deadline_occurrence_id, supplier_deadline_commitment_definition_line_id) WHERE ((opening_kind)::text = 'deadline_requirement'::text);


--
-- Name: index_supplier_commitments_on_id_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_commitments_on_id_agency ON public.supplier_commitments USING btree (id, agency_id);


--
-- Name: index_supplier_commitments_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_commitments_on_id_departure_agency ON public.supplier_commitments USING btree (id, departure_id, agency_id);


--
-- Name: index_supplier_commitments_on_supplier_blocker; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_commitments_on_supplier_blocker ON public.supplier_commitments USING btree (agency_id, committed_supplier_id, opened_at, id);


--
-- Name: index_supplier_commitments_on_version_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_commitments_on_version_owner ON public.supplier_commitments USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_supplier_confirmation_activation_links_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_confirmation_activation_links_on_agency_id ON public.supplier_confirmation_activation_links USING btree (agency_id);


--
-- Name: index_supplier_confirmation_capacity_event_links_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_confirmation_capacity_event_links_on_agency_id ON public.supplier_confirmation_capacity_event_links USING btree (agency_id);


--
-- Name: index_supplier_confirmation_commitment_links_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_confirmation_commitment_links_on_agency_id ON public.supplier_confirmation_commitment_links USING btree (agency_id);


--
-- Name: index_supplier_confirmation_identifier_links_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_confirmation_identifier_links_on_agency_id ON public.supplier_confirmation_identifier_links USING btree (agency_id);


--
-- Name: index_supplier_confirmations_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_confirmations_on_agency_id ON public.supplier_confirmations USING btree (agency_id);


--
-- Name: index_supplier_confirmations_on_arrangement_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_confirmations_on_arrangement_owner ON public.supplier_confirmations USING btree (id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_supplier_confirmations_on_id_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_confirmations_on_id_agency ON public.supplier_confirmations USING btree (id, agency_id);


--
-- Name: index_supplier_confirmations_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_confirmations_on_id_departure_agency ON public.supplier_confirmations USING btree (id, departure_id, agency_id);


--
-- Name: index_supplier_confirmations_on_version_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_confirmations_on_version_owner ON public.supplier_confirmations USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_supplier_contact_email_addresses_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_contact_email_addresses_on_agency_id ON public.supplier_contact_email_addresses USING btree (agency_id);


--
-- Name: index_supplier_contact_email_addresses_on_contact_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_contact_email_addresses_on_contact_and_agency ON public.supplier_contact_email_addresses USING btree (supplier_contact_id, agency_id);


--
-- Name: index_supplier_contact_email_addresses_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_contact_email_addresses_on_id_and_agency_id ON public.supplier_contact_email_addresses USING btree (id, agency_id);


--
-- Name: index_supplier_contact_email_addresses_on_one_preferred_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_contact_email_addresses_on_one_preferred_active ON public.supplier_contact_email_addresses USING btree (agency_id, supplier_contact_id) WHERE (preferred AND ((status)::text = 'active'::text));


--
-- Name: index_supplier_contact_emails_on_agency_and_normalized; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_contact_emails_on_agency_and_normalized ON public.supplier_contact_email_addresses USING btree (agency_id, normalized_address);


--
-- Name: index_supplier_contact_phone_numbers_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_contact_phone_numbers_on_agency_id ON public.supplier_contact_phone_numbers USING btree (agency_id);


--
-- Name: index_supplier_contact_phone_numbers_on_contact_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_contact_phone_numbers_on_contact_and_agency ON public.supplier_contact_phone_numbers USING btree (supplier_contact_id, agency_id);


--
-- Name: index_supplier_contact_phone_numbers_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_contact_phone_numbers_on_id_and_agency_id ON public.supplier_contact_phone_numbers USING btree (id, agency_id);


--
-- Name: index_supplier_contact_phone_numbers_on_one_preferred_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_contact_phone_numbers_on_one_preferred_active ON public.supplier_contact_phone_numbers USING btree (agency_id, supplier_contact_id) WHERE (preferred AND ((status)::text = 'active'::text));


--
-- Name: index_supplier_contact_phones_on_agency_and_e164; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_contact_phones_on_agency_and_e164 ON public.supplier_contact_phone_numbers USING btree (agency_id, normalized_number);


--
-- Name: index_supplier_contact_phones_on_agency_and_reversed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_contact_phones_on_agency_and_reversed ON public.supplier_contact_phone_numbers USING btree (agency_id, phone_digits_reversed text_pattern_ops);


--
-- Name: index_supplier_contacts_on_agency_and_full_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_contacts_on_agency_and_full_name ON public.supplier_contacts USING btree (agency_id, full_name_search_key);


--
-- Name: index_supplier_contacts_on_agency_and_name_parts; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_contacts_on_agency_and_name_parts ON public.supplier_contacts USING btree (agency_id, first_name_search_key, last_name_search_key);


--
-- Name: index_supplier_contacts_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_contacts_on_agency_id ON public.supplier_contacts USING btree (agency_id);


--
-- Name: index_supplier_contacts_on_agency_supplier_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_contacts_on_agency_supplier_status ON public.supplier_contacts USING btree (agency_id, supplier_id, status);


--
-- Name: index_supplier_contacts_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_contacts_on_id_and_agency_id ON public.supplier_contacts USING btree (id, agency_id);


--
-- Name: index_supplier_contacts_on_id_supplier_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_contacts_on_id_supplier_agency ON public.supplier_contacts USING btree (id, supplier_id, agency_id);


--
-- Name: index_supplier_contacts_on_name_search_vector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_contacts_on_name_search_vector ON public.supplier_contacts USING gin (name_search_vector);


--
-- Name: index_supplier_contacts_on_one_preferred_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_contacts_on_one_preferred_active ON public.supplier_contacts USING btree (agency_id, supplier_id) WHERE (preferred AND ((status)::text = 'active'::text));


--
-- Name: index_supplier_contacts_on_supplier_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_contacts_on_supplier_and_agency ON public.supplier_contacts USING btree (supplier_id, agency_id);


--
-- Name: index_supplier_cost_assumptions_on_context; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_assumptions_on_context ON public.supplier_cost_usage_assumptions USING btree (supplier_arrangement_version_id, arrangement_item_id, service_occurrence_id, supplier_resource_id) NULLS NOT DISTINCT;


--
-- Name: index_supplier_cost_assumptions_on_full_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_assumptions_on_full_owner ON public.supplier_cost_usage_assumptions USING btree (id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_supplier_cost_assumptions_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_assumptions_on_id_and_agency_id ON public.supplier_cost_usage_assumptions USING btree (id, agency_id);


--
-- Name: index_supplier_cost_assumptions_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_assumptions_on_id_departure_agency ON public.supplier_cost_usage_assumptions USING btree (id, departure_id, agency_id);


--
-- Name: index_supplier_cost_categories_on_context_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_categories_on_context_owner ON public.supplier_cost_participant_categories USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_supplier_cost_categories_on_full_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_categories_on_full_owner ON public.supplier_cost_participant_categories USING btree (id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_supplier_cost_categories_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_categories_on_id_and_agency_id ON public.supplier_cost_participant_categories USING btree (id, agency_id);


--
-- Name: index_supplier_cost_categories_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_categories_on_id_departure_agency ON public.supplier_cost_participant_categories USING btree (id, departure_id, agency_id);


--
-- Name: index_supplier_cost_component_bases_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_cost_component_bases_on_agency_id ON public.supplier_cost_component_bases USING btree (agency_id);


--
-- Name: index_supplier_cost_component_bases_on_base; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_cost_component_bases_on_base ON public.supplier_cost_component_bases USING btree (base_component_id);


--
-- Name: index_supplier_cost_component_bases_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_component_bases_on_id_and_agency_id ON public.supplier_cost_component_bases USING btree (id, agency_id);


--
-- Name: index_supplier_cost_component_bases_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_component_bases_on_id_departure_agency ON public.supplier_cost_component_bases USING btree (id, departure_id, agency_id);


--
-- Name: index_supplier_cost_component_bases_on_pair; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_component_bases_on_pair ON public.supplier_cost_component_bases USING btree (supplier_cost_component_id, base_component_id);


--
-- Name: index_supplier_cost_component_bases_on_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_component_bases_on_position ON public.supplier_cost_component_bases USING btree (supplier_cost_component_id, "position");


--
-- Name: index_supplier_cost_components_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_cost_components_on_agency_id ON public.supplier_cost_components USING btree (agency_id);


--
-- Name: index_supplier_cost_components_on_definition_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_components_on_definition_position ON public.supplier_cost_components USING btree (supplier_cost_definition_id, "position");


--
-- Name: index_supplier_cost_components_on_full_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_components_on_full_owner ON public.supplier_cost_components USING btree (id, supplier_cost_definition_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_supplier_cost_components_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_components_on_id_and_agency_id ON public.supplier_cost_components USING btree (id, agency_id);


--
-- Name: index_supplier_cost_components_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_components_on_id_departure_agency ON public.supplier_cost_components USING btree (id, departure_id, agency_id);


--
-- Name: index_supplier_cost_definitions_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_cost_definitions_on_agency_id ON public.supplier_cost_definitions USING btree (agency_id);


--
-- Name: index_supplier_cost_definitions_on_context_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_definitions_on_context_owner ON public.supplier_cost_definitions USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_supplier_cost_definitions_on_full_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_definitions_on_full_owner ON public.supplier_cost_definitions USING btree (id, supplier_cost_source_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_supplier_cost_definitions_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_definitions_on_id_and_agency_id ON public.supplier_cost_definitions USING btree (id, agency_id);


--
-- Name: index_supplier_cost_definitions_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_definitions_on_id_departure_agency ON public.supplier_cost_definitions USING btree (id, departure_id, agency_id);


--
-- Name: index_supplier_cost_definitions_on_source_stage; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_definitions_on_source_stage ON public.supplier_cost_definitions USING btree (supplier_cost_source_id, stage);


--
-- Name: index_supplier_cost_occupancy_profile_positions_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_cost_occupancy_profile_positions_on_agency_id ON public.supplier_cost_occupancy_profile_positions USING btree (agency_id);


--
-- Name: index_supplier_cost_occupancy_profiles_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_cost_occupancy_profiles_on_agency_id ON public.supplier_cost_occupancy_profiles USING btree (agency_id);


--
-- Name: index_supplier_cost_participant_categories_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_cost_participant_categories_on_agency_id ON public.supplier_cost_participant_categories USING btree (agency_id);


--
-- Name: index_supplier_cost_profile_positions_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_profile_positions_on_id_and_agency_id ON public.supplier_cost_occupancy_profile_positions USING btree (id, agency_id);


--
-- Name: index_supplier_cost_profile_positions_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_profile_positions_on_id_departure_agency ON public.supplier_cost_occupancy_profile_positions USING btree (id, departure_id, agency_id);


--
-- Name: index_supplier_cost_profile_positions_on_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_profile_positions_on_position ON public.supplier_cost_occupancy_profile_positions USING btree (supplier_cost_occupancy_profile_id, occupancy_position);


--
-- Name: index_supplier_cost_profiles_on_full_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_profiles_on_full_owner ON public.supplier_cost_occupancy_profiles USING btree (id, supplier_cost_usage_assumption_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_supplier_cost_profiles_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_profiles_on_id_and_agency_id ON public.supplier_cost_occupancy_profiles USING btree (id, agency_id);


--
-- Name: index_supplier_cost_profiles_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_profiles_on_id_departure_agency ON public.supplier_cost_occupancy_profiles USING btree (id, departure_id, agency_id);


--
-- Name: index_supplier_cost_sources_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_cost_sources_on_agency_id ON public.supplier_cost_sources USING btree (agency_id);


--
-- Name: index_supplier_cost_sources_on_charging_supplier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_cost_sources_on_charging_supplier ON public.supplier_cost_sources USING btree (agency_id, charging_supplier_id, id);


--
-- Name: index_supplier_cost_sources_on_context_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_cost_sources_on_context_position ON public.supplier_cost_sources USING btree (supplier_arrangement_version_id, arrangement_item_id, "position");


--
-- Name: index_supplier_cost_sources_on_full_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_sources_on_full_owner ON public.supplier_cost_sources USING btree (id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_supplier_cost_sources_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_sources_on_id_and_agency_id ON public.supplier_cost_sources USING btree (id, agency_id);


--
-- Name: index_supplier_cost_sources_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_cost_sources_on_id_departure_agency ON public.supplier_cost_sources USING btree (id, departure_id, agency_id);


--
-- Name: index_supplier_cost_usage_assumptions_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_cost_usage_assumptions_on_agency_id ON public.supplier_cost_usage_assumptions USING btree (agency_id);


--
-- Name: index_supplier_email_addresses_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_email_addresses_on_agency_id ON public.supplier_email_addresses USING btree (agency_id);


--
-- Name: index_supplier_email_addresses_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_email_addresses_on_id_and_agency_id ON public.supplier_email_addresses USING btree (id, agency_id);


--
-- Name: index_supplier_email_addresses_on_one_preferred_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_email_addresses_on_one_preferred_active ON public.supplier_email_addresses USING btree (agency_id, supplier_id) WHERE (preferred AND ((status)::text = 'active'::text));


--
-- Name: index_supplier_email_addresses_on_supplier_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_email_addresses_on_supplier_and_agency ON public.supplier_email_addresses USING btree (supplier_id, agency_id);


--
-- Name: index_supplier_emails_on_agency_and_normalized; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_emails_on_agency_and_normalized ON public.supplier_email_addresses USING btree (agency_id, normalized_address);


--
-- Name: index_supplier_identifiers_on_active_owner_value; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_identifiers_on_active_owner_value ON public.supplier_issued_identifiers USING btree (supplier_arrangement_id, supplier_id, identifier_type, issuer_context, normalized_value) WHERE ((superseded_at IS NULL) AND (supplier_reservation_id IS NULL));


--
-- Name: index_supplier_identifiers_on_active_reservation_value; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_identifiers_on_active_reservation_value ON public.supplier_issued_identifiers USING btree (supplier_reservation_id, supplier_id, identifier_type, issuer_context, normalized_value) WHERE ((superseded_at IS NULL) AND (supplier_reservation_id IS NOT NULL));


--
-- Name: index_supplier_identifiers_on_candidate_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_identifiers_on_candidate_lookup ON public.supplier_issued_identifiers USING btree (agency_id, supplier_id, identifier_type, issuer_context, normalized_value, id);


--
-- Name: index_supplier_identifiers_on_full_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_identifiers_on_full_owner ON public.supplier_issued_identifiers USING btree (id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_supplier_identifiers_on_id_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_identifiers_on_id_agency ON public.supplier_issued_identifiers USING btree (id, agency_id);


--
-- Name: index_supplier_identifiers_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_identifiers_on_id_departure_agency ON public.supplier_issued_identifiers USING btree (id, departure_id, agency_id);


--
-- Name: index_supplier_identifiers_on_reservation_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_identifiers_on_reservation_owner ON public.supplier_issued_identifiers USING btree (id, supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_supplier_issued_identifiers_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_issued_identifiers_on_agency_id ON public.supplier_issued_identifiers USING btree (agency_id);


--
-- Name: index_supplier_locations_on_agency_and_locality; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_locations_on_agency_and_locality ON public.supplier_locations USING btree (agency_id, locality_search_key text_pattern_ops);


--
-- Name: index_supplier_locations_on_agency_and_name_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_locations_on_agency_and_name_key ON public.supplier_locations USING btree (agency_id, name_search_key);


--
-- Name: index_supplier_locations_on_agency_and_postal_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_locations_on_agency_and_postal_code ON public.supplier_locations USING btree (agency_id, postal_code_search_key);


--
-- Name: index_supplier_locations_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_locations_on_agency_id ON public.supplier_locations USING btree (agency_id);


--
-- Name: index_supplier_locations_on_agency_supplier_postal_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_locations_on_agency_supplier_postal_key ON public.supplier_locations USING btree (agency_id, supplier_id, postal_address_search_key);


--
-- Name: index_supplier_locations_on_agency_supplier_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_locations_on_agency_supplier_status ON public.supplier_locations USING btree (agency_id, supplier_id, status);


--
-- Name: index_supplier_locations_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_locations_on_id_and_agency_id ON public.supplier_locations USING btree (id, agency_id);


--
-- Name: index_supplier_locations_on_name_search_vector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_locations_on_name_search_vector ON public.supplier_locations USING gin (name_search_vector);


--
-- Name: index_supplier_locations_on_supplier_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_locations_on_supplier_and_agency ON public.supplier_locations USING btree (supplier_id, agency_id);


--
-- Name: index_supplier_phone_numbers_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_phone_numbers_on_agency_id ON public.supplier_phone_numbers USING btree (agency_id);


--
-- Name: index_supplier_phone_numbers_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_phone_numbers_on_id_and_agency_id ON public.supplier_phone_numbers USING btree (id, agency_id);


--
-- Name: index_supplier_phone_numbers_on_one_preferred_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_phone_numbers_on_one_preferred_active ON public.supplier_phone_numbers USING btree (agency_id, supplier_id) WHERE (preferred AND ((status)::text = 'active'::text));


--
-- Name: index_supplier_phone_numbers_on_supplier_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_phone_numbers_on_supplier_and_agency ON public.supplier_phone_numbers USING btree (supplier_id, agency_id);


--
-- Name: index_supplier_phones_on_agency_and_e164; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_phones_on_agency_and_e164 ON public.supplier_phone_numbers USING btree (agency_id, normalized_number);


--
-- Name: index_supplier_phones_on_agency_and_reversed_digits; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_phones_on_agency_and_reversed_digits ON public.supplier_phone_numbers USING btree (agency_id, phone_digits_reversed text_pattern_ops);


--
-- Name: index_supplier_postal_addresses_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_postal_addresses_on_agency_id ON public.supplier_postal_addresses USING btree (agency_id);


--
-- Name: index_supplier_postal_addresses_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_postal_addresses_on_id_and_agency_id ON public.supplier_postal_addresses USING btree (id, agency_id);


--
-- Name: index_supplier_postal_addresses_on_one_preferred_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_postal_addresses_on_one_preferred_active ON public.supplier_postal_addresses USING btree (agency_id, supplier_id) WHERE (preferred AND ((status)::text = 'active'::text));


--
-- Name: index_supplier_postal_addresses_on_supplier_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_postal_addresses_on_supplier_and_agency ON public.supplier_postal_addresses USING btree (supplier_id, agency_id);


--
-- Name: index_supplier_postals_on_agency_and_locality; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_postals_on_agency_and_locality ON public.supplier_postal_addresses USING btree (agency_id, locality_search_key text_pattern_ops);


--
-- Name: index_supplier_postals_on_agency_and_postal_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_postals_on_agency_and_postal_code ON public.supplier_postal_addresses USING btree (agency_id, postal_code_search_key);


--
-- Name: index_supplier_reservation_event_scope_outcomes_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_reservation_event_scope_outcomes_on_agency_id ON public.supplier_reservation_event_scope_outcomes USING btree (agency_id);


--
-- Name: index_supplier_reservation_events_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_reservation_events_on_agency_id ON public.supplier_reservation_events USING btree (agency_id);


--
-- Name: index_supplier_reservation_projections_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_reservation_projections_on_agency_id ON public.supplier_reservation_projections USING btree (agency_id);


--
-- Name: index_supplier_reservation_revisions_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_reservation_revisions_on_agency_id ON public.supplier_reservation_revisions USING btree (agency_id);


--
-- Name: index_supplier_reservation_scopes_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_reservation_scopes_on_agency_id ON public.supplier_reservation_scopes USING btree (agency_id);


--
-- Name: index_supplier_reservations_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_reservations_on_agency_id ON public.supplier_reservations USING btree (agency_id);


--
-- Name: index_supplier_reservations_on_arrangement_supplier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_reservations_on_arrangement_supplier ON public.supplier_reservations USING btree (agency_id, supplier_arrangement_id, booking_supplier_id, id);


--
-- Name: index_supplier_reservations_on_full_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_reservations_on_full_owner ON public.supplier_reservations USING btree (id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_supplier_reservations_on_id_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_reservations_on_id_agency ON public.supplier_reservations USING btree (id, agency_id);


--
-- Name: index_supplier_reservations_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_reservations_on_id_departure_agency ON public.supplier_reservations USING btree (id, departure_id, agency_id);


--
-- Name: index_supplier_resource_definitions_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_resource_definitions_on_agency_id ON public.supplier_resource_definitions USING btree (agency_id);


--
-- Name: index_supplier_resource_definitions_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_resource_definitions_on_id_and_agency_id ON public.supplier_resource_definitions USING btree (id, agency_id);


--
-- Name: index_supplier_resource_definitions_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_resource_definitions_on_id_departure_agency ON public.supplier_resource_definitions USING btree (id, departure_id, agency_id);


--
-- Name: index_supplier_resource_definitions_on_version_and_stable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_resource_definitions_on_version_and_stable_id ON public.supplier_resource_definitions USING btree (supplier_arrangement_version_id, supplier_resource_id);


--
-- Name: index_supplier_resources_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_resources_on_agency_id ON public.supplier_resources USING btree (agency_id);


--
-- Name: index_supplier_resources_on_full_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_resources_on_full_owner ON public.supplier_resources USING btree (id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: index_supplier_resources_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_resources_on_id_and_agency_id ON public.supplier_resources USING btree (id, agency_id);


--
-- Name: index_supplier_resources_on_id_departure_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_resources_on_id_departure_agency ON public.supplier_resources USING btree (id, departure_id, agency_id);


--
-- Name: index_supplier_resources_on_item_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_resources_on_item_owner ON public.supplier_resources USING btree (id, arrangement_item_id, agency_id);


--
-- Name: index_supplier_websites_on_agency_and_host; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_websites_on_agency_and_host ON public.supplier_websites USING btree (agency_id, normalized_host);


--
-- Name: index_supplier_websites_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_websites_on_agency_id ON public.supplier_websites USING btree (agency_id);


--
-- Name: index_supplier_websites_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_websites_on_id_and_agency_id ON public.supplier_websites USING btree (id, agency_id);


--
-- Name: index_supplier_websites_on_one_preferred_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_websites_on_one_preferred_active ON public.supplier_websites USING btree (agency_id, supplier_id) WHERE (preferred AND ((status)::text = 'active'::text));


--
-- Name: index_supplier_websites_on_supplier_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_websites_on_supplier_and_agency ON public.supplier_websites USING btree (supplier_id, agency_id);


--
-- Name: index_suppliers_on_agency_and_dba_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_suppliers_on_agency_and_dba_key ON public.suppliers USING btree (agency_id, doing_business_as_search_key);


--
-- Name: index_suppliers_on_agency_and_display_name_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_suppliers_on_agency_and_display_name_key ON public.suppliers USING btree (agency_id, display_name_search_key);


--
-- Name: index_suppliers_on_agency_and_individual_name_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_suppliers_on_agency_and_individual_name_key ON public.suppliers USING btree (agency_id, individual_full_name_search_key);


--
-- Name: index_suppliers_on_agency_and_legal_name_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_suppliers_on_agency_and_legal_name_key ON public.suppliers USING btree (agency_id, legal_name_search_key);


--
-- Name: index_suppliers_on_agency_and_reference; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_suppliers_on_agency_and_reference ON public.suppliers USING btree (agency_id, supplier_reference);


--
-- Name: index_suppliers_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_suppliers_on_agency_id ON public.suppliers USING btree (agency_id);


--
-- Name: index_suppliers_on_agency_kind_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_suppliers_on_agency_kind_status ON public.suppliers USING btree (agency_id, kind, status);


--
-- Name: index_suppliers_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_suppliers_on_id_and_agency_id ON public.suppliers USING btree (id, agency_id);


--
-- Name: index_suppliers_on_name_search_vector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_suppliers_on_name_search_vector ON public.suppliers USING gin (name_search_vector);


--
-- Name: item_definitions_copied_from_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX item_definitions_copied_from_idx ON public.arrangement_item_definitions USING btree (copied_from_id);


--
-- Name: item_definitions_lineage_owner_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX item_definitions_lineage_owner_idx ON public.arrangement_item_definitions USING btree (id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: occurrence_definitions_copied_from_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX occurrence_definitions_copied_from_idx ON public.service_occurrence_definitions USING btree (copied_from_id);


--
-- Name: occurrence_definitions_lineage_owner_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX occurrence_definitions_lineage_owner_idx ON public.service_occurrence_definitions USING btree (id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: resource_definitions_copied_from_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX resource_definitions_copied_from_idx ON public.supplier_resource_definitions USING btree (copied_from_id);


--
-- Name: resource_definitions_lineage_owner_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX resource_definitions_lineage_owner_idx ON public.supplier_resource_definitions USING btree (id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_assumptions_copied_from_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX supplier_cost_assumptions_copied_from_idx ON public.supplier_cost_usage_assumptions USING btree (copied_from_id);


--
-- Name: supplier_cost_assumptions_lineage_owner_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX supplier_cost_assumptions_lineage_owner_idx ON public.supplier_cost_usage_assumptions USING btree (id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_categories_copied_from_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX supplier_cost_categories_copied_from_idx ON public.supplier_cost_participant_categories USING btree (copied_from_id);


--
-- Name: supplier_cost_categories_lineage_owner_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX supplier_cost_categories_lineage_owner_idx ON public.supplier_cost_participant_categories USING btree (id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_component_bases_copied_from_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX supplier_cost_component_bases_copied_from_idx ON public.supplier_cost_component_bases USING btree (copied_from_id);


--
-- Name: supplier_cost_component_bases_lineage_owner_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX supplier_cost_component_bases_lineage_owner_idx ON public.supplier_cost_component_bases USING btree (id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_components_copied_from_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX supplier_cost_components_copied_from_idx ON public.supplier_cost_components USING btree (copied_from_id);


--
-- Name: supplier_cost_components_lineage_owner_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX supplier_cost_components_lineage_owner_idx ON public.supplier_cost_components USING btree (id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_definitions_copied_from_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX supplier_cost_definitions_copied_from_idx ON public.supplier_cost_definitions USING btree (copied_from_id);


--
-- Name: supplier_cost_definitions_lineage_owner_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX supplier_cost_definitions_lineage_owner_idx ON public.supplier_cost_definitions USING btree (id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_profile_positions_copied_from_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX supplier_cost_profile_positions_copied_from_idx ON public.supplier_cost_occupancy_profile_positions USING btree (copied_from_id);


--
-- Name: supplier_cost_profile_positions_lineage_owner_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX supplier_cost_profile_positions_lineage_owner_idx ON public.supplier_cost_occupancy_profile_positions USING btree (id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_profiles_copied_from_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX supplier_cost_profiles_copied_from_idx ON public.supplier_cost_occupancy_profiles USING btree (copied_from_id);


--
-- Name: supplier_cost_profiles_lineage_owner_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX supplier_cost_profiles_lineage_owner_idx ON public.supplier_cost_occupancy_profiles USING btree (id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_sources_copied_from_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX supplier_cost_sources_copied_from_idx ON public.supplier_cost_sources USING btree (copied_from_id);


--
-- Name: supplier_cost_sources_lineage_owner_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX supplier_cost_sources_lineage_owner_idx ON public.supplier_cost_sources USING btree (id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: agencies agencies_reject_workspace_code_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER agencies_reject_workspace_code_change BEFORE UPDATE ON public.agencies FOR EACH ROW EXECUTE FUNCTION public.reject_agency_workspace_code_change();


--
-- Name: agency_users agency_users_reject_agency_id_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER agency_users_reject_agency_id_change BEFORE UPDATE ON public.agency_users FOR EACH ROW EXECUTE FUNCTION public.reject_agency_user_agency_change();


--
-- Name: arrangement_item_definitions arrangement_item_definitions_reject_non_draft_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER arrangement_item_definitions_reject_non_draft_mutation BEFORE INSERT OR DELETE OR UPDATE ON public.arrangement_item_definitions FOR EACH ROW EXECUTE FUNCTION public.reject_non_draft_arrangement_version_definition_mutation();


--
-- Name: arrangement_item_definitions arrangement_item_definitions_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER arrangement_item_definitions_reject_owner_change BEFORE UPDATE ON public.arrangement_item_definitions FOR EACH ROW EXECUTE FUNCTION public.reject_arrangement_item_definition_owner_change();


--
-- Name: arrangement_items arrangement_items_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER arrangement_items_reject_owner_change BEFORE UPDATE ON public.arrangement_items FOR EACH ROW EXECUTE FUNCTION public.reject_arrangement_item_owner_change();


--
-- Name: audit_events audit_events_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_events_reject_update BEFORE DELETE OR UPDATE ON public.audit_events FOR EACH ROW EXECUTE FUNCTION public.reject_audit_event_mutation();


--
-- Name: capacity_events capacity_events_reject_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_events_reject_delete BEFORE DELETE ON public.capacity_events FOR EACH ROW EXECUTE FUNCTION public.reject_capacity_event_mutation();


--
-- Name: capacity_events capacity_events_reject_nonnumeric_pool; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_events_reject_nonnumeric_pool BEFORE INSERT ON public.capacity_events FOR EACH ROW EXECUTE FUNCTION public.reject_nonnumeric_capacity_event();


--
-- Name: capacity_events capacity_events_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_events_reject_update BEFORE UPDATE ON public.capacity_events FOR EACH ROW EXECUTE FUNCTION public.reject_capacity_event_mutation();


--
-- Name: capacity_pair_definitions capacity_pair_definitions_reject_non_draft_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_pair_definitions_reject_non_draft_mutation BEFORE INSERT OR DELETE OR UPDATE ON public.capacity_pair_definitions FOR EACH ROW EXECUTE FUNCTION public.reject_non_draft_arrangement_version_definition_mutation();


--
-- Name: capacity_pair_definitions capacity_pair_definitions_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_pair_definitions_reject_owner_change BEFORE UPDATE ON public.capacity_pair_definitions FOR EACH ROW EXECUTE FUNCTION public.reject_capacity_pair_definition_owner_change();


--
-- Name: capacity_pair_definitions capacity_pairs_reject_cancelled_occurrence; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_pairs_reject_cancelled_occurrence BEFORE INSERT OR UPDATE OF service_occurrence_id ON public.capacity_pair_definitions FOR EACH ROW EXECUTE FUNCTION public.reject_capacity_pair_for_cancelled_occurrence();


--
-- Name: capacity_pool_definitions capacity_pool_definitions_reject_non_draft_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_pool_definitions_reject_non_draft_mutation BEFORE INSERT OR DELETE OR UPDATE ON public.capacity_pool_definitions FOR EACH ROW EXECUTE FUNCTION public.reject_non_draft_arrangement_version_definition_mutation();


--
-- Name: capacity_pool_definitions capacity_pool_definitions_reject_nonnumeric_quantity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_pool_definitions_reject_nonnumeric_quantity BEFORE INSERT OR UPDATE ON public.capacity_pool_definitions FOR EACH ROW EXECUTE FUNCTION public.reject_nonnumeric_capacity_pool_definition_quantity();


--
-- Name: capacity_pool_definitions capacity_pool_definitions_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_pool_definitions_reject_owner_change BEFORE UPDATE ON public.capacity_pool_definitions FOR EACH ROW EXECUTE FUNCTION public.reject_capacity_pool_definition_owner_change();


--
-- Name: capacity_pools capacity_pools_reject_invalid_zone; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_pools_reject_invalid_zone BEFORE INSERT OR UPDATE OF effective_time_zone ON public.capacity_pools FOR EACH ROW EXECUTE FUNCTION public.reject_invalid_capacity_pool_zone();


--
-- Name: capacity_pools capacity_pools_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_pools_reject_owner_change BEFORE UPDATE ON public.capacity_pools FOR EACH ROW EXECUTE FUNCTION public.reject_capacity_pool_owner_change();


--
-- Name: capacity_projections capacity_projections_reject_nonnumeric_pool; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_projections_reject_nonnumeric_pool BEFORE INSERT ON public.capacity_projections FOR EACH ROW EXECUTE FUNCTION public.reject_nonnumeric_capacity_projection();


--
-- Name: capacity_projections capacity_projections_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_projections_reject_owner_change BEFORE UPDATE ON public.capacity_projections FOR EACH ROW EXECUTE FUNCTION public.reject_capacity_projection_owner_change();


--
-- Name: capacity_reconciliation_resolutions capacity_reconciliation_resolutions_reject_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_reconciliation_resolutions_reject_delete BEFORE DELETE ON public.capacity_reconciliation_resolutions FOR EACH ROW EXECUTE FUNCTION public.reject_capacity_reconciliation_resolution_mutation();


--
-- Name: capacity_reconciliation_resolutions capacity_reconciliation_resolutions_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_reconciliation_resolutions_reject_update BEFORE UPDATE ON public.capacity_reconciliation_resolutions FOR EACH ROW EXECUTE FUNCTION public.reject_capacity_reconciliation_resolution_mutation();


--
-- Name: capacity_reconciliations capacity_reconciliations_reject_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_reconciliations_reject_delete BEFORE DELETE ON public.capacity_reconciliations FOR EACH ROW EXECUTE FUNCTION public.reject_capacity_reconciliation_mutation();


--
-- Name: capacity_reconciliations capacity_reconciliations_reject_nonnumeric_pool; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_reconciliations_reject_nonnumeric_pool BEFORE INSERT ON public.capacity_reconciliations FOR EACH ROW EXECUTE FUNCTION public.reject_nonnumeric_capacity_reconciliation();


--
-- Name: capacity_reconciliations capacity_reconciliations_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_reconciliations_reject_update BEFORE UPDATE ON public.capacity_reconciliations FOR EACH ROW EXECUTE FUNCTION public.reject_capacity_reconciliation_mutation();


--
-- Name: client_organization_email_addresses client_org_email_addresses_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_org_email_addresses_reject_owner_change BEFORE UPDATE ON public.client_organization_email_addresses FOR EACH ROW EXECUTE FUNCTION public.reject_client_organization_contact_owner_change();


--
-- Name: client_organization_phone_numbers client_org_phone_numbers_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_org_phone_numbers_reject_owner_change BEFORE UPDATE ON public.client_organization_phone_numbers FOR EACH ROW EXECUTE FUNCTION public.reject_client_organization_contact_owner_change();


--
-- Name: client_organization_postal_addresses client_org_postal_addresses_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_org_postal_addresses_reject_owner_change BEFORE UPDATE ON public.client_organization_postal_addresses FOR EACH ROW EXECUTE FUNCTION public.reject_client_organization_contact_owner_change();


--
-- Name: client_organization_websites client_org_websites_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_org_websites_reject_owner_change BEFORE UPDATE ON public.client_organization_websites FOR EACH ROW EXECUTE FUNCTION public.reject_client_organization_contact_owner_change();


--
-- Name: client_organization_contacts client_organization_contacts_reject_identity_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_organization_contacts_reject_identity_change BEFORE UPDATE ON public.client_organization_contacts FOR EACH ROW EXECUTE FUNCTION public.reject_client_organization_contact_identity_change();


--
-- Name: client_organizations client_organizations_reject_agency_id_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_organizations_reject_agency_id_change BEFORE UPDATE ON public.client_organizations FOR EACH ROW EXECUTE FUNCTION public.reject_directory_agency_change();


--
-- Name: client_people client_people_reject_agency_id_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_people_reject_agency_id_change BEFORE UPDATE ON public.client_people FOR EACH ROW EXECUTE FUNCTION public.reject_directory_agency_change();


--
-- Name: client_person_email_addresses client_person_email_addresses_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_person_email_addresses_reject_owner_change BEFORE UPDATE ON public.client_person_email_addresses FOR EACH ROW EXECUTE FUNCTION public.reject_client_person_contact_owner_change();


--
-- Name: client_person_phone_numbers client_person_phone_numbers_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_person_phone_numbers_reject_owner_change BEFORE UPDATE ON public.client_person_phone_numbers FOR EACH ROW EXECUTE FUNCTION public.reject_client_person_contact_owner_change();


--
-- Name: client_person_postal_addresses client_person_postal_addresses_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_person_postal_addresses_reject_owner_change BEFORE UPDATE ON public.client_person_postal_addresses FOR EACH ROW EXECUTE FUNCTION public.reject_client_person_contact_owner_change();


--
-- Name: clients clients_reject_identity_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER clients_reject_identity_change BEFORE UPDATE ON public.clients FOR EACH ROW EXECUTE FUNCTION public.reject_client_identity_change();


--
-- Name: departures departures_reject_identity_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER departures_reject_identity_change BEFORE UPDATE ON public.departures FOR EACH ROW EXECUTE FUNCTION public.reject_departure_identity_change();


--
-- Name: offices offices_reject_identity_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER offices_reject_identity_change BEFORE UPDATE ON public.offices FOR EACH ROW EXECUTE FUNCTION public.reject_office_identity_change();


--
-- Name: reference_sequences reference_sequences_reject_identity_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER reference_sequences_reject_identity_change BEFORE UPDATE ON public.reference_sequences FOR EACH ROW EXECUTE FUNCTION public.reject_reference_sequence_identity_change();


--
-- Name: service_occurrence_definitions service_occurrence_definitions_reject_invalid_zone; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER service_occurrence_definitions_reject_invalid_zone BEFORE INSERT OR UPDATE OF time_zone ON public.service_occurrence_definitions FOR EACH ROW EXECUTE FUNCTION public.reject_invalid_service_occurrence_definition_zone();


--
-- Name: service_occurrence_definitions service_occurrence_definitions_reject_non_draft_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER service_occurrence_definitions_reject_non_draft_mutation BEFORE INSERT OR DELETE OR UPDATE ON public.service_occurrence_definitions FOR EACH ROW EXECUTE FUNCTION public.reject_non_draft_arrangement_version_definition_mutation();


--
-- Name: service_occurrence_definitions service_occurrence_definitions_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER service_occurrence_definitions_reject_owner_change BEFORE UPDATE ON public.service_occurrence_definitions FOR EACH ROW EXECUTE FUNCTION public.reject_service_occurrence_definition_owner_change();


--
-- Name: service_occurrences service_occurrences_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER service_occurrences_reject_owner_change BEFORE UPDATE ON public.service_occurrences FOR EACH ROW EXECUTE FUNCTION public.reject_service_occurrence_owner_change();


--
-- Name: supplier_arrangement_activation_capacity_entries supplier_arrangement_activation_capacity_entries_reject_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_arrangement_activation_capacity_entries_reject_delete BEFORE DELETE ON public.supplier_arrangement_activation_capacity_entries FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_arrangement_activation_capacity_entries supplier_arrangement_activation_capacity_entries_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_arrangement_activation_capacity_entries_reject_update BEFORE UPDATE ON public.supplier_arrangement_activation_capacity_entries FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_arrangement_activation_cost_selections supplier_arrangement_activation_cost_selections_reject_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_arrangement_activation_cost_selections_reject_delete BEFORE DELETE ON public.supplier_arrangement_activation_cost_selections FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_arrangement_activation_cost_selections supplier_arrangement_activation_cost_selections_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_arrangement_activation_cost_selections_reject_update BEFORE UPDATE ON public.supplier_arrangement_activation_cost_selections FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_arrangement_activations supplier_arrangement_activations_reject_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_arrangement_activations_reject_delete BEFORE DELETE ON public.supplier_arrangement_activations FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_arrangement_activations supplier_arrangement_activations_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_arrangement_activations_reject_update BEFORE UPDATE ON public.supplier_arrangement_activations FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_arrangement_versions supplier_arrangement_versions_reject_illegal_lifecycle; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_arrangement_versions_reject_illegal_lifecycle BEFORE UPDATE ON public.supplier_arrangement_versions FOR EACH ROW EXECUTE FUNCTION public.reject_illegal_supplier_arrangement_version_lifecycle();


--
-- Name: supplier_arrangement_versions supplier_arrangement_versions_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_arrangement_versions_reject_owner_change BEFORE UPDATE ON public.supplier_arrangement_versions FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_arrangement_version_owner_change();


--
-- Name: supplier_arrangements supplier_arrangements_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_arrangements_reject_owner_change BEFORE UPDATE ON public.supplier_arrangements FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_arrangement_owner_change();


--
-- Name: supplier_category_assignments supplier_category_assignments_reject_identity_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_category_assignments_reject_identity_change BEFORE UPDATE ON public.supplier_category_assignments FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_category_identity_change();


--
-- Name: supplier_commitment_dispositions supplier_commitment_dispositions_enforce_coverage_purpose; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_commitment_dispositions_enforce_coverage_purpose BEFORE INSERT ON public.supplier_commitment_dispositions FOR EACH ROW EXECUTE FUNCTION public.enforce_commitment_disposition_coverage_purpose();


--
-- Name: supplier_commitment_dispositions supplier_commitment_dispositions_enforce_current; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_commitment_dispositions_enforce_current BEFORE INSERT ON public.supplier_commitment_dispositions FOR EACH ROW EXECUTE FUNCTION public.reject_second_current_commitment_disposition();


--
-- Name: supplier_commitment_dispositions supplier_commitment_dispositions_reject_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_commitment_dispositions_reject_delete BEFORE DELETE ON public.supplier_commitment_dispositions FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_commitment_dispositions supplier_commitment_dispositions_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_commitment_dispositions_reject_update BEFORE UPDATE ON public.supplier_commitment_dispositions FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_commitment_evidence_coverage_members supplier_commitment_evidence_coverage_members_reject_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_commitment_evidence_coverage_members_reject_delete BEFORE DELETE ON public.supplier_commitment_evidence_coverage_members FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_commitment_evidence_coverage_members supplier_commitment_evidence_coverage_members_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_commitment_evidence_coverage_members_reject_update BEFORE UPDATE ON public.supplier_commitment_evidence_coverage_members FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_commitment_evidence_coverage_revocations supplier_commitment_evidence_coverage_revocations_reject_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_commitment_evidence_coverage_revocations_reject_delete BEFORE DELETE ON public.supplier_commitment_evidence_coverage_revocations FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_commitment_evidence_coverage_revocations supplier_commitment_evidence_coverage_revocations_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_commitment_evidence_coverage_revocations_reject_update BEFORE UPDATE ON public.supplier_commitment_evidence_coverage_revocations FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_commitment_evidence_coverages supplier_commitment_evidence_coverages_reject_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_commitment_evidence_coverages_reject_delete BEFORE DELETE ON public.supplier_commitment_evidence_coverages FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_commitment_evidence_coverages supplier_commitment_evidence_coverages_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_commitment_evidence_coverages_reject_update BEFORE UPDATE ON public.supplier_commitment_evidence_coverages FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_commitment_evidence_member_disqualifications supplier_commitment_evidence_member_disqualifications_reject_de; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_commitment_evidence_member_disqualifications_reject_de BEFORE DELETE ON public.supplier_commitment_evidence_member_disqualifications FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_commitment_evidence_member_disqualifications supplier_commitment_evidence_member_disqualifications_reject_up; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_commitment_evidence_member_disqualifications_reject_up BEFORE UPDATE ON public.supplier_commitment_evidence_member_disqualifications FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_commitment_evidence_coverage_members supplier_commitment_evidence_members_reject_after_disposition; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_commitment_evidence_members_reject_after_disposition BEFORE INSERT ON public.supplier_commitment_evidence_coverage_members FOR EACH ROW EXECUTE FUNCTION public.reject_evidence_member_after_disposition();


--
-- Name: supplier_commitment_reopenings supplier_commitment_reopenings_reject_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_commitment_reopenings_reject_delete BEFORE DELETE ON public.supplier_commitment_reopenings FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_commitment_reopenings supplier_commitment_reopenings_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_commitment_reopenings_reject_update BEFORE UPDATE ON public.supplier_commitment_reopenings FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_commitment_trigger_definitions supplier_commitment_trigger_definitions_reject_non_draft_mutati; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_commitment_trigger_definitions_reject_non_draft_mutati BEFORE INSERT OR DELETE OR UPDATE ON public.supplier_commitment_trigger_definitions FOR EACH ROW EXECUTE FUNCTION public.reject_non_draft_arrangement_version_definition_mutation();


--
-- Name: supplier_commitment_trigger_definitions supplier_commitment_trigger_definitions_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_commitment_trigger_definitions_reject_owner_change BEFORE UPDATE ON public.supplier_commitment_trigger_definitions FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_commitment_trigger_definition_owner_change();


--
-- Name: supplier_commitments supplier_commitments_reject_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_commitments_reject_delete BEFORE DELETE ON public.supplier_commitments FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_commitments supplier_commitments_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_commitments_reject_update BEFORE UPDATE ON public.supplier_commitments FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_confirmation_activation_links supplier_confirmation_activation_links_reject_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_confirmation_activation_links_reject_delete BEFORE DELETE ON public.supplier_confirmation_activation_links FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_confirmation_activation_links supplier_confirmation_activation_links_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_confirmation_activation_links_reject_update BEFORE UPDATE ON public.supplier_confirmation_activation_links FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_confirmation_capacity_event_links supplier_confirmation_capacity_event_links_reject_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_confirmation_capacity_event_links_reject_delete BEFORE DELETE ON public.supplier_confirmation_capacity_event_links FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_confirmation_capacity_event_links supplier_confirmation_capacity_event_links_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_confirmation_capacity_event_links_reject_update BEFORE UPDATE ON public.supplier_confirmation_capacity_event_links FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_confirmation_commitment_links supplier_confirmation_commitment_links_reject_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_confirmation_commitment_links_reject_delete BEFORE DELETE ON public.supplier_confirmation_commitment_links FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_confirmation_commitment_links supplier_confirmation_commitment_links_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_confirmation_commitment_links_reject_update BEFORE UPDATE ON public.supplier_confirmation_commitment_links FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_confirmation_identifier_links supplier_confirmation_identifier_links_reject_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_confirmation_identifier_links_reject_delete BEFORE DELETE ON public.supplier_confirmation_identifier_links FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_confirmation_identifier_links supplier_confirmation_identifier_links_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_confirmation_identifier_links_reject_update BEFORE UPDATE ON public.supplier_confirmation_identifier_links FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_confirmation_reservation_response_links supplier_confirmation_reservation_response_links_reject_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_confirmation_reservation_response_links_reject_delete BEFORE DELETE ON public.supplier_confirmation_reservation_response_links FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_confirmation_reservation_response_links supplier_confirmation_reservation_response_links_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_confirmation_reservation_response_links_reject_update BEFORE UPDATE ON public.supplier_confirmation_reservation_response_links FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_confirmation_reservation_scope_links supplier_confirmation_reservation_scope_links_reject_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_confirmation_reservation_scope_links_reject_delete BEFORE DELETE ON public.supplier_confirmation_reservation_scope_links FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_confirmation_reservation_scope_links supplier_confirmation_reservation_scope_links_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_confirmation_reservation_scope_links_reject_update BEFORE UPDATE ON public.supplier_confirmation_reservation_scope_links FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_confirmations supplier_confirmations_reject_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_confirmations_reject_delete BEFORE DELETE ON public.supplier_confirmations FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_confirmations supplier_confirmations_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_confirmations_reject_update BEFORE UPDATE ON public.supplier_confirmations FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_contact_email_addresses supplier_contact_email_addresses_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_contact_email_addresses_reject_owner_change BEFORE UPDATE ON public.supplier_contact_email_addresses FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_contact_destination_owner_change();


--
-- Name: supplier_contact_phone_numbers supplier_contact_phone_numbers_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_contact_phone_numbers_reject_owner_change BEFORE UPDATE ON public.supplier_contact_phone_numbers FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_contact_destination_owner_change();


--
-- Name: supplier_contacts supplier_contacts_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_contacts_reject_owner_change BEFORE UPDATE ON public.supplier_contacts FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_contact_person_owner_change();


--
-- Name: supplier_cost_component_bases supplier_cost_component_bases_reject_non_draft_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_cost_component_bases_reject_non_draft_mutation BEFORE INSERT OR DELETE OR UPDATE ON public.supplier_cost_component_bases FOR EACH ROW EXECUTE FUNCTION public.reject_non_draft_arrangement_version_definition_mutation();


--
-- Name: supplier_cost_component_bases supplier_cost_component_bases_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_cost_component_bases_reject_owner_change BEFORE UPDATE ON public.supplier_cost_component_bases FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_cost_component_basis_owner_change();


--
-- Name: supplier_cost_component_bases supplier_cost_component_bases_validate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_cost_component_bases_validate BEFORE INSERT OR UPDATE ON public.supplier_cost_component_bases FOR EACH ROW EXECUTE FUNCTION public.validate_supplier_cost_component_base();


--
-- Name: supplier_cost_components supplier_cost_components_clear_bases_for_kind; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_cost_components_clear_bases_for_kind AFTER UPDATE OF calculation_kind ON public.supplier_cost_components FOR EACH ROW EXECUTE FUNCTION public.clear_supplier_cost_component_bases_for_kind();


--
-- Name: supplier_cost_components supplier_cost_components_reject_non_draft_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_cost_components_reject_non_draft_mutation BEFORE INSERT OR DELETE OR UPDATE ON public.supplier_cost_components FOR EACH ROW EXECUTE FUNCTION public.reject_non_draft_arrangement_version_definition_mutation();


--
-- Name: supplier_cost_components supplier_cost_components_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_cost_components_reject_owner_change BEFORE UPDATE ON public.supplier_cost_components FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_cost_component_owner_change();


--
-- Name: supplier_cost_components supplier_cost_components_validate_context; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_cost_components_validate_context BEFORE INSERT OR UPDATE ON public.supplier_cost_components FOR EACH ROW EXECUTE FUNCTION public.validate_supplier_cost_component();


--
-- Name: supplier_cost_definitions supplier_cost_definitions_reject_non_draft_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_cost_definitions_reject_non_draft_mutation BEFORE INSERT OR DELETE OR UPDATE ON public.supplier_cost_definitions FOR EACH ROW EXECUTE FUNCTION public.reject_non_draft_arrangement_version_definition_mutation();


--
-- Name: supplier_cost_definitions supplier_cost_definitions_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_cost_definitions_reject_owner_change BEFORE UPDATE ON public.supplier_cost_definitions FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_cost_definition_owner_change();


--
-- Name: supplier_cost_definitions supplier_cost_definitions_reject_stage_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_cost_definitions_reject_stage_change BEFORE UPDATE OF stage ON public.supplier_cost_definitions FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_cost_definition_stage_change();


--
-- Name: supplier_cost_definitions supplier_cost_definitions_validate_mode_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_cost_definitions_validate_mode_change BEFORE UPDATE OF mode ON public.supplier_cost_definitions FOR EACH ROW EXECUTE FUNCTION public.validate_supplier_cost_definition_mode_change();


--
-- Name: supplier_cost_occupancy_profile_positions supplier_cost_occupancy_profile_positions_reject_non_draft_muta; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_cost_occupancy_profile_positions_reject_non_draft_muta BEFORE INSERT OR DELETE OR UPDATE ON public.supplier_cost_occupancy_profile_positions FOR EACH ROW EXECUTE FUNCTION public.reject_non_draft_arrangement_version_definition_mutation();


--
-- Name: supplier_cost_occupancy_profile_positions supplier_cost_occupancy_profile_positions_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_cost_occupancy_profile_positions_reject_owner_change BEFORE UPDATE ON public.supplier_cost_occupancy_profile_positions FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_cost_occupancy_profile_position_owner_change();


--
-- Name: supplier_cost_occupancy_profiles supplier_cost_occupancy_profiles_reject_non_draft_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_cost_occupancy_profiles_reject_non_draft_mutation BEFORE INSERT OR DELETE OR UPDATE ON public.supplier_cost_occupancy_profiles FOR EACH ROW EXECUTE FUNCTION public.reject_non_draft_arrangement_version_definition_mutation();


--
-- Name: supplier_cost_occupancy_profiles supplier_cost_occupancy_profiles_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_cost_occupancy_profiles_reject_owner_change BEFORE UPDATE ON public.supplier_cost_occupancy_profiles FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_cost_occupancy_profile_owner_change();


--
-- Name: supplier_cost_participant_categories supplier_cost_participant_categories_reject_non_draft_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_cost_participant_categories_reject_non_draft_mutation BEFORE INSERT OR DELETE OR UPDATE ON public.supplier_cost_participant_categories FOR EACH ROW EXECUTE FUNCTION public.reject_non_draft_arrangement_version_definition_mutation();


--
-- Name: supplier_cost_participant_categories supplier_cost_participant_categories_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_cost_participant_categories_reject_owner_change BEFORE UPDATE ON public.supplier_cost_participant_categories FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_cost_participant_category_owner_change();


--
-- Name: supplier_cost_sources supplier_cost_sources_reject_non_draft_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_cost_sources_reject_non_draft_mutation BEFORE INSERT OR DELETE OR UPDATE ON public.supplier_cost_sources FOR EACH ROW EXECUTE FUNCTION public.reject_non_draft_arrangement_version_definition_mutation();


--
-- Name: supplier_cost_sources supplier_cost_sources_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_cost_sources_reject_owner_change BEFORE UPDATE ON public.supplier_cost_sources FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_cost_source_owner_change();


--
-- Name: supplier_cost_usage_assumptions supplier_cost_usage_assumptions_reject_non_draft_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_cost_usage_assumptions_reject_non_draft_mutation BEFORE INSERT OR DELETE OR UPDATE ON public.supplier_cost_usage_assumptions FOR EACH ROW EXECUTE FUNCTION public.reject_non_draft_arrangement_version_definition_mutation();


--
-- Name: supplier_cost_usage_assumptions supplier_cost_usage_assumptions_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_cost_usage_assumptions_reject_owner_change BEFORE UPDATE ON public.supplier_cost_usage_assumptions FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_cost_usage_assumption_owner_change();


--
-- Name: supplier_deadline_commitment_definition_lines supplier_deadline_commitment_definition_lines_reject_non_draft_; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_deadline_commitment_definition_lines_reject_non_draft_ BEFORE INSERT OR DELETE OR UPDATE ON public.supplier_deadline_commitment_definition_lines FOR EACH ROW EXECUTE FUNCTION public.reject_non_draft_arrangement_version_definition_mutation();


--
-- Name: supplier_deadline_definition_coverage_links supplier_deadline_definition_coverage_links_reject_non_draft_mu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_deadline_definition_coverage_links_reject_non_draft_mu BEFORE INSERT OR DELETE OR UPDATE ON public.supplier_deadline_definition_coverage_links FOR EACH ROW EXECUTE FUNCTION public.reject_non_draft_arrangement_version_definition_mutation();


--
-- Name: supplier_deadline_definitions supplier_deadline_definitions_reject_non_draft_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_deadline_definitions_reject_non_draft_mutation BEFORE INSERT OR DELETE OR UPDATE ON public.supplier_deadline_definitions FOR EACH ROW EXECUTE FUNCTION public.reject_non_draft_arrangement_version_definition_mutation();


--
-- Name: supplier_deadline_definitions supplier_deadline_definitions_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_deadline_definitions_reject_owner_change BEFORE UPDATE ON public.supplier_deadline_definitions FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_deadline_definition_owner_change();


--
-- Name: supplier_deadline_occurrences supplier_deadline_occurrences_reject_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_deadline_occurrences_reject_delete BEFORE DELETE ON public.supplier_deadline_occurrences FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_deadline_occurrences supplier_deadline_occurrences_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_deadline_occurrences_reject_update BEFORE UPDATE ON public.supplier_deadline_occurrences FOR EACH ROW EXECUTE FUNCTION public.allow_deadline_occurrence_supersession_only();


--
-- Name: supplier_email_addresses supplier_email_addresses_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_email_addresses_reject_owner_change BEFORE UPDATE ON public.supplier_email_addresses FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_contact_owner_change();


--
-- Name: supplier_issued_identifiers supplier_issued_identifiers_reject_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_issued_identifiers_reject_delete BEFORE DELETE ON public.supplier_issued_identifiers FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_issued_identifiers supplier_issued_identifiers_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_issued_identifiers_reject_update BEFORE UPDATE ON public.supplier_issued_identifiers FOR EACH ROW EXECUTE FUNCTION public.allow_supplier_identifier_supersession_stamp();


--
-- Name: supplier_issued_identifiers supplier_issued_identifiers_stamp_superseded; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_issued_identifiers_stamp_superseded BEFORE INSERT ON public.supplier_issued_identifiers FOR EACH ROW WHEN ((new.supersedes_id IS NOT NULL)) EXECUTE FUNCTION public.stamp_supplier_identifier_superseded_by_successor();


--
-- Name: supplier_locations supplier_locations_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_locations_reject_owner_change BEFORE UPDATE ON public.supplier_locations FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_location_owner_change();


--
-- Name: supplier_phone_numbers supplier_phone_numbers_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_phone_numbers_reject_owner_change BEFORE UPDATE ON public.supplier_phone_numbers FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_contact_owner_change();


--
-- Name: supplier_postal_addresses supplier_postal_addresses_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_postal_addresses_reject_owner_change BEFORE UPDATE ON public.supplier_postal_addresses FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_contact_owner_change();


--
-- Name: supplier_reservation_events supplier_reservation_events_reject_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_reservation_events_reject_delete BEFORE DELETE ON public.supplier_reservation_events FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_reservation_events supplier_reservation_events_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_reservation_events_reject_update BEFORE UPDATE ON public.supplier_reservation_events FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_reservation_event_scope_outcomes supplier_reservation_outcomes_reject_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_reservation_outcomes_reject_delete BEFORE DELETE ON public.supplier_reservation_event_scope_outcomes FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_reservation_event_scope_outcomes supplier_reservation_outcomes_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_reservation_outcomes_reject_update BEFORE UPDATE ON public.supplier_reservation_event_scope_outcomes FOR EACH ROW EXECUTE FUNCTION public.reject_m3d_immutable_mutation();


--
-- Name: supplier_reservation_event_scope_outcomes supplier_reservation_outcomes_require_event_compat; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_reservation_outcomes_require_event_compat BEFORE INSERT ON public.supplier_reservation_event_scope_outcomes FOR EACH ROW EXECUTE FUNCTION public.reject_incompatible_reservation_outcome();


--
-- Name: supplier_reservation_scopes supplier_reservation_scopes_freeze_after_request; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_reservation_scopes_freeze_after_request BEFORE INSERT OR DELETE OR UPDATE ON public.supplier_reservation_scopes FOR EACH ROW EXECUTE FUNCTION public.reject_requested_reservation_scope_mutation();


--
-- Name: supplier_reservation_scopes supplier_reservation_scopes_require_pool_definition; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_reservation_scopes_require_pool_definition BEFORE INSERT OR UPDATE ON public.supplier_reservation_scopes FOR EACH ROW EXECUTE FUNCTION public.reject_reservation_scope_without_capacity_pool_definition();


--
-- Name: supplier_reservations supplier_reservations_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_reservations_reject_owner_change BEFORE UPDATE ON public.supplier_reservations FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_reservation_owner_change();


--
-- Name: supplier_resource_definitions supplier_resource_definitions_reject_non_draft_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_resource_definitions_reject_non_draft_mutation BEFORE INSERT OR DELETE OR UPDATE ON public.supplier_resource_definitions FOR EACH ROW EXECUTE FUNCTION public.reject_non_draft_arrangement_version_definition_mutation();


--
-- Name: supplier_resource_definitions supplier_resource_definitions_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_resource_definitions_reject_owner_change BEFORE UPDATE ON public.supplier_resource_definitions FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_resource_definition_owner_change();


--
-- Name: supplier_resources supplier_resources_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_resources_reject_owner_change BEFORE UPDATE ON public.supplier_resources FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_resource_owner_change();


--
-- Name: supplier_websites supplier_websites_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_websites_reject_owner_change BEFORE UPDATE ON public.supplier_websites FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_contact_owner_change();


--
-- Name: suppliers suppliers_reject_identity_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER suppliers_reject_identity_change BEFORE UPDATE ON public.suppliers FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_identity_change();


--
-- Name: supplier_arrangement_activation_capacity_entries activation_capacity_entries_activation_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangement_activation_capacity_entries
    ADD CONSTRAINT activation_capacity_entries_activation_fk FOREIGN KEY (supplier_arrangement_activation_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_activations(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_arrangement_activation_capacity_entries activation_capacity_entries_event_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangement_activation_capacity_entries
    ADD CONSTRAINT activation_capacity_entries_event_fk FOREIGN KEY (establishment_event_id, capacity_pool_id, agency_id) REFERENCES public.capacity_events(id, capacity_pool_id, agency_id);


--
-- Name: supplier_arrangement_activation_capacity_entries activation_capacity_entries_pool_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangement_activation_capacity_entries
    ADD CONSTRAINT activation_capacity_entries_pool_definition_fk FOREIGN KEY (capacity_pool_definition_id, capacity_pool_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.capacity_pool_definitions(id, capacity_pool_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_arrangement_activation_cost_selections activation_cost_selections_activation_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangement_activation_cost_selections
    ADD CONSTRAINT activation_cost_selections_activation_fk FOREIGN KEY (supplier_arrangement_activation_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_activations(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_arrangement_activation_cost_selections activation_cost_selections_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangement_activation_cost_selections
    ADD CONSTRAINT activation_cost_selections_definition_fk FOREIGN KEY (supplier_cost_definition_id, supplier_cost_source_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_cost_definitions(id, supplier_cost_source_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: agency_users agency_users_default_office_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agency_users
    ADD CONSTRAINT agency_users_default_office_fk FOREIGN KEY (default_office_id, agency_id) REFERENCES public.offices(id, agency_id);


--
-- Name: supplier_arrangement_activations arrangement_activations_actor_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangement_activations
    ADD CONSTRAINT arrangement_activations_actor_fk FOREIGN KEY (actor_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: supplier_arrangement_activations arrangement_activations_confirmation_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangement_activations
    ADD CONSTRAINT arrangement_activations_confirmation_fk FOREIGN KEY (supplier_confirmation_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_confirmations(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_arrangement_activations arrangement_activations_predecessor_activation_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangement_activations
    ADD CONSTRAINT arrangement_activations_predecessor_activation_fk FOREIGN KEY (predecessor_activation_id, predecessor_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_activations(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_arrangement_activations arrangement_activations_predecessor_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangement_activations
    ADD CONSTRAINT arrangement_activations_predecessor_version_fk FOREIGN KEY (predecessor_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_arrangement_activations arrangement_activations_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangement_activations
    ADD CONSTRAINT arrangement_activations_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: arrangement_item_definitions arrangement_item_definitions_item_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arrangement_item_definitions
    ADD CONSTRAINT arrangement_item_definitions_item_fk FOREIGN KEY (arrangement_item_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.arrangement_items(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: arrangement_item_definitions arrangement_item_definitions_provider_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arrangement_item_definitions
    ADD CONSTRAINT arrangement_item_definitions_provider_fk FOREIGN KEY (default_service_provider_id, agency_id) REFERENCES public.suppliers(id, agency_id);


--
-- Name: arrangement_item_definitions arrangement_item_definitions_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arrangement_item_definitions
    ADD CONSTRAINT arrangement_item_definitions_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: arrangement_items arrangement_items_arrangement_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arrangement_items
    ADD CONSTRAINT arrangement_items_arrangement_fk FOREIGN KEY (supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangements(id, departure_id, agency_id);


--
-- Name: audit_events audit_events_actor_agency_user_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_actor_agency_user_fk FOREIGN KEY (actor_agency_user_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: capacity_events capacity_events_actor_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_events
    ADD CONSTRAINT capacity_events_actor_fk FOREIGN KEY (actor_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: capacity_events capacity_events_corrects_event_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_events
    ADD CONSTRAINT capacity_events_corrects_event_fk FOREIGN KEY (corrects_event_id, capacity_pool_id, agency_id) REFERENCES public.capacity_events(id, capacity_pool_id, agency_id);


--
-- Name: capacity_events capacity_events_idempotency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_events
    ADD CONSTRAINT capacity_events_idempotency_fk FOREIGN KEY (agency_command_idempotency_key_id, agency_id) REFERENCES public.agency_command_idempotency_keys(id, agency_id);


--
-- Name: capacity_events capacity_events_pool_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_events
    ADD CONSTRAINT capacity_events_pool_fk FOREIGN KEY (capacity_pool_id, service_occurrence_id, supplier_resource_id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.capacity_pools(id, service_occurrence_id, supplier_resource_id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: capacity_events capacity_events_reconciliation_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_events
    ADD CONSTRAINT capacity_events_reconciliation_fk FOREIGN KEY (capacity_reconciliation_id, capacity_pool_id, agency_id) REFERENCES public.capacity_reconciliations(id, capacity_pool_id, agency_id);


--
-- Name: capacity_events capacity_events_reinstates_event_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_events
    ADD CONSTRAINT capacity_events_reinstates_event_fk FOREIGN KEY (reinstates_event_id, capacity_pool_id, agency_id) REFERENCES public.capacity_events(id, capacity_pool_id, agency_id);


--
-- Name: capacity_events capacity_events_supplier_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_events
    ADD CONSTRAINT capacity_events_supplier_fk FOREIGN KEY (supplying_supplier_id, agency_id) REFERENCES public.suppliers(id, agency_id);


--
-- Name: capacity_events capacity_events_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_events
    ADD CONSTRAINT capacity_events_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: capacity_pair_definitions capacity_pair_definitions_item_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pair_definitions
    ADD CONSTRAINT capacity_pair_definitions_item_definition_fk FOREIGN KEY (arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.arrangement_item_definitions(arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: capacity_pair_definitions capacity_pair_definitions_item_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pair_definitions
    ADD CONSTRAINT capacity_pair_definitions_item_fk FOREIGN KEY (arrangement_item_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.arrangement_items(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: capacity_pair_definitions capacity_pair_definitions_occurrence_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pair_definitions
    ADD CONSTRAINT capacity_pair_definitions_occurrence_definition_fk FOREIGN KEY (service_occurrence_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.service_occurrence_definitions(service_occurrence_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: capacity_pair_definitions capacity_pair_definitions_occurrence_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pair_definitions
    ADD CONSTRAINT capacity_pair_definitions_occurrence_fk FOREIGN KEY (service_occurrence_id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.service_occurrences(id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: capacity_pair_definitions capacity_pair_definitions_resource_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pair_definitions
    ADD CONSTRAINT capacity_pair_definitions_resource_definition_fk FOREIGN KEY (supplier_resource_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_resource_definitions(supplier_resource_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: capacity_pair_definitions capacity_pair_definitions_resource_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pair_definitions
    ADD CONSTRAINT capacity_pair_definitions_resource_fk FOREIGN KEY (supplier_resource_id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_resources(id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: capacity_pair_definitions capacity_pair_definitions_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pair_definitions
    ADD CONSTRAINT capacity_pair_definitions_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: capacity_pair_definitions capacity_pairs_copied_from_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pair_definitions
    ADD CONSTRAINT capacity_pairs_copied_from_fk FOREIGN KEY (copied_from_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.capacity_pair_definitions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: capacity_pool_definitions capacity_pool_definitions_pair_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pool_definitions
    ADD CONSTRAINT capacity_pool_definitions_pair_fk FOREIGN KEY (capacity_pair_definition_id, service_occurrence_id, supplier_resource_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.capacity_pair_definitions(id, service_occurrence_id, supplier_resource_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: capacity_pool_definitions capacity_pool_definitions_pool_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pool_definitions
    ADD CONSTRAINT capacity_pool_definitions_pool_fk FOREIGN KEY (capacity_pool_id, service_occurrence_id, supplier_resource_id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.capacity_pools(id, service_occurrence_id, supplier_resource_id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: capacity_pool_definitions capacity_pool_definitions_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pool_definitions
    ADD CONSTRAINT capacity_pool_definitions_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: capacity_pool_definitions capacity_pool_defs_copied_from_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pool_definitions
    ADD CONSTRAINT capacity_pool_defs_copied_from_fk FOREIGN KEY (copied_from_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.capacity_pool_definitions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: capacity_pools capacity_pools_arrangement_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pools
    ADD CONSTRAINT capacity_pools_arrangement_fk FOREIGN KEY (supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangements(id, departure_id, agency_id);


--
-- Name: capacity_pools capacity_pools_item_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pools
    ADD CONSTRAINT capacity_pools_item_fk FOREIGN KEY (arrangement_item_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.arrangement_items(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: capacity_pools capacity_pools_occurrence_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pools
    ADD CONSTRAINT capacity_pools_occurrence_fk FOREIGN KEY (service_occurrence_id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.service_occurrences(id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: capacity_pools capacity_pools_resource_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pools
    ADD CONSTRAINT capacity_pools_resource_fk FOREIGN KEY (supplier_resource_id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_resources(id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: capacity_pools capacity_pools_supplier_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pools
    ADD CONSTRAINT capacity_pools_supplier_fk FOREIGN KEY (supplying_supplier_id, agency_id) REFERENCES public.suppliers(id, agency_id);


--
-- Name: capacity_projections capacity_projections_last_event_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_projections
    ADD CONSTRAINT capacity_projections_last_event_fk FOREIGN KEY (last_event_id, capacity_pool_id, agency_id) REFERENCES public.capacity_events(id, capacity_pool_id, agency_id);


--
-- Name: capacity_projections capacity_projections_next_event_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_projections
    ADD CONSTRAINT capacity_projections_next_event_fk FOREIGN KEY (next_event_id, capacity_pool_id, agency_id) REFERENCES public.capacity_events(id, capacity_pool_id, agency_id);


--
-- Name: capacity_projections capacity_projections_pool_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_projections
    ADD CONSTRAINT capacity_projections_pool_fk FOREIGN KEY (capacity_pool_id, service_occurrence_id, supplier_resource_id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.capacity_pools(id, service_occurrence_id, supplier_resource_id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: capacity_reconciliation_resolutions capacity_recon_resolutions_event_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_reconciliation_resolutions
    ADD CONSTRAINT capacity_recon_resolutions_event_fk FOREIGN KEY (capacity_event_id, capacity_pool_id, agency_id) REFERENCES public.capacity_events(id, capacity_pool_id, agency_id);


--
-- Name: capacity_reconciliation_resolutions capacity_recon_resolutions_reconciliation_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_reconciliation_resolutions
    ADD CONSTRAINT capacity_recon_resolutions_reconciliation_fk FOREIGN KEY (capacity_reconciliation_id, capacity_pool_id, agency_id) REFERENCES public.capacity_reconciliations(id, capacity_pool_id, agency_id);


--
-- Name: capacity_reconciliation_resolutions capacity_reconciliation_resolutions_actor_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_reconciliation_resolutions
    ADD CONSTRAINT capacity_reconciliation_resolutions_actor_fk FOREIGN KEY (actor_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: capacity_reconciliation_resolutions capacity_reconciliation_resolutions_pool_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_reconciliation_resolutions
    ADD CONSTRAINT capacity_reconciliation_resolutions_pool_fk FOREIGN KEY (capacity_pool_id, service_occurrence_id, supplier_resource_id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.capacity_pools(id, service_occurrence_id, supplier_resource_id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: capacity_reconciliation_resolutions capacity_reconciliation_resolutions_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_reconciliation_resolutions
    ADD CONSTRAINT capacity_reconciliation_resolutions_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: capacity_reconciliations capacity_reconciliations_actor_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_reconciliations
    ADD CONSTRAINT capacity_reconciliations_actor_fk FOREIGN KEY (actor_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: capacity_reconciliations capacity_reconciliations_idempotency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_reconciliations
    ADD CONSTRAINT capacity_reconciliations_idempotency_fk FOREIGN KEY (agency_command_idempotency_key_id, agency_id) REFERENCES public.agency_command_idempotency_keys(id, agency_id);


--
-- Name: capacity_reconciliations capacity_reconciliations_pool_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_reconciliations
    ADD CONSTRAINT capacity_reconciliations_pool_fk FOREIGN KEY (capacity_pool_id, service_occurrence_id, supplier_resource_id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.capacity_pools(id, service_occurrence_id, supplier_resource_id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: capacity_reconciliations capacity_reconciliations_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_reconciliations
    ADD CONSTRAINT capacity_reconciliations_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: client_organization_contacts client_org_contacts_organization_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_organization_contacts
    ADD CONSTRAINT client_org_contacts_organization_agency_fk FOREIGN KEY (client_organization_id, agency_id) REFERENCES public.client_organizations(id, agency_id);


--
-- Name: client_organization_contacts client_org_contacts_person_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_organization_contacts
    ADD CONSTRAINT client_org_contacts_person_agency_fk FOREIGN KEY (client_person_id, agency_id) REFERENCES public.client_people(id, agency_id);


--
-- Name: client_organization_email_addresses client_org_email_addresses_organization_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_organization_email_addresses
    ADD CONSTRAINT client_org_email_addresses_organization_agency_fk FOREIGN KEY (client_organization_id, agency_id) REFERENCES public.client_organizations(id, agency_id);


--
-- Name: client_organization_phone_numbers client_org_phone_numbers_organization_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_organization_phone_numbers
    ADD CONSTRAINT client_org_phone_numbers_organization_agency_fk FOREIGN KEY (client_organization_id, agency_id) REFERENCES public.client_organizations(id, agency_id);


--
-- Name: client_organization_postal_addresses client_org_postal_addresses_organization_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_organization_postal_addresses
    ADD CONSTRAINT client_org_postal_addresses_organization_agency_fk FOREIGN KEY (client_organization_id, agency_id) REFERENCES public.client_organizations(id, agency_id);


--
-- Name: client_organization_websites client_org_websites_organization_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_organization_websites
    ADD CONSTRAINT client_org_websites_organization_agency_fk FOREIGN KEY (client_organization_id, agency_id) REFERENCES public.client_organizations(id, agency_id);


--
-- Name: client_person_email_addresses client_person_email_addresses_person_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_person_email_addresses
    ADD CONSTRAINT client_person_email_addresses_person_agency_fk FOREIGN KEY (client_person_id, agency_id) REFERENCES public.client_people(id, agency_id);


--
-- Name: client_person_phone_numbers client_person_phone_numbers_person_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_person_phone_numbers
    ADD CONSTRAINT client_person_phone_numbers_person_agency_fk FOREIGN KEY (client_person_id, agency_id) REFERENCES public.client_people(id, agency_id);


--
-- Name: client_person_postal_addresses client_person_postal_addresses_person_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_person_postal_addresses
    ADD CONSTRAINT client_person_postal_addresses_person_agency_fk FOREIGN KEY (client_person_id, agency_id) REFERENCES public.client_people(id, agency_id);


--
-- Name: clients clients_organization_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_organization_agency_fk FOREIGN KEY (client_organization_id, agency_id) REFERENCES public.client_organizations(id, agency_id);


--
-- Name: clients clients_person_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_person_agency_fk FOREIGN KEY (client_person_id, agency_id) REFERENCES public.client_people(id, agency_id);


--
-- Name: supplier_commitment_dispositions commitment_dispositions_actor_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_dispositions
    ADD CONSTRAINT commitment_dispositions_actor_fk FOREIGN KEY (actor_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: supplier_commitment_dispositions commitment_dispositions_commitment_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_dispositions
    ADD CONSTRAINT commitment_dispositions_commitment_fk FOREIGN KEY (supplier_commitment_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_commitments(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_dispositions commitment_dispositions_idempotency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_dispositions
    ADD CONSTRAINT commitment_dispositions_idempotency_fk FOREIGN KEY (agency_command_idempotency_key_id, agency_id) REFERENCES public.agency_command_idempotency_keys(id, agency_id);


--
-- Name: supplier_commitment_dispositions commitment_dispositions_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_dispositions
    ADD CONSTRAINT commitment_dispositions_membership_fk FOREIGN KEY (supplier_commitment_evidence_coverage_id, supplier_commitment_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_commitment_evidence_coverage_members(supplier_commitment_evidence_coverage_id, supplier_commitment_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_dispositions commitment_dispositions_replacement_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_dispositions
    ADD CONSTRAINT commitment_dispositions_replacement_fk FOREIGN KEY (replacement_supplier_commitment_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_commitments(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_dispositions commitment_dispositions_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_dispositions
    ADD CONSTRAINT commitment_dispositions_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_evidence_coverages commitment_evidence_coverages_actor_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_evidence_coverages
    ADD CONSTRAINT commitment_evidence_coverages_actor_fk FOREIGN KEY (actor_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: supplier_commitment_evidence_coverages commitment_evidence_coverages_confirmation_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_evidence_coverages
    ADD CONSTRAINT commitment_evidence_coverages_confirmation_fk FOREIGN KEY (supplier_confirmation_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_confirmations(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_evidence_coverages commitment_evidence_coverages_idempotency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_evidence_coverages
    ADD CONSTRAINT commitment_evidence_coverages_idempotency_fk FOREIGN KEY (agency_command_idempotency_key_id, agency_id) REFERENCES public.agency_command_idempotency_keys(id, agency_id);


--
-- Name: supplier_commitment_evidence_coverages commitment_evidence_coverages_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_evidence_coverages
    ADD CONSTRAINT commitment_evidence_coverages_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_evidence_member_disqualifications commitment_evidence_disqualifications_actor_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_evidence_member_disqualifications
    ADD CONSTRAINT commitment_evidence_disqualifications_actor_fk FOREIGN KEY (actor_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: supplier_commitment_evidence_member_disqualifications commitment_evidence_disqualifications_disposition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_evidence_member_disqualifications
    ADD CONSTRAINT commitment_evidence_disqualifications_disposition_fk FOREIGN KEY (supplier_commitment_disposition_id, supplier_commitment_evidence_coverage_id, supplier_commitment_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_commitment_dispositions(id, supplier_commitment_evidence_coverage_id, supplier_commitment_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_evidence_member_disqualifications commitment_evidence_disqualifications_idempotency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_evidence_member_disqualifications
    ADD CONSTRAINT commitment_evidence_disqualifications_idempotency_fk FOREIGN KEY (agency_command_idempotency_key_id, agency_id) REFERENCES public.agency_command_idempotency_keys(id, agency_id);


--
-- Name: supplier_commitment_evidence_member_disqualifications commitment_evidence_disqualifications_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_evidence_member_disqualifications
    ADD CONSTRAINT commitment_evidence_disqualifications_membership_fk FOREIGN KEY (supplier_commitment_evidence_coverage_id, supplier_commitment_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_commitment_evidence_coverage_members(supplier_commitment_evidence_coverage_id, supplier_commitment_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_evidence_member_disqualifications commitment_evidence_disqualifications_reopening_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_evidence_member_disqualifications
    ADD CONSTRAINT commitment_evidence_disqualifications_reopening_fk FOREIGN KEY (supplier_commitment_reopening_id, supplier_commitment_disposition_id, supplier_commitment_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_commitment_reopenings(id, supplier_commitment_disposition_id, supplier_commitment_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_evidence_member_disqualifications commitment_evidence_disqualifications_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_evidence_member_disqualifications
    ADD CONSTRAINT commitment_evidence_disqualifications_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_evidence_coverage_members commitment_evidence_members_commitment_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_evidence_coverage_members
    ADD CONSTRAINT commitment_evidence_members_commitment_fk FOREIGN KEY (supplier_commitment_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_commitments(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_evidence_coverage_members commitment_evidence_members_coverage_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_evidence_coverage_members
    ADD CONSTRAINT commitment_evidence_members_coverage_fk FOREIGN KEY (supplier_commitment_evidence_coverage_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_commitment_evidence_coverages(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_evidence_coverage_members commitment_evidence_members_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_evidence_coverage_members
    ADD CONSTRAINT commitment_evidence_members_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_evidence_coverage_revocations commitment_evidence_revocations_actor_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_evidence_coverage_revocations
    ADD CONSTRAINT commitment_evidence_revocations_actor_fk FOREIGN KEY (actor_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: supplier_commitment_evidence_coverage_revocations commitment_evidence_revocations_coverage_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_evidence_coverage_revocations
    ADD CONSTRAINT commitment_evidence_revocations_coverage_fk FOREIGN KEY (supplier_commitment_evidence_coverage_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_commitment_evidence_coverages(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_evidence_coverage_revocations commitment_evidence_revocations_idempotency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_evidence_coverage_revocations
    ADD CONSTRAINT commitment_evidence_revocations_idempotency_fk FOREIGN KEY (agency_command_idempotency_key_id, agency_id) REFERENCES public.agency_command_idempotency_keys(id, agency_id);


--
-- Name: supplier_commitment_evidence_coverage_revocations commitment_evidence_revocations_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_evidence_coverage_revocations
    ADD CONSTRAINT commitment_evidence_revocations_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_reopenings commitment_reopenings_actor_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_reopenings
    ADD CONSTRAINT commitment_reopenings_actor_fk FOREIGN KEY (actor_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: supplier_commitment_reopenings commitment_reopenings_commitment_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_reopenings
    ADD CONSTRAINT commitment_reopenings_commitment_fk FOREIGN KEY (supplier_commitment_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_commitments(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_reopenings commitment_reopenings_disposition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_reopenings
    ADD CONSTRAINT commitment_reopenings_disposition_fk FOREIGN KEY (supplier_commitment_disposition_id, supplier_commitment_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_commitment_dispositions(id, supplier_commitment_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_reopenings commitment_reopenings_idempotency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_reopenings
    ADD CONSTRAINT commitment_reopenings_idempotency_fk FOREIGN KEY (agency_command_idempotency_key_id, agency_id) REFERENCES public.agency_command_idempotency_keys(id, agency_id);


--
-- Name: supplier_commitment_reopenings commitment_reopenings_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_reopenings
    ADD CONSTRAINT commitment_reopenings_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_trigger_definitions commitment_triggers_capacity_pool_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_trigger_definitions
    ADD CONSTRAINT commitment_triggers_capacity_pool_fk FOREIGN KEY (capacity_pool_id, service_occurrence_id, supplier_resource_id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.capacity_pools(id, service_occurrence_id, supplier_resource_id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_trigger_definitions commitment_triggers_copied_from_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_trigger_definitions
    ADD CONSTRAINT commitment_triggers_copied_from_fk FOREIGN KEY (copied_from_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_commitment_trigger_definitions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_trigger_definitions commitment_triggers_cost_component_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_trigger_definitions
    ADD CONSTRAINT commitment_triggers_cost_component_fk FOREIGN KEY (supplier_cost_component_id, supplier_cost_definition_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_cost_components(id, supplier_cost_definition_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_trigger_definitions commitment_triggers_cost_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_trigger_definitions
    ADD CONSTRAINT commitment_triggers_cost_definition_fk FOREIGN KEY (supplier_cost_definition_id, supplier_cost_source_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_cost_definitions(id, supplier_cost_source_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_trigger_definitions commitment_triggers_cost_source_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_trigger_definitions
    ADD CONSTRAINT commitment_triggers_cost_source_fk FOREIGN KEY (supplier_cost_source_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_cost_sources(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_trigger_definitions commitment_triggers_item_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_trigger_definitions
    ADD CONSTRAINT commitment_triggers_item_definition_fk FOREIGN KEY (arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.arrangement_item_definitions(arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_trigger_definitions commitment_triggers_occurrence_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_trigger_definitions
    ADD CONSTRAINT commitment_triggers_occurrence_definition_fk FOREIGN KEY (service_occurrence_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.service_occurrence_definitions(service_occurrence_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_trigger_definitions commitment_triggers_resource_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_trigger_definitions
    ADD CONSTRAINT commitment_triggers_resource_definition_fk FOREIGN KEY (supplier_resource_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_resource_definitions(supplier_resource_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitment_trigger_definitions commitment_triggers_supplier_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_trigger_definitions
    ADD CONSTRAINT commitment_triggers_supplier_fk FOREIGN KEY (committed_supplier_id, agency_id) REFERENCES public.suppliers(id, agency_id);


--
-- Name: supplier_commitment_trigger_definitions commitment_triggers_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_trigger_definitions
    ADD CONSTRAINT commitment_triggers_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_confirmation_activation_links confirmation_activation_links_confirmation_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_activation_links
    ADD CONSTRAINT confirmation_activation_links_confirmation_fk FOREIGN KEY (supplier_confirmation_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_confirmations(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_confirmation_activation_links confirmation_activation_links_target_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_activation_links
    ADD CONSTRAINT confirmation_activation_links_target_fk FOREIGN KEY (supplier_arrangement_activation_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_activations(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_confirmation_activation_links confirmation_activation_links_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_activation_links
    ADD CONSTRAINT confirmation_activation_links_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_confirmation_capacity_event_links confirmation_capacity_event_links_confirmation_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_capacity_event_links
    ADD CONSTRAINT confirmation_capacity_event_links_confirmation_fk FOREIGN KEY (supplier_confirmation_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_confirmations(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_confirmation_capacity_event_links confirmation_capacity_event_links_target_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_capacity_event_links
    ADD CONSTRAINT confirmation_capacity_event_links_target_fk FOREIGN KEY (capacity_event_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.capacity_events(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_confirmation_capacity_event_links confirmation_capacity_event_links_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_capacity_event_links
    ADD CONSTRAINT confirmation_capacity_event_links_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_confirmation_commitment_links confirmation_commitment_links_confirmation_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_commitment_links
    ADD CONSTRAINT confirmation_commitment_links_confirmation_fk FOREIGN KEY (supplier_confirmation_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_confirmations(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_confirmation_commitment_links confirmation_commitment_links_target_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_commitment_links
    ADD CONSTRAINT confirmation_commitment_links_target_fk FOREIGN KEY (supplier_commitment_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_commitments(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_confirmation_commitment_links confirmation_commitment_links_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_commitment_links
    ADD CONSTRAINT confirmation_commitment_links_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_confirmation_identifier_links confirmation_identifier_links_confirmation_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_identifier_links
    ADD CONSTRAINT confirmation_identifier_links_confirmation_fk FOREIGN KEY (supplier_confirmation_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_confirmations(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_confirmation_identifier_links confirmation_identifier_links_target_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_identifier_links
    ADD CONSTRAINT confirmation_identifier_links_target_fk FOREIGN KEY (supplier_issued_identifier_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_issued_identifiers(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_confirmation_identifier_links confirmation_identifier_links_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_identifier_links
    ADD CONSTRAINT confirmation_identifier_links_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_confirmation_reservation_response_links confirmation_response_links_confirmation_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_reservation_response_links
    ADD CONSTRAINT confirmation_response_links_confirmation_fk FOREIGN KEY (supplier_confirmation_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_confirmations(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_confirmation_reservation_response_links confirmation_response_links_event_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_reservation_response_links
    ADD CONSTRAINT confirmation_response_links_event_fk FOREIGN KEY (supplier_reservation_event_id, supplier_reservation_revision_id, supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_reservation_events(id, supplier_reservation_revision_id, supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_confirmation_reservation_scope_links confirmation_scope_links_confirmation_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_reservation_scope_links
    ADD CONSTRAINT confirmation_scope_links_confirmation_fk FOREIGN KEY (supplier_confirmation_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_confirmations(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_confirmation_reservation_scope_links confirmation_scope_links_scope_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_reservation_scope_links
    ADD CONSTRAINT confirmation_scope_links_scope_fk FOREIGN KEY (supplier_reservation_scope_id, supplier_reservation_revision_id, supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_reservation_scopes(id, supplier_reservation_revision_id, supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_deadline_commitment_definition_lines deadline_commitment_lines_cost_component_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_commitment_definition_lines
    ADD CONSTRAINT deadline_commitment_lines_cost_component_fk FOREIGN KEY (supplier_cost_component_id, supplier_cost_definition_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_cost_components(id, supplier_cost_definition_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_deadline_commitment_definition_lines deadline_commitment_lines_cost_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_commitment_definition_lines
    ADD CONSTRAINT deadline_commitment_lines_cost_definition_fk FOREIGN KEY (supplier_cost_definition_id, supplier_cost_source_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_cost_definitions(id, supplier_cost_source_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_deadline_commitment_definition_lines deadline_commitment_lines_cost_source_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_commitment_definition_lines
    ADD CONSTRAINT deadline_commitment_lines_cost_source_fk FOREIGN KEY (supplier_cost_source_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_cost_sources(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_deadline_commitment_definition_lines deadline_commitment_lines_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_commitment_definition_lines
    ADD CONSTRAINT deadline_commitment_lines_definition_fk FOREIGN KEY (supplier_deadline_definition_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_deadline_definitions(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_deadline_commitment_definition_lines deadline_commitment_lines_supplier_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_commitment_definition_lines
    ADD CONSTRAINT deadline_commitment_lines_supplier_fk FOREIGN KEY (committed_supplier_id, agency_id) REFERENCES public.suppliers(id, agency_id);


--
-- Name: supplier_deadline_commitment_definition_lines deadline_commitment_lines_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_commitment_definition_lines
    ADD CONSTRAINT deadline_commitment_lines_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_deadline_definition_coverage_links deadline_coverage_item_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_definition_coverage_links
    ADD CONSTRAINT deadline_coverage_item_fk FOREIGN KEY (arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.arrangement_item_definitions(arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_deadline_definition_coverage_links deadline_coverage_links_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_definition_coverage_links
    ADD CONSTRAINT deadline_coverage_links_definition_fk FOREIGN KEY (supplier_deadline_definition_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_deadline_definitions(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_deadline_definition_coverage_links deadline_coverage_links_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_definition_coverage_links
    ADD CONSTRAINT deadline_coverage_links_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_deadline_definition_coverage_links deadline_coverage_occurrence_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_definition_coverage_links
    ADD CONSTRAINT deadline_coverage_occurrence_fk FOREIGN KEY (service_occurrence_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.service_occurrence_definitions(service_occurrence_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_deadline_definition_coverage_links deadline_coverage_pool_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_definition_coverage_links
    ADD CONSTRAINT deadline_coverage_pool_fk FOREIGN KEY (capacity_pool_id, service_occurrence_id, supplier_resource_id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.capacity_pools(id, service_occurrence_id, supplier_resource_id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_deadline_definition_coverage_links deadline_coverage_resource_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_definition_coverage_links
    ADD CONSTRAINT deadline_coverage_resource_fk FOREIGN KEY (supplier_resource_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_resource_definitions(supplier_resource_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_deadline_definitions deadline_definitions_copied_from_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_definitions
    ADD CONSTRAINT deadline_definitions_copied_from_fk FOREIGN KEY (copied_from_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_deadline_definitions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_deadline_definitions deadline_definitions_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_definitions
    ADD CONSTRAINT deadline_definitions_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_deadline_occurrences deadline_occurrences_activation_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_occurrences
    ADD CONSTRAINT deadline_occurrences_activation_fk FOREIGN KEY (supplier_arrangement_activation_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_activations(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_deadline_occurrences deadline_occurrences_actor_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_occurrences
    ADD CONSTRAINT deadline_occurrences_actor_fk FOREIGN KEY (actor_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: supplier_deadline_occurrences deadline_occurrences_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_occurrences
    ADD CONSTRAINT deadline_occurrences_definition_fk FOREIGN KEY (supplier_deadline_definition_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_deadline_definitions(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_deadline_occurrences deadline_occurrences_predecessor_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_occurrences
    ADD CONSTRAINT deadline_occurrences_predecessor_fk FOREIGN KEY (predecessor_occurrence_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_deadline_occurrences(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_deadline_occurrences deadline_occurrences_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_occurrences
    ADD CONSTRAINT deadline_occurrences_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_deadline_projections deadline_projections_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_projections
    ADD CONSTRAINT deadline_projections_agency_fk FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_deadline_projections deadline_projections_occurrence_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadline_projections
    ADD CONSTRAINT deadline_projections_occurrence_fk FOREIGN KEY (supplier_deadline_occurrence_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_deadline_occurrences(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: departures departures_agency_user_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departures
    ADD CONSTRAINT departures_agency_user_agency_fk FOREIGN KEY (responsible_agency_user_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: departures departures_office_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departures
    ADD CONSTRAINT departures_office_agency_fk FOREIGN KEY (responsible_office_id, agency_id) REFERENCES public.offices(id, agency_id);


--
-- Name: supplier_arrangements fk_rails_089363381e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangements
    ADD CONSTRAINT fk_rails_089363381e FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_confirmation_activation_links fk_rails_08aed1348e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_activation_links
    ADD CONSTRAINT fk_rails_08aed1348e FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_reservation_scopes fk_rails_0f150b102b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_scopes
    ADD CONSTRAINT fk_rails_0f150b102b FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: client_person_postal_addresses fk_rails_14e390d793; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_person_postal_addresses
    ADD CONSTRAINT fk_rails_14e390d793 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: capacity_pools fk_rails_19d5f960c4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pools
    ADD CONSTRAINT fk_rails_19d5f960c4 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_confirmation_reservation_response_links fk_rails_1c041b2616; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_reservation_response_links
    ADD CONSTRAINT fk_rails_1c041b2616 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_confirmations fk_rails_1d834ae4a2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmations
    ADD CONSTRAINT fk_rails_1d834ae4a2 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: client_organization_phone_numbers fk_rails_1f83ac8034; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_organization_phone_numbers
    ADD CONSTRAINT fk_rails_1f83ac8034 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: service_occurrences fk_rails_1f84c2293b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_occurrences
    ADD CONSTRAINT fk_rails_1f84c2293b FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_cost_sources fk_rails_1fe5bd76c2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_sources
    ADD CONSTRAINT fk_rails_1fe5bd76c2 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: arrangement_item_definitions fk_rails_21148f554b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arrangement_item_definitions
    ADD CONSTRAINT fk_rails_21148f554b FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: capacity_reconciliations fk_rails_28fe5e2cf2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_reconciliations
    ADD CONSTRAINT fk_rails_28fe5e2cf2 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_arrangement_versions fk_rails_2919e0612f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangement_versions
    ADD CONSTRAINT fk_rails_2919e0612f FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: offices fk_rails_29d71841aa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offices
    ADD CONSTRAINT fk_rails_29d71841aa FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_reservation_projections fk_rails_2a067fc225; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_projections
    ADD CONSTRAINT fk_rails_2a067fc225 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_cost_components fk_rails_2c6afdf08e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_components
    ADD CONSTRAINT fk_rails_2c6afdf08e FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_cost_occupancy_profiles fk_rails_2d6c909edf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_occupancy_profiles
    ADD CONSTRAINT fk_rails_2d6c909edf FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: capacity_projections fk_rails_308824deff; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_projections
    ADD CONSTRAINT fk_rails_308824deff FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_cost_definitions fk_rails_315fff7890; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_definitions
    ADD CONSTRAINT fk_rails_315fff7890 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_resource_definitions fk_rails_32a78d1b5b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_resource_definitions
    ADD CONSTRAINT fk_rails_32a78d1b5b FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_reservation_event_scope_outcomes fk_rails_35bd5035fb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_event_scope_outcomes
    ADD CONSTRAINT fk_rails_35bd5035fb FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_category_assignments fk_rails_3affd09c40; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_category_assignments
    ADD CONSTRAINT fk_rails_3affd09c40 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: client_organization_contacts fk_rails_3c145b85a0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_organization_contacts
    ADD CONSTRAINT fk_rails_3c145b85a0 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_commitments fk_rails_3c8531ba76; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT fk_rails_3c8531ba76 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: agency_command_idempotency_keys fk_rails_3ce67d3c6c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agency_command_idempotency_keys
    ADD CONSTRAINT fk_rails_3ce67d3c6c FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: client_organizations fk_rails_4e204305ef; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_organizations
    ADD CONSTRAINT fk_rails_4e204305ef FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: reference_sequences fk_rails_4fafc1651c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reference_sequences
    ADD CONSTRAINT fk_rails_4fafc1651c FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_arrangement_activations fk_rails_5bedb1c962; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangement_activations
    ADD CONSTRAINT fk_rails_5bedb1c962 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_confirmation_reservation_scope_links fk_rails_62fbdad473; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_reservation_scope_links
    ADD CONSTRAINT fk_rails_62fbdad473 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: capacity_reconciliation_resolutions fk_rails_6af96c37bf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_reconciliation_resolutions
    ADD CONSTRAINT fk_rails_6af96c37bf FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_commitment_trigger_definitions fk_rails_77637659d8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitment_trigger_definitions
    ADD CONSTRAINT fk_rails_77637659d8 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: client_organization_websites fk_rails_7b1ea3ba3f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_organization_websites
    ADD CONSTRAINT fk_rails_7b1ea3ba3f FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_websites fk_rails_800f8de757; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_websites
    ADD CONSTRAINT fk_rails_800f8de757 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: service_occurrence_definitions fk_rails_84fd108f14; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_occurrence_definitions
    ADD CONSTRAINT fk_rails_84fd108f14 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: audit_events fk_rails_8512cd9707; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT fk_rails_8512cd9707 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_cost_usage_assumptions fk_rails_89364bac36; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_usage_assumptions
    ADD CONSTRAINT fk_rails_89364bac36 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_cost_occupancy_profile_positions fk_rails_8df51be2b8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_occupancy_profile_positions
    ADD CONSTRAINT fk_rails_8df51be2b8 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_contacts fk_rails_8eda2b4f49; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_contacts
    ADD CONSTRAINT fk_rails_8eda2b4f49 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_issued_identifiers fk_rails_941feb8180; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_issued_identifiers
    ADD CONSTRAINT fk_rails_941feb8180 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_phone_numbers fk_rails_980d81234b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_phone_numbers
    ADD CONSTRAINT fk_rails_980d81234b FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: clients fk_rails_987104bb65; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT fk_rails_987104bb65 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: agency_users fk_rails_9b56937ae8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agency_users
    ADD CONSTRAINT fk_rails_9b56937ae8 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: capacity_events fk_rails_9c760ffc14; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_events
    ADD CONSTRAINT fk_rails_9c760ffc14 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: suppliers fk_rails_a0dd1fca19; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suppliers
    ADD CONSTRAINT fk_rails_a0dd1fca19 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_reservations fk_rails_a1b8a7498f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservations
    ADD CONSTRAINT fk_rails_a1b8a7498f FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_cost_component_bases fk_rails_a86750f564; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_component_bases
    ADD CONSTRAINT fk_rails_a86750f564 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_contact_phone_numbers fk_rails_a8cbb23af8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_contact_phone_numbers
    ADD CONSTRAINT fk_rails_a8cbb23af8 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_arrangement_activation_capacity_entries fk_rails_aea065218a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangement_activation_capacity_entries
    ADD CONSTRAINT fk_rails_aea065218a FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: client_organization_email_addresses fk_rails_b2180601e2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_organization_email_addresses
    ADD CONSTRAINT fk_rails_b2180601e2 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_confirmation_identifier_links fk_rails_c64abedabc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_identifier_links
    ADD CONSTRAINT fk_rails_c64abedabc FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: arrangement_item_setup_results fk_rails_c847b536e6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arrangement_item_setup_results
    ADD CONSTRAINT fk_rails_c847b536e6 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_postal_addresses fk_rails_c92f255d74; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_postal_addresses
    ADD CONSTRAINT fk_rails_c92f255d74 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: client_people fk_rails_ca3cbcb220; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_people
    ADD CONSTRAINT fk_rails_ca3cbcb220 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_confirmation_commitment_links fk_rails_cc85304ba7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_commitment_links
    ADD CONSTRAINT fk_rails_cc85304ba7 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_reservation_revisions fk_rails_d01e1a54e9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_revisions
    ADD CONSTRAINT fk_rails_d01e1a54e9 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: departures fk_rails_d0941bcf52; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departures
    ADD CONSTRAINT fk_rails_d0941bcf52 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: client_person_email_addresses fk_rails_d40f0804a1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_person_email_addresses
    ADD CONSTRAINT fk_rails_d40f0804a1 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_locations fk_rails_d4741615d4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_locations
    ADD CONSTRAINT fk_rails_d4741615d4 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_reservation_events fk_rails_d50274fa49; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_events
    ADD CONSTRAINT fk_rails_d50274fa49 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: client_organization_postal_addresses fk_rails_da4da8a391; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_organization_postal_addresses
    ADD CONSTRAINT fk_rails_da4da8a391 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_contact_email_addresses fk_rails_dc5a291124; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_contact_email_addresses
    ADD CONSTRAINT fk_rails_dc5a291124 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: arrangement_items fk_rails_de3260558a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arrangement_items
    ADD CONSTRAINT fk_rails_de3260558a FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_arrangement_activation_cost_selections fk_rails_e14cc8af4e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangement_activation_cost_selections
    ADD CONSTRAINT fk_rails_e14cc8af4e FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_confirmation_capacity_event_links fk_rails_e355d5452e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_capacity_event_links
    ADD CONSTRAINT fk_rails_e355d5452e FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_email_addresses fk_rails_e4b48618c0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_email_addresses
    ADD CONSTRAINT fk_rails_e4b48618c0 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: capacity_pair_definitions fk_rails_e840ad8189; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pair_definitions
    ADD CONSTRAINT fk_rails_e840ad8189 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_cost_participant_categories fk_rails_eaa89f9369; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_participant_categories
    ADD CONSTRAINT fk_rails_eaa89f9369 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: capacity_pool_definitions fk_rails_f2e9dce76c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pool_definitions
    ADD CONSTRAINT fk_rails_f2e9dce76c FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: client_person_phone_numbers fk_rails_f3401476d8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_person_phone_numbers
    ADD CONSTRAINT fk_rails_f3401476d8 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_resources fk_rails_f4555dab68; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_resources
    ADD CONSTRAINT fk_rails_f4555dab68 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: sessions fk_rails_fda020f2ca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_fda020f2ca FOREIGN KEY (agency_user_id) REFERENCES public.agency_users(id);


--
-- Name: arrangement_item_definitions item_definitions_copied_from_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arrangement_item_definitions
    ADD CONSTRAINT item_definitions_copied_from_fk FOREIGN KEY (copied_from_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.arrangement_item_definitions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: arrangement_item_setup_results item_setup_results_idempotency_key_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arrangement_item_setup_results
    ADD CONSTRAINT item_setup_results_idempotency_key_fk FOREIGN KEY (agency_command_idempotency_key_id, agency_id) REFERENCES public.agency_command_idempotency_keys(id, agency_id);


--
-- Name: arrangement_item_setup_results item_setup_results_item_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arrangement_item_setup_results
    ADD CONSTRAINT item_setup_results_item_fk FOREIGN KEY (arrangement_item_id, agency_id) REFERENCES public.arrangement_items(id, agency_id) ON DELETE CASCADE;


--
-- Name: arrangement_item_setup_results item_setup_results_occurrence_owner_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arrangement_item_setup_results
    ADD CONSTRAINT item_setup_results_occurrence_owner_fk FOREIGN KEY (service_occurrence_id, arrangement_item_id, agency_id) REFERENCES public.service_occurrences(id, arrangement_item_id, agency_id);


--
-- Name: arrangement_item_setup_results item_setup_results_resource_owner_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arrangement_item_setup_results
    ADD CONSTRAINT item_setup_results_resource_owner_fk FOREIGN KEY (supplier_resource_id, arrangement_item_id, agency_id) REFERENCES public.supplier_resources(id, arrangement_item_id, agency_id);


--
-- Name: service_occurrence_definitions occurrence_definitions_copied_from_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_occurrence_definitions
    ADD CONSTRAINT occurrence_definitions_copied_from_fk FOREIGN KEY (copied_from_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.service_occurrence_definitions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_reservation_events reservation_events_actor_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_events
    ADD CONSTRAINT reservation_events_actor_fk FOREIGN KEY (actor_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: supplier_reservation_events reservation_events_contact_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_events
    ADD CONSTRAINT reservation_events_contact_fk FOREIGN KEY (supplier_contact_id, agency_id) REFERENCES public.supplier_contacts(id, agency_id);


--
-- Name: supplier_reservation_events reservation_events_idempotency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_events
    ADD CONSTRAINT reservation_events_idempotency_fk FOREIGN KEY (agency_command_idempotency_key_id, agency_id) REFERENCES public.agency_command_idempotency_keys(id, agency_id);


--
-- Name: supplier_reservation_events reservation_events_revision_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_events
    ADD CONSTRAINT reservation_events_revision_fk FOREIGN KEY (supplier_reservation_revision_id, supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_reservation_revisions(id, supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_reservation_event_scope_outcomes reservation_outcomes_event_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_event_scope_outcomes
    ADD CONSTRAINT reservation_outcomes_event_fk FOREIGN KEY (supplier_reservation_event_id, supplier_reservation_revision_id, supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_reservation_events(id, supplier_reservation_revision_id, supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_reservation_event_scope_outcomes reservation_outcomes_scope_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_event_scope_outcomes
    ADD CONSTRAINT reservation_outcomes_scope_fk FOREIGN KEY (supplier_reservation_scope_id, supplier_reservation_revision_id, supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_reservation_scopes(id, supplier_reservation_revision_id, supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_reservation_projections reservation_projections_current_revision_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_projections
    ADD CONSTRAINT reservation_projections_current_revision_fk FOREIGN KEY (current_revision_id, supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_reservation_revisions(id, supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_reservation_projections reservation_projections_reservation_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_projections
    ADD CONSTRAINT reservation_projections_reservation_fk FOREIGN KEY (supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_reservations(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_confirmation_reservation_response_links reservation_response_links_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_reservation_response_links
    ADD CONSTRAINT reservation_response_links_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_reservation_revisions reservation_revisions_actor_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_revisions
    ADD CONSTRAINT reservation_revisions_actor_fk FOREIGN KEY (actor_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: supplier_reservation_revisions reservation_revisions_reservation_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_revisions
    ADD CONSTRAINT reservation_revisions_reservation_fk FOREIGN KEY (supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_reservations(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_reservation_revisions reservation_revisions_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_revisions
    ADD CONSTRAINT reservation_revisions_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_confirmation_reservation_scope_links reservation_scope_links_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmation_reservation_scope_links
    ADD CONSTRAINT reservation_scope_links_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_reservation_scopes reservation_scopes_capacity_pool_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_scopes
    ADD CONSTRAINT reservation_scopes_capacity_pool_fk FOREIGN KEY (capacity_pool_id, service_occurrence_id, supplier_resource_id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.capacity_pools(id, service_occurrence_id, supplier_resource_id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_reservation_scopes reservation_scopes_item_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_scopes
    ADD CONSTRAINT reservation_scopes_item_definition_fk FOREIGN KEY (arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.arrangement_item_definitions(arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_reservation_scopes reservation_scopes_occurrence_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_scopes
    ADD CONSTRAINT reservation_scopes_occurrence_definition_fk FOREIGN KEY (service_occurrence_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.service_occurrence_definitions(service_occurrence_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_reservation_scopes reservation_scopes_resource_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_scopes
    ADD CONSTRAINT reservation_scopes_resource_definition_fk FOREIGN KEY (supplier_resource_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_resource_definitions(supplier_resource_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_reservation_scopes reservation_scopes_revision_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_scopes
    ADD CONSTRAINT reservation_scopes_revision_fk FOREIGN KEY (supplier_reservation_revision_id, supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_reservation_revisions(id, supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_resource_definitions resource_definitions_copied_from_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_resource_definitions
    ADD CONSTRAINT resource_definitions_copied_from_fk FOREIGN KEY (copied_from_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_resource_definitions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: service_occurrence_definitions service_occurrence_definitions_occurrence_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_occurrence_definitions
    ADD CONSTRAINT service_occurrence_definitions_occurrence_fk FOREIGN KEY (service_occurrence_id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.service_occurrences(id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: service_occurrence_definitions service_occurrence_definitions_provider_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_occurrence_definitions
    ADD CONSTRAINT service_occurrence_definitions_provider_fk FOREIGN KEY (service_provider_id, agency_id) REFERENCES public.suppliers(id, agency_id);


--
-- Name: service_occurrence_definitions service_occurrence_definitions_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_occurrence_definitions
    ADD CONSTRAINT service_occurrence_definitions_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: service_occurrences service_occurrences_item_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_occurrences
    ADD CONSTRAINT service_occurrences_item_fk FOREIGN KEY (arrangement_item_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.arrangement_items(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: sessions sessions_office_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_office_fk FOREIGN KEY (office_id) REFERENCES public.offices(id);


--
-- Name: supplier_arrangement_versions supplier_arrangement_versions_arrangement_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangement_versions
    ADD CONSTRAINT supplier_arrangement_versions_arrangement_fk FOREIGN KEY (supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangements(id, departure_id, agency_id);


--
-- Name: supplier_arrangement_versions supplier_arrangement_versions_copied_from_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangement_versions
    ADD CONSTRAINT supplier_arrangement_versions_copied_from_fk FOREIGN KEY (copied_from_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_arrangements supplier_arrangements_contracting_contact_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangements
    ADD CONSTRAINT supplier_arrangements_contracting_contact_fk FOREIGN KEY (supplier_contact_id, contracting_supplier_id, agency_id) REFERENCES public.supplier_contacts(id, supplier_id, agency_id);


--
-- Name: supplier_arrangements supplier_arrangements_contracting_supplier_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangements
    ADD CONSTRAINT supplier_arrangements_contracting_supplier_fk FOREIGN KEY (contracting_supplier_id, agency_id) REFERENCES public.suppliers(id, agency_id);


--
-- Name: supplier_arrangements supplier_arrangements_departure_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangements
    ADD CONSTRAINT supplier_arrangements_departure_agency_fk FOREIGN KEY (departure_id, agency_id) REFERENCES public.departures(id, agency_id);


--
-- Name: supplier_arrangements supplier_arrangements_governing_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangements
    ADD CONSTRAINT supplier_arrangements_governing_version_fk FOREIGN KEY (governing_version_id, id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_category_assignments supplier_category_assignments_supplier_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_category_assignments
    ADD CONSTRAINT supplier_category_assignments_supplier_agency_fk FOREIGN KEY (supplier_id, agency_id) REFERENCES public.suppliers(id, agency_id);


--
-- Name: supplier_commitments supplier_commitments_activation_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_activation_fk FOREIGN KEY (supplier_arrangement_activation_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_activations(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitments supplier_commitments_actor_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_actor_fk FOREIGN KEY (actor_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: supplier_commitments supplier_commitments_capacity_pool_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_capacity_pool_fk FOREIGN KEY (capacity_pool_id, service_occurrence_id, supplier_resource_id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.capacity_pools(id, service_occurrence_id, supplier_resource_id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitments supplier_commitments_confirmation_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_confirmation_fk FOREIGN KEY (supplier_confirmation_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_confirmations(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitments supplier_commitments_cost_source_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_cost_source_fk FOREIGN KEY (supplier_cost_source_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_cost_sources(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitments supplier_commitments_deadline_line_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_deadline_line_fk FOREIGN KEY (supplier_deadline_commitment_definition_line_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_deadline_commitment_definition_lines(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitments supplier_commitments_deadline_occurrence_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_deadline_occurrence_fk FOREIGN KEY (supplier_deadline_occurrence_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_deadline_occurrences(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitments supplier_commitments_idempotency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_idempotency_fk FOREIGN KEY (agency_command_idempotency_key_id, agency_id) REFERENCES public.agency_command_idempotency_keys(id, agency_id);


--
-- Name: supplier_commitments supplier_commitments_item_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_item_definition_fk FOREIGN KEY (arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.arrangement_item_definitions(arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitments supplier_commitments_occurrence_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_occurrence_definition_fk FOREIGN KEY (service_occurrence_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.service_occurrence_definitions(service_occurrence_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitments supplier_commitments_reservation_event_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_reservation_event_fk FOREIGN KEY (supplier_reservation_event_id, supplier_reservation_revision_id, supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_reservation_events(id, supplier_reservation_revision_id, supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitments supplier_commitments_reservation_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_reservation_fk FOREIGN KEY (supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_reservations(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitments supplier_commitments_reservation_revision_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_reservation_revision_fk FOREIGN KEY (supplier_reservation_revision_id, supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_reservation_revisions(id, supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitments supplier_commitments_reservation_scope_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_reservation_scope_fk FOREIGN KEY (supplier_reservation_scope_id, supplier_reservation_revision_id, supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_reservation_scopes(id, supplier_reservation_revision_id, supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitments supplier_commitments_resource_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_resource_definition_fk FOREIGN KEY (supplier_resource_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_resource_definitions(supplier_resource_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitments supplier_commitments_supplier_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_supplier_fk FOREIGN KEY (committed_supplier_id, agency_id) REFERENCES public.suppliers(id, agency_id);


--
-- Name: supplier_commitments supplier_commitments_trigger_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_trigger_fk FOREIGN KEY (supplier_commitment_trigger_definition_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_commitment_trigger_definitions(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_commitments supplier_commitments_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_confirmations supplier_confirmations_actor_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmations
    ADD CONSTRAINT supplier_confirmations_actor_fk FOREIGN KEY (actor_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: supplier_confirmations supplier_confirmations_supplier_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmations
    ADD CONSTRAINT supplier_confirmations_supplier_fk FOREIGN KEY (confirming_supplier_id, agency_id) REFERENCES public.suppliers(id, agency_id);


--
-- Name: supplier_confirmations supplier_confirmations_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmations
    ADD CONSTRAINT supplier_confirmations_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_contact_email_addresses supplier_contact_email_addresses_contact_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_contact_email_addresses
    ADD CONSTRAINT supplier_contact_email_addresses_contact_agency_fk FOREIGN KEY (supplier_contact_id, agency_id) REFERENCES public.supplier_contacts(id, agency_id);


--
-- Name: supplier_contact_phone_numbers supplier_contact_phone_numbers_contact_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_contact_phone_numbers
    ADD CONSTRAINT supplier_contact_phone_numbers_contact_agency_fk FOREIGN KEY (supplier_contact_id, agency_id) REFERENCES public.supplier_contacts(id, agency_id);


--
-- Name: supplier_contacts supplier_contacts_supplier_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_contacts
    ADD CONSTRAINT supplier_contacts_supplier_agency_fk FOREIGN KEY (supplier_id, agency_id) REFERENCES public.suppliers(id, agency_id);


--
-- Name: supplier_cost_usage_assumptions supplier_cost_assumptions_copied_from_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_usage_assumptions
    ADD CONSTRAINT supplier_cost_assumptions_copied_from_fk FOREIGN KEY (copied_from_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_cost_usage_assumptions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_participant_categories supplier_cost_categories_copied_from_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_participant_categories
    ADD CONSTRAINT supplier_cost_categories_copied_from_fk FOREIGN KEY (copied_from_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_cost_participant_categories(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_component_bases supplier_cost_component_bases_base_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_component_bases
    ADD CONSTRAINT supplier_cost_component_bases_base_fk FOREIGN KEY (base_component_id, supplier_cost_definition_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_cost_components(id, supplier_cost_definition_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_component_bases supplier_cost_component_bases_component_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_component_bases
    ADD CONSTRAINT supplier_cost_component_bases_component_fk FOREIGN KEY (supplier_cost_component_id, supplier_cost_definition_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_cost_components(id, supplier_cost_definition_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_component_bases supplier_cost_component_bases_copied_from_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_component_bases
    ADD CONSTRAINT supplier_cost_component_bases_copied_from_fk FOREIGN KEY (copied_from_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_cost_component_bases(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_component_bases supplier_cost_component_bases_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_component_bases
    ADD CONSTRAINT supplier_cost_component_bases_definition_fk FOREIGN KEY (supplier_cost_definition_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_cost_definitions(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_components supplier_cost_components_category_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_components
    ADD CONSTRAINT supplier_cost_components_category_fk FOREIGN KEY (participant_category_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_cost_participant_categories(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_components supplier_cost_components_copied_from_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_components
    ADD CONSTRAINT supplier_cost_components_copied_from_fk FOREIGN KEY (copied_from_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_cost_components(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_components supplier_cost_components_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_components
    ADD CONSTRAINT supplier_cost_components_definition_fk FOREIGN KEY (supplier_cost_definition_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_cost_definitions(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_definitions supplier_cost_definitions_copied_from_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_definitions
    ADD CONSTRAINT supplier_cost_definitions_copied_from_fk FOREIGN KEY (copied_from_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_cost_definitions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_definitions supplier_cost_definitions_departure_currency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_definitions
    ADD CONSTRAINT supplier_cost_definitions_departure_currency_fk FOREIGN KEY (departure_id, agency_id, currency) REFERENCES public.departures(id, agency_id, operating_currency);


--
-- Name: supplier_cost_definitions supplier_cost_definitions_ready_actor_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_definitions
    ADD CONSTRAINT supplier_cost_definitions_ready_actor_fk FOREIGN KEY (forecast_ready_by_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: supplier_cost_definitions supplier_cost_definitions_source_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_definitions
    ADD CONSTRAINT supplier_cost_definitions_source_fk FOREIGN KEY (supplier_cost_source_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_cost_sources(id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_occupancy_profile_positions supplier_cost_occupancy_profile_positions_profile_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_occupancy_profile_positions
    ADD CONSTRAINT supplier_cost_occupancy_profile_positions_profile_fk FOREIGN KEY (supplier_cost_occupancy_profile_id, supplier_cost_usage_assumption_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_cost_occupancy_profiles(id, supplier_cost_usage_assumption_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_occupancy_profiles supplier_cost_occupancy_profiles_assumption_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_occupancy_profiles
    ADD CONSTRAINT supplier_cost_occupancy_profiles_assumption_fk FOREIGN KEY (supplier_cost_usage_assumption_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_cost_usage_assumptions(id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_participant_categories supplier_cost_participant_categories_item_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_participant_categories
    ADD CONSTRAINT supplier_cost_participant_categories_item_definition_fk FOREIGN KEY (arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.arrangement_item_definitions(arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_participant_categories supplier_cost_participant_categories_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_participant_categories
    ADD CONSTRAINT supplier_cost_participant_categories_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_occupancy_profile_positions supplier_cost_profile_positions_category_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_occupancy_profile_positions
    ADD CONSTRAINT supplier_cost_profile_positions_category_fk FOREIGN KEY (participant_category_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_cost_participant_categories(id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_occupancy_profile_positions supplier_cost_profile_positions_copied_from_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_occupancy_profile_positions
    ADD CONSTRAINT supplier_cost_profile_positions_copied_from_fk FOREIGN KEY (copied_from_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_cost_occupancy_profile_positions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_occupancy_profiles supplier_cost_profiles_copied_from_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_occupancy_profiles
    ADD CONSTRAINT supplier_cost_profiles_copied_from_fk FOREIGN KEY (copied_from_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_cost_occupancy_profiles(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_sources supplier_cost_sources_charging_supplier_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_sources
    ADD CONSTRAINT supplier_cost_sources_charging_supplier_fk FOREIGN KEY (charging_supplier_id, agency_id) REFERENCES public.suppliers(id, agency_id);


--
-- Name: supplier_cost_sources supplier_cost_sources_copied_from_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_sources
    ADD CONSTRAINT supplier_cost_sources_copied_from_fk FOREIGN KEY (copied_from_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_cost_sources(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_sources supplier_cost_sources_item_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_sources
    ADD CONSTRAINT supplier_cost_sources_item_definition_fk FOREIGN KEY (arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.arrangement_item_definitions(arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_sources supplier_cost_sources_occurrence_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_sources
    ADD CONSTRAINT supplier_cost_sources_occurrence_definition_fk FOREIGN KEY (service_occurrence_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.service_occurrence_definitions(service_occurrence_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_sources supplier_cost_sources_resource_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_sources
    ADD CONSTRAINT supplier_cost_sources_resource_definition_fk FOREIGN KEY (supplier_resource_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_resource_definitions(supplier_resource_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_sources supplier_cost_sources_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_sources
    ADD CONSTRAINT supplier_cost_sources_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_usage_assumptions supplier_cost_usage_assumptions_item_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_usage_assumptions
    ADD CONSTRAINT supplier_cost_usage_assumptions_item_definition_fk FOREIGN KEY (arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.arrangement_item_definitions(arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_usage_assumptions supplier_cost_usage_assumptions_occurrence_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_usage_assumptions
    ADD CONSTRAINT supplier_cost_usage_assumptions_occurrence_definition_fk FOREIGN KEY (service_occurrence_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.service_occurrence_definitions(service_occurrence_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_usage_assumptions supplier_cost_usage_assumptions_resource_definition_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_usage_assumptions
    ADD CONSTRAINT supplier_cost_usage_assumptions_resource_definition_fk FOREIGN KEY (supplier_resource_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_resource_definitions(supplier_resource_id, arrangement_item_id, supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_cost_usage_assumptions supplier_cost_usage_assumptions_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_usage_assumptions
    ADD CONSTRAINT supplier_cost_usage_assumptions_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_email_addresses supplier_email_addresses_supplier_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_email_addresses
    ADD CONSTRAINT supplier_email_addresses_supplier_agency_fk FOREIGN KEY (supplier_id, agency_id) REFERENCES public.suppliers(id, agency_id);


--
-- Name: supplier_issued_identifiers supplier_identifiers_arrangement_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_issued_identifiers
    ADD CONSTRAINT supplier_identifiers_arrangement_fk FOREIGN KEY (supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangements(id, departure_id, agency_id);


--
-- Name: supplier_issued_identifiers supplier_identifiers_first_confirmation_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_issued_identifiers
    ADD CONSTRAINT supplier_identifiers_first_confirmation_fk FOREIGN KEY (first_supplier_confirmation_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_confirmations(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_issued_identifiers supplier_identifiers_reservation_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_issued_identifiers
    ADD CONSTRAINT supplier_identifiers_reservation_fk FOREIGN KEY (supplier_reservation_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_reservations(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_issued_identifiers supplier_identifiers_supersedes_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_issued_identifiers
    ADD CONSTRAINT supplier_identifiers_supersedes_fk FOREIGN KEY (supersedes_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_issued_identifiers(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_issued_identifiers supplier_identifiers_supplier_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_issued_identifiers
    ADD CONSTRAINT supplier_identifiers_supplier_fk FOREIGN KEY (supplier_id, agency_id) REFERENCES public.suppliers(id, agency_id);


--
-- Name: supplier_locations supplier_locations_supplier_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_locations
    ADD CONSTRAINT supplier_locations_supplier_agency_fk FOREIGN KEY (supplier_id, agency_id) REFERENCES public.suppliers(id, agency_id);


--
-- Name: supplier_phone_numbers supplier_phone_numbers_supplier_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_phone_numbers
    ADD CONSTRAINT supplier_phone_numbers_supplier_agency_fk FOREIGN KEY (supplier_id, agency_id) REFERENCES public.suppliers(id, agency_id);


--
-- Name: supplier_postal_addresses supplier_postal_addresses_supplier_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_postal_addresses
    ADD CONSTRAINT supplier_postal_addresses_supplier_agency_fk FOREIGN KEY (supplier_id, agency_id) REFERENCES public.suppliers(id, agency_id);


--
-- Name: supplier_reservations supplier_reservations_arrangement_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservations
    ADD CONSTRAINT supplier_reservations_arrangement_fk FOREIGN KEY (supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangements(id, departure_id, agency_id);


--
-- Name: supplier_reservations supplier_reservations_booking_supplier_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservations
    ADD CONSTRAINT supplier_reservations_booking_supplier_fk FOREIGN KEY (booking_supplier_id, agency_id) REFERENCES public.suppliers(id, agency_id);


--
-- Name: supplier_resource_definitions supplier_resource_definitions_resource_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_resource_definitions
    ADD CONSTRAINT supplier_resource_definitions_resource_fk FOREIGN KEY (supplier_resource_id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_resources(id, arrangement_item_id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_resource_definitions supplier_resource_definitions_version_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_resource_definitions
    ADD CONSTRAINT supplier_resource_definitions_version_fk FOREIGN KEY (supplier_arrangement_version_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.supplier_arrangement_versions(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_resources supplier_resources_item_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_resources
    ADD CONSTRAINT supplier_resources_item_fk FOREIGN KEY (arrangement_item_id, supplier_arrangement_id, departure_id, agency_id) REFERENCES public.arrangement_items(id, supplier_arrangement_id, departure_id, agency_id);


--
-- Name: supplier_websites supplier_websites_supplier_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_websites
    ADD CONSTRAINT supplier_websites_supplier_agency_fk FOREIGN KEY (supplier_id, agency_id) REFERENCES public.suppliers(id, agency_id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260919120000'),
('20260919070000'),
('20260919060000'),
('20260919050000'),
('20260919040000'),
('20260918070000'),
('20260918060000'),
('20260918050000'),
('20260918040000'),
('20260918030000'),
('20260918020000'),
('20260918010000'),
('20260917232000'),
('20260917230500'),
('20260917230400'),
('20260917230300'),
('20260917230200'),
('20260917230100'),
('20260917230000'),
('20260917220000'),
('20260917150000'),
('20260917120000'),
('20260917100000'),
('20260916220000'),
('20260916210000'),
('20260916200000'),
('20260916140000'),
('20260916010000'),
('20260915120000'),
('20260915010000'),
('20260914200000'),
('20260914183000'),
('20260914150000'),
('20260914030000'),
('20260914020000'),
('20260914010000');

