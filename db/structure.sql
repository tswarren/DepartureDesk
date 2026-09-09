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
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: client_advisor_assignments_prevent_identity_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.client_advisor_assignments_prevent_identity_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.client_profile_id IS DISTINCT FROM OLD.client_profile_id
    OR NEW.advisor_membership_id IS DISTINCT FROM OLD.advisor_membership_id
    OR NEW.effective_from IS DISTINCT FROM OLD.effective_from THEN
    RAISE EXCEPTION 'advisor assignment identity cannot change';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: client_advisor_current_matches_open_assignment(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.client_advisor_current_matches_open_assignment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  target_profile_id uuid;
  pointer uuid;
  open_count integer;
  open_membership_id uuid;
BEGIN
  IF TG_TABLE_NAME = 'client_profiles' THEN
    target_profile_id := COALESCE(NEW.id, OLD.id);
  ELSE
    target_profile_id := COALESCE(NEW.client_profile_id, OLD.client_profile_id);
  END IF;

  SELECT primary_advisor_membership_id
    INTO pointer
    FROM client_profiles
    WHERE id = target_profile_id;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT COUNT(*)::integer
    INTO open_count
    FROM client_advisor_assignments
    WHERE client_profile_id = target_profile_id
      AND effective_until IS NULL;

  IF pointer IS NULL THEN
    IF COALESCE(open_count, 0) <> 0 THEN
      RAISE EXCEPTION 'current advisor must agree with open assignment history'
        USING ERRCODE = 'check_violation';
    END IF;
  ELSIF COALESCE(open_count, 0) <> 1 THEN
    RAISE EXCEPTION 'current advisor must agree with open assignment history'
      USING ERRCODE = 'check_violation';
  ELSE
    SELECT advisor_membership_id
      INTO STRICT open_membership_id
      FROM client_advisor_assignments
      WHERE client_profile_id = target_profile_id
        AND effective_until IS NULL;

    IF open_membership_id IS DISTINCT FROM pointer THEN
      RAISE EXCEPTION 'current advisor must agree with open assignment history'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  RETURN NULL;
END;
$$;


--
-- Name: departure_party_role_assert_one_primary(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.departure_party_role_assert_one_primary(target_departure_id uuid, target_role text) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  current_count integer;
  primary_count integer;
BEGIN
  SELECT COUNT(*)::integer,
         COUNT(*) FILTER (WHERE is_primary)::integer
    INTO current_count, primary_count
    FROM departure_party_role_assignments
    WHERE departure_id = target_departure_id
      AND role = target_role
      AND effective_until IS NULL;

  IF current_count > 0 AND primary_count <> 1 THEN
    RAISE EXCEPTION 'a role with current assignments must have exactly one primary'
      USING ERRCODE = 'check_violation';
  END IF;
END;
$$;


--
-- Name: departure_party_role_current_has_one_primary(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.departure_party_role_current_has_one_primary() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP <> 'DELETE' THEN
    PERFORM departure_party_role_assert_one_primary(NEW.departure_id, NEW.role);
  END IF;

  IF TG_OP = 'DELETE' OR (
    TG_OP = 'UPDATE'
    AND (
      OLD.departure_id IS DISTINCT FROM NEW.departure_id
      OR OLD.role IS DISTINCT FROM NEW.role
    )
  ) THEN
    PERFORM departure_party_role_assert_one_primary(OLD.departure_id, OLD.role);
  END IF;

  RETURN NULL;
END;
$$;


--
-- Name: external_identifiers_prevent_identity_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.external_identifiers_prevent_identity_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.party_id IS DISTINCT FROM OLD.party_id
    OR NEW.client_profile_id IS DISTINCT FROM OLD.client_profile_id
    OR NEW.supplier_profile_id IS DISTINCT FROM OLD.supplier_profile_id
    OR NEW.identifier_type IS DISTINCT FROM OLD.identifier_type
    OR NEW.issuer IS DISTINCT FROM OLD.issuer
    OR NEW.original_value IS DISTINCT FROM OLD.original_value
    OR NEW.normalized_value IS DISTINCT FROM OLD.normalized_value
    OR NEW.normalization_version IS DISTINCT FROM OLD.normalization_version
    OR NEW.source IS DISTINCT FROM OLD.source THEN
    RAISE EXCEPTION 'external identifier identity cannot change';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: parties_prevent_kind_or_agency_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.parties_prevent_kind_or_agency_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.party_kind IS DISTINCT FROM OLD.party_kind THEN
    RAISE EXCEPTION 'party kind cannot change';
  END IF;
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id THEN
    RAISE EXCEPTION 'party agency cannot change';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: party_contact_points_prevent_kind_or_agency_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.party_contact_points_prevent_kind_or_agency_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.contact_kind IS DISTINCT FROM OLD.contact_kind THEN
    RAISE EXCEPTION 'contact kind cannot change';
  END IF;
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id THEN
    RAISE EXCEPTION 'contact agency cannot change';
  END IF;
  IF NEW.party_id IS DISTINCT FROM OLD.party_id THEN
    RAISE EXCEPTION 'contact party cannot change';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: party_notes_prevent_body_or_identity_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.party_notes_prevent_body_or_identity_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.body IS DISTINCT FROM OLD.body THEN
    RAISE EXCEPTION 'note body cannot change';
  END IF;
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.party_id IS DISTINCT FROM OLD.party_id
    OR NEW.author_membership_id IS DISTINCT FROM OLD.author_membership_id
    OR NEW.visibility IS DISTINCT FROM OLD.visibility THEN
    RAISE EXCEPTION 'note identity cannot change';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: party_relationships_prevent_immutable_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.party_relationships_prevent_immutable_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.origin_party_id IS DISTINCT FROM OLD.origin_party_id
    OR NEW.related_party_id IS DISTINCT FROM OLD.related_party_id
    OR NEW.origin_party_kind IS DISTINCT FROM OLD.origin_party_kind
    OR NEW.related_party_kind IS DISTINCT FROM OLD.related_party_kind
    OR NEW.relationship_kind IS DISTINCT FROM OLD.relationship_kind THEN
    RAISE EXCEPTION 'relationship identity cannot change';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: prevent_audit_event_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_audit_event_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'audit_events are append-only';
END;
$$;


--
-- Name: prevent_supplier_capacity_event_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_supplier_capacity_event_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'supplier_capacity_events are append-only';
END;
$$;


--
-- Name: role_profiles_prevent_identity_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.role_profiles_prevent_identity_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.party_id IS DISTINCT FROM OLD.party_id
    OR NEW.party_kind IS DISTINCT FROM OLD.party_kind THEN
    RAISE EXCEPTION 'agency_id, party_id, and party_kind are immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: supplier_arrangements_prevent_cycle(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.supplier_arrangements_prevent_cycle() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.parent_arrangement_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.parent_arrangement_id = NEW.id THEN
    RAISE EXCEPTION 'supplier arrangement cannot parent itself' USING ERRCODE = '23514';
  END IF;

  IF EXISTS (
    WITH RECURSIVE ancestors(id, parent_arrangement_id) AS (
      SELECT id, parent_arrangement_id
      FROM supplier_arrangements
      WHERE id = NEW.parent_arrangement_id
        AND agency_id = NEW.agency_id
        AND office_id = NEW.office_id
        AND departure_id = NEW.departure_id
      UNION ALL
      SELECT parent.id, parent.parent_arrangement_id
      FROM supplier_arrangements parent
      JOIN ancestors child ON child.parent_arrangement_id = parent.id
      WHERE parent.agency_id = NEW.agency_id
        AND parent.office_id = NEW.office_id
        AND parent.departure_id = NEW.departure_id
    )
    SELECT 1 FROM ancestors WHERE id = NEW.id LIMIT 1
  ) THEN
    RAISE EXCEPTION 'supplier arrangement hierarchy cannot contain cycles' USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id uuid NOT NULL,
    blob_id uuid NOT NULL,
    created_at timestamp(6) with time zone NOT NULL
);


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) with time zone NOT NULL
);


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    blob_id uuid NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: agencies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agencies (
    id uuid DEFAULT uuidv7() NOT NULL,
    name character varying NOT NULL,
    default_timezone character varying DEFAULT 'UTC'::character varying NOT NULL,
    default_currency character varying(3) DEFAULT 'USD'::character varying NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    legal_name character varying,
    country_code character varying(2) DEFAULT 'US'::character varying NOT NULL,
    CONSTRAINT agencies_country_code_format CHECK (((country_code)::text ~ '^[A-Z]{2}$'::text)),
    CONSTRAINT agencies_currency_format CHECK (((default_currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT agencies_legal_name_null_or_not_blank CHECK (((legal_name IS NULL) OR (btrim((legal_name)::text) <> ''::text))),
    CONSTRAINT agencies_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT agencies_name_not_blank CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT agencies_status_valid CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('suspended'::character varying)::text, ('closed'::character varying)::text]))),
    CONSTRAINT agencies_timezone_not_blank CHECK ((btrim((default_timezone)::text) <> ''::text))
);


--
-- Name: agency_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agency_memberships (
    id uuid DEFAULT uuidv7() NOT NULL,
    user_id uuid NOT NULL,
    agency_id uuid NOT NULL,
    role character varying NOT NULL,
    status character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    invitation_version integer DEFAULT 0 NOT NULL,
    invitation_sent_at timestamp with time zone,
    person_party_id uuid NOT NULL,
    CONSTRAINT agency_memberships_invitation_version_nonnegative CHECK ((invitation_version >= 0)),
    CONSTRAINT agency_memberships_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT agency_memberships_role_valid CHECK (((role)::text = ANY (ARRAY[('staff'::character varying)::text, ('administrator'::character varying)::text]))),
    CONSTRAINT agency_memberships_status_valid CHECK (((status)::text = ANY (ARRAY[('invited'::character varying)::text, ('active'::character varying)::text, ('suspended'::character varying)::text, ('revoked'::character varying)::text])))
);


--
-- Name: agency_provisioning_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agency_provisioning_requests (
    id uuid DEFAULT uuidv7() NOT NULL,
    idempotency_key_digest character varying NOT NULL,
    intent_digest character varying NOT NULL,
    agency_id uuid NOT NULL,
    created_at timestamp(6) with time zone NOT NULL
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
-- Name: audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_events (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    actor_kind character varying NOT NULL,
    actor_user_id uuid,
    actor_identifier character varying,
    action character varying NOT NULL,
    subject_type character varying,
    subject_id uuid,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT audit_events_action_format CHECK (((action)::text ~ '^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*$'::text)),
    CONSTRAINT audit_events_actor_consistency CHECK (((((actor_kind)::text = 'user'::text) AND (actor_user_id IS NOT NULL) AND (actor_identifier IS NULL)) OR (((actor_kind)::text = 'system'::text) AND (actor_user_id IS NULL) AND (btrim((actor_identifier)::text) <> ''::text)))),
    CONSTRAINT audit_events_subject_consistency CHECK (((subject_type IS NULL) = (subject_id IS NULL)))
);


--
-- Name: client_advisor_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_advisor_assignments (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_profile_id uuid NOT NULL,
    advisor_membership_id uuid NOT NULL,
    effective_from date NOT NULL,
    effective_until date,
    ended_at timestamp with time zone,
    ended_by_membership_id uuid,
    ending_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT caa_ending_complete CHECK ((((ended_at IS NULL) AND (ended_by_membership_id IS NULL) AND (ending_reason IS NULL) AND (effective_until IS NULL)) OR ((ended_at IS NOT NULL) AND (ended_by_membership_id IS NOT NULL) AND (btrim((ending_reason)::text) <> ''::text) AND (effective_until IS NOT NULL)))),
    CONSTRAINT caa_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT caa_range_order CHECK (((effective_until IS NULL) OR (effective_until >= effective_from)))
);


--
-- Name: client_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_profiles (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    party_id uuid NOT NULL,
    party_kind character varying NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    party_status character varying,
    responsible_office_id uuid NOT NULL,
    responsible_office_status character varying,
    deactivated_at timestamp with time zone,
    deactivated_by_membership_id uuid,
    deactivation_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    primary_advisor_membership_id uuid,
    primary_advisor_membership_status character varying,
    communication_preference character varying DEFAULT 'no_preference'::character varying NOT NULL,
    servicing_restrictions text,
    billing_restrictions text,
    CONSTRAINT client_profiles_advisor_projection CHECK ((((primary_advisor_membership_id IS NULL) AND (primary_advisor_membership_status IS NULL)) OR ((primary_advisor_membership_id IS NOT NULL) AND ((primary_advisor_membership_status)::text = 'active'::text)))),
    CONSTRAINT client_profiles_billing_restrictions_length CHECK ((char_length(billing_restrictions) <= 2000)),
    CONSTRAINT client_profiles_communication_preference_valid CHECK (((communication_preference)::text = ANY ((ARRAY['no_preference'::character varying, 'email'::character varying, 'phone'::character varying, 'postal_mail'::character varying])::text[]))),
    CONSTRAINT client_profiles_lifecycle_and_status_projections CHECK (((((status)::text = 'active'::text) AND (party_status IS NOT NULL) AND ((party_status)::text = 'active'::text) AND (responsible_office_status IS NOT NULL) AND ((responsible_office_status)::text = 'active'::text) AND (deactivated_at IS NULL) AND (deactivated_by_membership_id IS NULL) AND (deactivation_reason IS NULL)) OR (((status)::text = 'inactive'::text) AND (party_status IS NULL) AND (responsible_office_status IS NULL) AND (primary_advisor_membership_id IS NULL) AND (primary_advisor_membership_status IS NULL) AND (deactivated_at IS NOT NULL) AND (deactivated_by_membership_id IS NOT NULL) AND (btrim((deactivation_reason)::text) <> ''::text)))),
    CONSTRAINT client_profiles_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT client_profiles_party_kind_valid CHECK (((party_kind)::text = ANY ((ARRAY['person'::character varying, 'household'::character varying, 'organization'::character varying])::text[]))),
    CONSTRAINT client_profiles_servicing_restrictions_length CHECK ((char_length(servicing_restrictions) <= 2000)),
    CONSTRAINT client_profiles_status_valid CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
);


--
-- Name: contact_point_purpose_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contact_point_purpose_assignments (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    party_id uuid NOT NULL,
    contact_point_id uuid NOT NULL,
    contact_kind character varying NOT NULL,
    purpose character varying NOT NULL,
    priority integer NOT NULL,
    effective_from date,
    effective_until date,
    record_status character varying DEFAULT 'valid'::character varying NOT NULL,
    superseded_by_assignment_id uuid,
    corrected_at timestamp with time zone,
    corrected_by_membership_id uuid,
    correction_reason character varying,
    ended_at timestamp with time zone,
    ended_by_membership_id uuid,
    ending_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT contact_point_purpose_assignments_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT contact_point_purpose_assignments_priority_positive CHECK ((priority >= 1)),
    CONSTRAINT contact_point_purpose_assignments_purpose_valid CHECK (((purpose)::text = ANY (ARRAY[('general'::character varying)::text, ('correspondence'::character varying)::text, ('billing'::character varying)::text]))),
    CONSTRAINT contact_point_purpose_assignments_range_order CHECK (((effective_until IS NULL) OR (effective_from IS NULL) OR (effective_until > effective_from))),
    CONSTRAINT contact_point_purpose_assignments_record_status_valid CHECK (((record_status)::text = ANY (ARRAY[('valid'::character varying)::text, ('superseded'::character varying)::text, ('voided'::character varying)::text]))),
    CONSTRAINT cppa_disposition_matches_status CHECK (((((record_status)::text = 'valid'::text) AND (superseded_by_assignment_id IS NULL) AND (corrected_at IS NULL) AND (corrected_by_membership_id IS NULL) AND (correction_reason IS NULL)) OR (((record_status)::text = 'superseded'::text) AND (superseded_by_assignment_id IS NOT NULL) AND (corrected_at IS NOT NULL) AND (corrected_by_membership_id IS NOT NULL) AND (btrim((correction_reason)::text) <> ''::text)) OR (((record_status)::text = 'voided'::text) AND (corrected_at IS NOT NULL) AND (corrected_by_membership_id IS NOT NULL) AND (btrim((correction_reason)::text) <> ''::text)))),
    CONSTRAINT cppa_ending_complete CHECK ((((ended_at IS NULL) AND (ended_by_membership_id IS NULL) AND (ending_reason IS NULL)) OR ((ended_at IS NOT NULL) AND (ended_by_membership_id IS NOT NULL) AND (btrim((ending_reason)::text) <> ''::text) AND (effective_until IS NOT NULL))))
);


--
-- Name: delivery_intents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.delivery_intents (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid,
    subject_type character varying NOT NULL,
    subject_id uuid NOT NULL,
    purpose character varying NOT NULL,
    subject_version integer NOT NULL,
    idempotency_key character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    attempt_count integer DEFAULT 0 NOT NULL,
    available_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    claimed_at timestamp with time zone,
    delivered_at timestamp with time zone,
    last_error text,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT delivery_intents_counts_nonnegative CHECK (((attempt_count >= 0) AND (subject_version >= 0))),
    CONSTRAINT delivery_intents_purpose_valid CHECK (((purpose)::text = ANY (ARRAY[('team_invitation'::character varying)::text, ('password_reset'::character varying)::text]))),
    CONSTRAINT delivery_intents_status_valid CHECK (((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('processing'::character varying)::text, ('succeeded'::character varying)::text, ('discarded'::character varying)::text]))),
    CONSTRAINT delivery_intents_success_has_delivery_time CHECK (((((status)::text = 'succeeded'::text) AND (delivered_at IS NOT NULL)) OR (((status)::text <> 'succeeded'::text) AND (delivered_at IS NULL))))
);


--
-- Name: departure_party_role_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.departure_party_role_assignments (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    party_id uuid NOT NULL,
    party_kind character varying NOT NULL,
    role character varying NOT NULL,
    party_display_name_snapshot character varying CONSTRAINT departure_party_role_assign_party_display_name_snapsho_not_null NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    effective_from date NOT NULL,
    effective_until date,
    assigned_at timestamp with time zone NOT NULL,
    assigned_by_membership_id uuid CONSTRAINT departure_party_role_assignm_assigned_by_membership_id_not_null NOT NULL,
    ended_at timestamp with time zone,
    ended_by_membership_id uuid,
    ending_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT dpra_group_leader_person CHECK ((((role)::text <> 'group_leader'::text) OR ((party_kind)::text = 'person'::text))),
    CONSTRAINT dpra_lifecycle_complete CHECK ((((effective_until IS NULL) AND (ended_at IS NULL) AND (ended_by_membership_id IS NULL) AND (ending_reason IS NULL)) OR ((effective_until IS NOT NULL) AND (ended_at IS NOT NULL) AND (ended_by_membership_id IS NOT NULL) AND (btrim((ending_reason)::text) <> ''::text)))),
    CONSTRAINT dpra_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT dpra_party_kind_valid CHECK (((party_kind)::text = ANY ((ARRAY['person'::character varying, 'household'::character varying, 'organization'::character varying])::text[]))),
    CONSTRAINT dpra_range_order CHECK (((effective_until IS NULL) OR (effective_until >= effective_from))),
    CONSTRAINT dpra_role_valid CHECK (((role)::text = ANY ((ARRAY['organizer'::character varying, 'group_leader'::character varying, 'sponsor'::character varying])::text[]))),
    CONSTRAINT dpra_snapshot_not_blank CHECK ((btrim((party_display_name_snapshot)::text) <> ''::text))
);


--
-- Name: departure_reference_counters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.departure_reference_counters (
    agency_id uuid NOT NULL,
    last_value bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT drc_last_value_nonnegative CHECK ((last_value >= 0))
);


--
-- Name: departure_team_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.departure_team_assignments (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    agency_membership_id uuid NOT NULL,
    membership_status character varying,
    assignment_role character varying NOT NULL,
    member_name_snapshot character varying NOT NULL,
    effective_from date NOT NULL,
    effective_until date,
    assigned_at timestamp with time zone NOT NULL,
    assigned_by_membership_id uuid NOT NULL,
    ended_at timestamp with time zone,
    ended_by_membership_id uuid,
    ending_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT dta_lifecycle_complete CHECK ((((effective_until IS NULL) AND (ended_at IS NULL) AND (ended_by_membership_id IS NULL) AND (ending_reason IS NULL) AND ((membership_status)::text = 'active'::text)) OR ((effective_until IS NOT NULL) AND (ended_at IS NOT NULL) AND (ended_by_membership_id IS NOT NULL) AND (btrim((ending_reason)::text) <> ''::text) AND (membership_status IS NULL)))),
    CONSTRAINT dta_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT dta_range_order CHECK (((effective_until IS NULL) OR (effective_until >= effective_from))),
    CONSTRAINT dta_role_valid CHECK (((assignment_role)::text = ANY ((ARRAY['group_manager'::character varying, 'responsible_advisor'::character varying])::text[]))),
    CONSTRAINT dta_snapshot_not_blank CHECK ((btrim((member_name_snapshot)::text) <> ''::text))
);


--
-- Name: departures; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.departures (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    office_id uuid NOT NULL,
    owning_office_status character varying,
    travel_program_id uuid,
    travel_program_status character varying,
    departure_reference character varying NOT NULL,
    creation_idempotency_key uuid NOT NULL,
    name character varying NOT NULL,
    description text,
    client_facing_description text,
    primary_destination character varying,
    start_date date NOT NULL,
    end_date date NOT NULL,
    sales_open_on date,
    sales_close_on date,
    default_currency character varying(3) NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    created_by_membership_id uuid NOT NULL,
    status_changed_at timestamp with time zone NOT NULL,
    status_changed_by_membership_id uuid NOT NULL,
    status_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT departures_currency_format CHECK (((default_currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT departures_date_order CHECK ((end_date >= start_date)),
    CONSTRAINT departures_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT departures_name_not_blank CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT departures_owning_office_projection CHECK (((((status)::text = ANY ((ARRAY['draft'::character varying, 'planning'::character varying])::text[])) AND (owning_office_status IS NOT NULL) AND ((owning_office_status)::text = 'active'::text)) OR (((status)::text = 'cancelled'::text) AND (owning_office_status IS NULL)))),
    CONSTRAINT departures_program_projection CHECK ((((travel_program_id IS NULL) AND (travel_program_status IS NULL)) OR ((travel_program_id IS NOT NULL) AND ((status)::text = ANY ((ARRAY['draft'::character varying, 'planning'::character varying])::text[])) AND (travel_program_status IS NOT NULL) AND ((travel_program_status)::text = 'active'::text)) OR ((travel_program_id IS NOT NULL) AND ((status)::text = 'cancelled'::text) AND (travel_program_status IS NULL)))),
    CONSTRAINT departures_reference_format CHECK (((departure_reference)::text ~ '^D-[0-9]{6,}$'::text)),
    CONSTRAINT departures_sales_date_order CHECK (((sales_open_on IS NULL) OR (sales_close_on IS NULL) OR (sales_close_on >= sales_open_on))),
    CONSTRAINT departures_status_metadata CHECK (((((status)::text = 'cancelled'::text) AND (btrim((status_reason)::text) <> ''::text)) OR (((status)::text = ANY ((ARRAY['draft'::character varying, 'planning'::character varying])::text[])) AND (status_reason IS NULL)))),
    CONSTRAINT departures_status_valid CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'planning'::character varying, 'cancelled'::character varying])::text[])))
);


--
-- Name: external_identifiers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.external_identifiers (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    party_id uuid,
    client_profile_id uuid,
    supplier_profile_id uuid,
    office_id uuid,
    identifier_type character varying NOT NULL,
    issuer character varying,
    original_value character varying NOT NULL,
    normalized_value character varying NOT NULL,
    normalization_version integer NOT NULL,
    status character varying NOT NULL,
    source character varying NOT NULL,
    deactivated_at timestamp with time zone,
    deactivated_by_membership_id uuid,
    deactivation_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT external_identifiers_exactly_one_owner CHECK ((((((party_id IS NOT NULL))::integer + ((client_profile_id IS NOT NULL))::integer) + ((supplier_profile_id IS NOT NULL))::integer) = 1)),
    CONSTRAINT external_identifiers_issuer_required CHECK ((((identifier_type)::text <> ALL ((ARRAY['legacy_client_id'::character varying, 'external_crm_id'::character varying, 'supplier_account_number'::character varying, 'supplier_portal_id'::character varying, 'industry_supplier_code'::character varying])::text[])) OR ((issuer IS NOT NULL) AND (btrim((issuer)::text) <> ''::text)))),
    CONSTRAINT external_identifiers_lifecycle CHECK (((((status)::text = 'active'::text) AND (deactivated_at IS NULL) AND (deactivated_by_membership_id IS NULL) AND (deactivation_reason IS NULL)) OR (((status)::text = 'inactive'::text) AND (deactivated_at IS NOT NULL) AND (deactivated_by_membership_id IS NOT NULL) AND (btrim((deactivation_reason)::text) <> ''::text)))),
    CONSTRAINT external_identifiers_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT external_identifiers_office_id_null CHECK ((office_id IS NULL)),
    CONSTRAINT external_identifiers_source_valid CHECK (((source)::text = 'staff'::text)),
    CONSTRAINT external_identifiers_status_valid CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[]))),
    CONSTRAINT external_identifiers_type_owner CHECK (((((identifier_type)::text = 'legacy_party_id'::text) AND (party_id IS NOT NULL) AND (client_profile_id IS NULL) AND (supplier_profile_id IS NULL)) OR (((identifier_type)::text = ANY ((ARRAY['legacy_client_id'::character varying, 'external_crm_id'::character varying])::text[])) AND (client_profile_id IS NOT NULL) AND (party_id IS NULL) AND (supplier_profile_id IS NULL)) OR (((identifier_type)::text = ANY ((ARRAY['supplier_account_number'::character varying, 'supplier_portal_id'::character varying, 'industry_supplier_code'::character varying])::text[])) AND (supplier_profile_id IS NOT NULL) AND (party_id IS NULL) AND (client_profile_id IS NULL)))),
    CONSTRAINT external_identifiers_values_not_blank CHECK (((btrim((original_value)::text) <> ''::text) AND (btrim((normalized_value)::text) <> ''::text)))
);


--
-- Name: households; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.households (
    party_id uuid NOT NULL,
    agency_id uuid NOT NULL,
    name character varying NOT NULL,
    correspondence_name character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    party_kind character varying DEFAULT 'household'::character varying NOT NULL,
    CONSTRAINT households_correspondence_name_null_or_not_blank CHECK (((correspondence_name IS NULL) OR (btrim((correspondence_name)::text) <> ''::text))),
    CONSTRAINT households_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT households_name_not_blank CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT households_party_kind_household CHECK (((party_kind)::text = 'household'::text))
);


--
-- Name: office_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.office_assignments (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    agency_membership_id uuid NOT NULL,
    office_id uuid NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    granted_at timestamp with time zone NOT NULL,
    revoked_at timestamp with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT office_assignments_default_only_when_active CHECK (((is_default = false) OR ((status)::text = 'active'::text))),
    CONSTRAINT office_assignments_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT office_assignments_revoked_at_matches_status CHECK (((((status)::text = 'active'::text) AND (revoked_at IS NULL)) OR (((status)::text = 'revoked'::text) AND (revoked_at IS NOT NULL)))),
    CONSTRAINT office_assignments_status_valid CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('revoked'::character varying)::text])))
);


--
-- Name: offices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offices (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    name character varying NOT NULL,
    code character varying(10) NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    default_timezone character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT offices_code_format CHECK (((code)::text ~ '^[A-Z][A-Z0-9]{1,9}$'::text)),
    CONSTRAINT offices_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT offices_name_not_blank CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT offices_status_valid CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('inactive'::character varying)::text]))),
    CONSTRAINT offices_timezone_not_blank CHECK ((btrim((default_timezone)::text) <> ''::text))
);


--
-- Name: organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organizations (
    party_id uuid NOT NULL,
    agency_id uuid NOT NULL,
    legal_name character varying NOT NULL,
    trading_name character varying,
    website character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    party_kind character varying DEFAULT 'organization'::character varying NOT NULL,
    CONSTRAINT organizations_legal_name_not_blank CHECK ((btrim((legal_name)::text) <> ''::text)),
    CONSTRAINT organizations_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT organizations_party_kind_organization CHECK (((party_kind)::text = 'organization'::text)),
    CONSTRAINT organizations_trading_name_null_or_not_blank CHECK (((trading_name IS NULL) OR (btrim((trading_name)::text) <> ''::text))),
    CONSTRAINT organizations_website_null_or_not_blank CHECK (((website IS NULL) OR (btrim((website)::text) <> ''::text)))
);


--
-- Name: parties; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.parties (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    party_kind character varying NOT NULL,
    display_name character varying NOT NULL,
    sort_name character varying NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    deactivated_at timestamp with time zone,
    deactivated_by_membership_id uuid,
    deactivation_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT parties_deactivation_matches_status CHECK (((((status)::text = 'active'::text) AND (deactivated_at IS NULL) AND (deactivated_by_membership_id IS NULL) AND (deactivation_reason IS NULL)) OR (((status)::text = 'deactivated'::text) AND (deactivated_at IS NOT NULL) AND (deactivated_by_membership_id IS NOT NULL) AND (btrim((deactivation_reason)::text) <> ''::text)))),
    CONSTRAINT parties_display_name_not_blank CHECK ((btrim((display_name)::text) <> ''::text)),
    CONSTRAINT parties_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT parties_party_kind_valid CHECK (((party_kind)::text = ANY (ARRAY[('person'::character varying)::text, ('household'::character varying)::text, ('organization'::character varying)::text]))),
    CONSTRAINT parties_sort_name_not_blank CHECK ((btrim((sort_name)::text) <> ''::text)),
    CONSTRAINT parties_status_valid CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('deactivated'::character varying)::text])))
);


--
-- Name: party_alternate_names; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.party_alternate_names (
    id uuid DEFAULT uuidv7() NOT NULL,
    party_id uuid NOT NULL,
    agency_id uuid NOT NULL,
    name_kind character varying NOT NULL,
    name character varying NOT NULL,
    normalized_name character varying NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    removed_by_membership_id uuid,
    removed_at timestamp with time zone,
    CONSTRAINT party_alternate_names_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT party_alternate_names_name_kind_valid CHECK (((name_kind)::text = ANY (ARRAY[('former_name'::character varying)::text, ('alias'::character varying)::text, ('additional_trading_name'::character varying)::text, ('acronym'::character varying)::text, ('imported_name'::character varying)::text]))),
    CONSTRAINT party_alternate_names_name_not_blank CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT party_alternate_names_normalized_name_not_blank CHECK ((btrim((normalized_name)::text) <> ''::text)),
    CONSTRAINT party_alternate_names_removal_matches_status CHECK (((((status)::text = 'active'::text) AND (removed_at IS NULL) AND (removed_by_membership_id IS NULL)) OR (((status)::text = 'removed'::text) AND (removed_at IS NOT NULL) AND (removed_by_membership_id IS NOT NULL)))),
    CONSTRAINT party_alternate_names_status_valid CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('removed'::character varying)::text])))
);


--
-- Name: party_contact_points; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.party_contact_points (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    party_id uuid NOT NULL,
    contact_kind character varying NOT NULL,
    label character varying,
    normalized_value character varying NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    deactivated_at timestamp with time zone,
    deactivated_by_membership_id uuid,
    deactivation_reason character varying,
    suppressed_at timestamp with time zone,
    suppressed_by_membership_id uuid,
    suppression_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT party_contact_points_contact_kind_valid CHECK (((contact_kind)::text = ANY (ARRAY[('postal_address'::character varying)::text, ('phone'::character varying)::text, ('email'::character varying)::text]))),
    CONSTRAINT party_contact_points_deactivation_matches_status CHECK (((((status)::text = 'active'::text) AND (deactivated_at IS NULL) AND (deactivated_by_membership_id IS NULL) AND (deactivation_reason IS NULL)) OR (((status)::text = 'deactivated'::text) AND (deactivated_at IS NOT NULL) AND (deactivated_by_membership_id IS NOT NULL) AND (btrim((deactivation_reason)::text) <> ''::text)))),
    CONSTRAINT party_contact_points_label_null_or_not_blank CHECK (((label IS NULL) OR (btrim((label)::text) <> ''::text))),
    CONSTRAINT party_contact_points_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT party_contact_points_normalized_value_not_blank CHECK ((btrim((normalized_value)::text) <> ''::text)),
    CONSTRAINT party_contact_points_status_valid CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('deactivated'::character varying)::text]))),
    CONSTRAINT party_contact_points_suppression_complete CHECK ((((suppressed_at IS NULL) AND (suppressed_by_membership_id IS NULL) AND (suppression_reason IS NULL)) OR ((suppressed_at IS NOT NULL) AND (suppressed_by_membership_id IS NOT NULL) AND (btrim((suppression_reason)::text) <> ''::text))))
);


--
-- Name: party_email_addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.party_email_addresses (
    contact_point_id uuid NOT NULL,
    agency_id uuid NOT NULL,
    contact_kind character varying DEFAULT 'email'::character varying NOT NULL,
    display_address character varying NOT NULL,
    normalized_address character varying NOT NULL,
    email_type character varying NOT NULL,
    normalization_version integer DEFAULT 1 NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT party_email_addresses_contact_kind_email CHECK (((contact_kind)::text = 'email'::text)),
    CONSTRAINT party_email_addresses_display_address_not_blank CHECK ((btrim((display_address)::text) <> ''::text)),
    CONSTRAINT party_email_addresses_email_type_valid CHECK (((email_type)::text = ANY (ARRAY[('personal'::character varying)::text, ('work'::character varying)::text, ('general'::character varying)::text, ('booking'::character varying)::text, ('accounting'::character varying)::text, ('other'::character varying)::text]))),
    CONSTRAINT party_email_addresses_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT party_email_addresses_normalized_address_not_blank CHECK ((btrim((normalized_address)::text) <> ''::text))
);


--
-- Name: party_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.party_notes (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    party_id uuid NOT NULL,
    author_membership_id uuid NOT NULL,
    body text NOT NULL,
    visibility character varying NOT NULL,
    pinned boolean DEFAULT false NOT NULL,
    record_status character varying DEFAULT 'active'::character varying NOT NULL,
    superseded_by_note_id uuid,
    corrected_at timestamp with time zone,
    corrected_by_membership_id uuid,
    correction_reason character varying,
    removed_at timestamp with time zone,
    removed_by_membership_id uuid,
    removal_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT party_notes_body_not_blank CHECK ((btrim(body) <> ''::text)),
    CONSTRAINT party_notes_disposition_matches_status CHECK (((((record_status)::text = 'active'::text) AND (superseded_by_note_id IS NULL) AND (corrected_at IS NULL) AND (corrected_by_membership_id IS NULL) AND (correction_reason IS NULL) AND (removed_at IS NULL) AND (removed_by_membership_id IS NULL) AND (removal_reason IS NULL)) OR (((record_status)::text = 'superseded'::text) AND (superseded_by_note_id IS NOT NULL) AND (corrected_at IS NOT NULL) AND (corrected_by_membership_id IS NOT NULL) AND (btrim((correction_reason)::text) <> ''::text) AND (removed_at IS NULL) AND (removed_by_membership_id IS NULL) AND (removal_reason IS NULL)) OR (((record_status)::text = 'removed'::text) AND (removed_at IS NOT NULL) AND (removed_by_membership_id IS NOT NULL) AND (btrim((removal_reason)::text) <> ''::text)))),
    CONSTRAINT party_notes_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT party_notes_no_self_supersession CHECK (((superseded_by_note_id IS NULL) OR (superseded_by_note_id <> id))),
    CONSTRAINT party_notes_record_status_valid CHECK (((record_status)::text = ANY (ARRAY[('active'::character varying)::text, ('superseded'::character varying)::text, ('removed'::character varying)::text]))),
    CONSTRAINT party_notes_visibility_valid CHECK (((visibility)::text = ANY (ARRAY[('standard'::character varying)::text, ('administrator_only'::character varying)::text])))
);


--
-- Name: party_phone_numbers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.party_phone_numbers (
    contact_point_id uuid NOT NULL,
    agency_id uuid NOT NULL,
    contact_kind character varying DEFAULT 'phone'::character varying NOT NULL,
    display_number character varying NOT NULL,
    normalized_digits character varying NOT NULL,
    e164_number character varying,
    extension character varying,
    phone_type character varying NOT NULL,
    parsed_country_code character varying(2),
    parse_status character varying NOT NULL,
    normalization_version integer DEFAULT 1 NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT party_phone_numbers_contact_kind_phone CHECK (((contact_kind)::text = 'phone'::text)),
    CONSTRAINT party_phone_numbers_display_number_not_blank CHECK ((btrim((display_number)::text) <> ''::text)),
    CONSTRAINT party_phone_numbers_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT party_phone_numbers_normalized_digits_not_blank CHECK ((btrim((normalized_digits)::text) <> ''::text)),
    CONSTRAINT party_phone_numbers_parse_status_valid CHECK (((parse_status)::text = ANY (ARRAY[('valid'::character varying)::text, ('possible'::character varying)::text, ('unparsed'::character varying)::text]))),
    CONSTRAINT party_phone_numbers_parsed_country_code_format CHECK (((parsed_country_code IS NULL) OR ((parsed_country_code)::text ~ '^[A-Z]{2}$'::text))),
    CONSTRAINT party_phone_numbers_phone_type_valid CHECK (((phone_type)::text = ANY (ARRAY[('mobile'::character varying)::text, ('home'::character varying)::text, ('work'::character varying)::text, ('main'::character varying)::text, ('fax'::character varying)::text, ('other'::character varying)::text])))
);


--
-- Name: party_postal_addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.party_postal_addresses (
    contact_point_id uuid NOT NULL,
    agency_id uuid NOT NULL,
    contact_kind character varying DEFAULT 'postal_address'::character varying NOT NULL,
    attention character varying,
    address_line_1 character varying NOT NULL,
    address_line_2 character varying,
    address_line_3 character varying,
    locality character varying,
    administrative_region character varying,
    postal_code character varying,
    country_code character varying(2) NOT NULL,
    formatted_address character varying NOT NULL,
    normalized_address character varying NOT NULL,
    normalization_version integer DEFAULT 1 NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT party_postal_addresses_address_line_1_not_blank CHECK ((btrim((address_line_1)::text) <> ''::text)),
    CONSTRAINT party_postal_addresses_contact_kind_postal_address CHECK (((contact_kind)::text = 'postal_address'::text)),
    CONSTRAINT party_postal_addresses_country_code_format CHECK (((country_code)::text ~ '^[A-Z]{2}$'::text)),
    CONSTRAINT party_postal_addresses_lock_version_nonnegative CHECK ((lock_version >= 0))
);


--
-- Name: party_relationships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.party_relationships (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    origin_party_id uuid NOT NULL,
    origin_party_kind character varying NOT NULL,
    related_party_id uuid NOT NULL,
    related_party_kind character varying NOT NULL,
    relationship_kind character varying NOT NULL,
    relationship_label character varying,
    title character varying,
    effective_from date,
    effective_until date,
    record_status character varying DEFAULT 'valid'::character varying NOT NULL,
    superseded_by_relationship_id uuid,
    corrected_at timestamp with time zone,
    corrected_by_membership_id uuid,
    correction_reason character varying,
    ended_at timestamp with time zone,
    ended_by_membership_id uuid,
    ending_reason character varying,
    source character varying,
    notes character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT party_relationships_kind_pair_valid CHECK (((((relationship_kind)::text = 'household_member'::text) AND ((origin_party_kind)::text = 'person'::text) AND ((related_party_kind)::text = 'household'::text)) OR (((relationship_kind)::text = 'family'::text) AND ((origin_party_kind)::text = 'person'::text) AND ((related_party_kind)::text = 'person'::text)) OR (((relationship_kind)::text = 'organization_affiliation'::text) AND ((origin_party_kind)::text = 'person'::text) AND ((related_party_kind)::text = 'organization'::text)) OR (((relationship_kind)::text = 'organization_contact'::text) AND ((origin_party_kind)::text = 'person'::text) AND ((related_party_kind)::text = 'organization'::text)) OR (((relationship_kind)::text = 'parent_organization'::text) AND ((origin_party_kind)::text = 'organization'::text) AND ((related_party_kind)::text = 'organization'::text)) OR (((relationship_kind)::text = 'service_provider_for'::text) AND ((origin_party_kind)::text = 'organization'::text) AND ((related_party_kind)::text = 'organization'::text)))),
    CONSTRAINT party_relationships_kind_valid CHECK (((relationship_kind)::text = ANY (ARRAY[('household_member'::character varying)::text, ('family'::character varying)::text, ('organization_affiliation'::character varying)::text, ('organization_contact'::character varying)::text, ('parent_organization'::character varying)::text, ('service_provider_for'::character varying)::text]))),
    CONSTRAINT party_relationships_label_matches_kind CHECK (((((relationship_kind)::text = 'family'::text) AND ((relationship_label)::text = ANY (ARRAY[('parent_of'::character varying)::text, ('child_of'::character varying)::text, ('guardian_of'::character varying)::text, ('dependent_of'::character varying)::text, ('spouse_of'::character varying)::text, ('partner_of'::character varying)::text, ('other_family'::character varying)::text]))) OR (((relationship_kind)::text = 'organization_affiliation'::text) AND ((relationship_label)::text = ANY (ARRAY[('employee'::character varying)::text, ('contractor'::character varying)::text, ('owner'::character varying)::text, ('member'::character varying)::text, ('representative'::character varying)::text, ('other'::character varying)::text]))) OR (((relationship_kind)::text = ANY (ARRAY[('household_member'::character varying)::text, ('organization_contact'::character varying)::text, ('parent_organization'::character varying)::text, ('service_provider_for'::character varying)::text])) AND (relationship_label IS NULL)))),
    CONSTRAINT party_relationships_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT party_relationships_no_self CHECK ((origin_party_id <> related_party_id)),
    CONSTRAINT party_relationships_range_order CHECK (((effective_until IS NULL) OR (effective_from IS NULL) OR (effective_until > effective_from))),
    CONSTRAINT party_relationships_record_status_valid CHECK (((record_status)::text = ANY (ARRAY[('valid'::character varying)::text, ('superseded'::character varying)::text, ('voided'::character varying)::text]))),
    CONSTRAINT party_relationships_spouse_canonical_order CHECK ((((relationship_kind)::text <> 'family'::text) OR ((relationship_label)::text <> ALL (ARRAY[('spouse_of'::character varying)::text, ('partner_of'::character varying)::text])) OR (origin_party_id < related_party_id))),
    CONSTRAINT pr_disposition_matches_status CHECK (((((record_status)::text = 'valid'::text) AND (superseded_by_relationship_id IS NULL) AND (corrected_at IS NULL) AND (corrected_by_membership_id IS NULL) AND (correction_reason IS NULL)) OR (((record_status)::text = 'superseded'::text) AND (superseded_by_relationship_id IS NOT NULL) AND (corrected_at IS NOT NULL) AND (corrected_by_membership_id IS NOT NULL) AND (btrim((correction_reason)::text) <> ''::text)) OR (((record_status)::text = 'voided'::text) AND (corrected_at IS NOT NULL) AND (corrected_by_membership_id IS NOT NULL) AND (btrim((correction_reason)::text) <> ''::text)))),
    CONSTRAINT pr_ending_complete CHECK ((((ended_at IS NULL) AND (ended_by_membership_id IS NULL) AND (ending_reason IS NULL)) OR ((ended_at IS NOT NULL) AND (ended_by_membership_id IS NOT NULL) AND (btrim((ending_reason)::text) <> ''::text) AND (effective_until IS NOT NULL))))
);


--
-- Name: people; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.people (
    party_id uuid NOT NULL,
    agency_id uuid NOT NULL,
    given_name character varying NOT NULL,
    middle_name character varying,
    family_name character varying NOT NULL,
    prefix character varying,
    suffix character varying,
    preferred_name character varying,
    form_of_address character varying,
    pronouns character varying,
    date_of_birth date,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    party_kind character varying DEFAULT 'person'::character varying NOT NULL,
    CONSTRAINT people_date_of_birth_not_future CHECK (((date_of_birth IS NULL) OR (date_of_birth <= CURRENT_DATE))),
    CONSTRAINT people_family_name_not_blank CHECK ((btrim((family_name)::text) <> ''::text)),
    CONSTRAINT people_form_of_address_null_or_not_blank CHECK (((form_of_address IS NULL) OR (btrim((form_of_address)::text) <> ''::text))),
    CONSTRAINT people_given_name_not_blank CHECK ((btrim((given_name)::text) <> ''::text)),
    CONSTRAINT people_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT people_middle_name_null_or_not_blank CHECK (((middle_name IS NULL) OR (btrim((middle_name)::text) <> ''::text))),
    CONSTRAINT people_party_kind_person CHECK (((party_kind)::text = 'person'::text)),
    CONSTRAINT people_preferred_name_null_or_not_blank CHECK (((preferred_name IS NULL) OR (btrim((preferred_name)::text) <> ''::text))),
    CONSTRAINT people_prefix_null_or_not_blank CHECK (((prefix IS NULL) OR (btrim((prefix)::text) <> ''::text))),
    CONSTRAINT people_pronouns_null_or_not_blank CHECK (((pronouns IS NULL) OR (btrim((pronouns)::text) <> ''::text))),
    CONSTRAINT people_suffix_null_or_not_blank CHECK (((suffix IS NULL) OR (btrim((suffix)::text) <> ''::text)))
);


--
-- Name: relationship_purpose_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.relationship_purpose_assignments (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    relationship_id uuid NOT NULL,
    organization_party_id uuid NOT NULL,
    purpose character varying NOT NULL,
    priority integer NOT NULL,
    effective_from date,
    effective_until date,
    record_status character varying DEFAULT 'valid'::character varying NOT NULL,
    superseded_by_assignment_id uuid,
    corrected_at timestamp with time zone,
    corrected_by_membership_id uuid,
    correction_reason character varying,
    ended_at timestamp with time zone,
    ended_by_membership_id uuid,
    ending_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT rpa_disposition_matches_status CHECK (((((record_status)::text = 'valid'::text) AND (superseded_by_assignment_id IS NULL) AND (corrected_at IS NULL) AND (corrected_by_membership_id IS NULL) AND (correction_reason IS NULL)) OR (((record_status)::text = 'superseded'::text) AND (superseded_by_assignment_id IS NOT NULL) AND (corrected_at IS NOT NULL) AND (corrected_by_membership_id IS NOT NULL) AND (btrim((correction_reason)::text) <> ''::text)) OR (((record_status)::text = 'voided'::text) AND (corrected_at IS NOT NULL) AND (corrected_by_membership_id IS NOT NULL) AND (btrim((correction_reason)::text) <> ''::text)))),
    CONSTRAINT rpa_ending_complete CHECK ((((ended_at IS NULL) AND (ended_by_membership_id IS NULL) AND (ending_reason IS NULL)) OR ((ended_at IS NOT NULL) AND (ended_by_membership_id IS NOT NULL) AND (btrim((ending_reason)::text) <> ''::text) AND (effective_until IS NOT NULL)))),
    CONSTRAINT rpa_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT rpa_priority_positive CHECK ((priority >= 1)),
    CONSTRAINT rpa_purpose_valid CHECK (((purpose)::text = ANY (ARRAY[('general'::character varying)::text, ('booking'::character varying)::text, ('accounting'::character varying)::text]))),
    CONSTRAINT rpa_range_order CHECK (((effective_until IS NULL) OR (effective_from IS NULL) OR (effective_until > effective_from))),
    CONSTRAINT rpa_record_status_valid CHECK (((record_status)::text = ANY (ARRAY[('valid'::character varying)::text, ('superseded'::character varying)::text, ('voided'::character varying)::text])))
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id uuid DEFAULT uuidv7() NOT NULL,
    user_id uuid NOT NULL,
    ip_address character varying,
    user_agent character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    office_id uuid
);


--
-- Name: supplier_arrangements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_arrangements (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    office_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    parent_arrangement_id uuid,
    supplier_party_id uuid NOT NULL,
    service_provider_party_id uuid,
    name character varying NOT NULL,
    description text,
    client_facing_description text,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    supplier_display_name_snapshot character varying NOT NULL,
    service_provider_display_name_snapshot character varying,
    created_by_membership_id uuid NOT NULL,
    status_changed_at timestamp with time zone NOT NULL,
    status_changed_by_membership_id uuid NOT NULL,
    status_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT supplier_arrangements_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_arrangements_name_not_blank CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT supplier_arrangements_no_self_parent CHECK (((parent_arrangement_id IS NULL) OR (parent_arrangement_id <> id))),
    CONSTRAINT supplier_arrangements_provider_snapshot CHECK (((service_provider_party_id IS NULL) OR (service_provider_display_name_snapshot IS NOT NULL))),
    CONSTRAINT supplier_arrangements_status_metadata CHECK (((((status)::text = ANY ((ARRAY['draft'::character varying, 'active'::character varying])::text[])) AND (status_reason IS NULL)) OR (((status)::text = 'cancelled'::text) AND (btrim((status_reason)::text) <> ''::text)))),
    CONSTRAINT supplier_arrangements_status_valid CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'active'::character varying, 'cancelled'::character varying])::text[])))
);


--
-- Name: supplier_capacity_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_capacity_events (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    office_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    arrangement_id uuid NOT NULL,
    resource_id uuid NOT NULL,
    service_occurrence_id uuid NOT NULL,
    supplier_capacity_position_id uuid NOT NULL,
    reservation_id uuid,
    capacity_unit character varying NOT NULL,
    event_type character varying NOT NULL,
    quantity integer NOT NULL,
    agency_held_delta integer DEFAULT 0 NOT NULL,
    pending_request_delta integer DEFAULT 0 NOT NULL,
    guaranteed_delta integer DEFAULT 0 NOT NULL,
    consumed_delta integer DEFAULT 0 NOT NULL,
    released_current_delta integer DEFAULT 0 NOT NULL,
    commanded_at timestamp with time zone NOT NULL,
    effective_on date NOT NULL,
    actor_kind character varying NOT NULL,
    actor_membership_id uuid,
    actor_identifier character varying,
    reason text NOT NULL,
    idempotency_key character varying NOT NULL,
    causation_event_id uuid,
    corrected_event_id uuid,
    supplier_approval_reference character varying,
    supplier_approval_received_at timestamp with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT sce_actor_consistency CHECK (((((actor_kind)::text = 'membership'::text) AND (actor_membership_id IS NOT NULL) AND (actor_identifier IS NULL)) OR (((actor_kind)::text = 'system'::text) AND (actor_membership_id IS NULL) AND (btrim((actor_identifier)::text) <> ''::text)))),
    CONSTRAINT sce_capacity_unit_valid CHECK (((capacity_unit)::text = ANY ((ARRAY['seat'::character varying, 'room'::character varying, 'cabin'::character varying, 'vehicle'::character varying, 'policy'::character varying, 'unit'::character varying])::text[]))),
    CONSTRAINT sce_consumption_reservation_required CHECK (((((event_type)::text <> 'consumption'::text) AND ((event_type)::text <> 'restoration'::text)) OR (reservation_id IS NOT NULL))),
    CONSTRAINT sce_event_type_valid CHECK (((event_type)::text = ANY ((ARRAY['initial_hold'::character varying, 'request'::character varying, 'confirm_request'::character varying, 'increase'::character varying, 'reduction'::character varying, 'release'::character varying, 'reinstatement'::character varying, 'consumption'::character varying, 'restoration'::character varying, 'correction'::character varying, 'expiration'::character varying])::text[]))),
    CONSTRAINT sce_idempotency_key_not_blank CHECK ((btrim((idempotency_key)::text) <> ''::text)),
    CONSTRAINT sce_quantity_positive CHECK ((quantity > 0)),
    CONSTRAINT sce_reason_not_blank CHECK ((btrim(reason) <> ''::text)),
    CONSTRAINT sce_reinstatement_approval_required CHECK ((((event_type)::text <> 'reinstatement'::text) OR (supplier_approval_reference IS NOT NULL))),
    CONSTRAINT sce_supplier_approval_complete CHECK (((supplier_approval_reference IS NULL) = (supplier_approval_received_at IS NULL)))
);


--
-- Name: supplier_capacity_positions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_capacity_positions (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    office_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    arrangement_id uuid NOT NULL,
    resource_id uuid NOT NULL,
    service_occurrence_id uuid NOT NULL,
    capacity_unit character varying NOT NULL,
    agency_held integer DEFAULT 0 NOT NULL,
    pending_request integer DEFAULT 0 NOT NULL,
    guaranteed integer DEFAULT 0 NOT NULL,
    consumed integer DEFAULT 0 NOT NULL,
    released_current integer DEFAULT 0 NOT NULL,
    supplier_reported_total integer,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT scp_agency_held_nonnegative CHECK ((agency_held >= 0)),
    CONSTRAINT scp_available_nonnegative CHECK ((agency_held >= consumed)),
    CONSTRAINT scp_capacity_unit_valid CHECK (((capacity_unit)::text = ANY ((ARRAY['seat'::character varying, 'room'::character varying, 'cabin'::character varying, 'vehicle'::character varying, 'policy'::character varying, 'unit'::character varying])::text[]))),
    CONSTRAINT scp_consumed_nonnegative CHECK ((consumed >= 0)),
    CONSTRAINT scp_guaranteed_nonnegative CHECK ((guaranteed >= 0)),
    CONSTRAINT scp_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT scp_pending_request_nonnegative CHECK ((pending_request >= 0)),
    CONSTRAINT scp_released_current_nonnegative CHECK ((released_current >= 0)),
    CONSTRAINT scp_supplier_total_nonnegative CHECK (((supplier_reported_total IS NULL) OR (supplier_reported_total >= 0)))
);


--
-- Name: supplier_commitments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_commitments (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    office_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    arrangement_id uuid NOT NULL,
    reservation_id uuid,
    resource_id uuid,
    service_occurrence_id uuid,
    governing_term_id uuid NOT NULL,
    supersedes_commitment_id uuid,
    economic_item_id uuid NOT NULL,
    economic_item_key character varying NOT NULL,
    cost_category character varying NOT NULL,
    quantity_basis character varying NOT NULL,
    quantity_unit character varying NOT NULL,
    currency character varying(3) NOT NULL,
    valuation_amount_minor_units bigint NOT NULL,
    valuation_details jsonb DEFAULT '{}'::jsonb NOT NULL,
    governing_term_snapshot character varying NOT NULL,
    status character varying DEFAULT 'open'::character varying NOT NULL,
    opened_reason text NOT NULL,
    created_by_membership_id uuid NOT NULL,
    status_changed_at timestamp with time zone NOT NULL,
    status_changed_by_membership_id uuid NOT NULL,
    status_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT supplier_commitments_currency_format CHECK (((currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT supplier_commitments_key_not_blank CHECK ((btrim((economic_item_key)::text) <> ''::text)),
    CONSTRAINT supplier_commitments_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_commitments_opened_reason_not_blank CHECK ((btrim(opened_reason) <> ''::text)),
    CONSTRAINT supplier_commitments_status_metadata CHECK (((((status)::text = 'open'::text) AND (status_reason IS NULL)) OR (((status)::text <> 'open'::text) AND (btrim((status_reason)::text) <> ''::text)))),
    CONSTRAINT supplier_commitments_status_valid CHECK (((status)::text = ANY ((ARRAY['open'::character varying, 'released'::character varying, 'satisfied'::character varying, 'superseded'::character varying, 'cancelled'::character varying])::text[]))),
    CONSTRAINT supplier_commitments_value_nonnegative CHECK ((valuation_amount_minor_units >= 0))
);


--
-- Name: supplier_confirmations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_confirmations (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    office_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    arrangement_id uuid,
    reservation_id uuid,
    issuer_party_id uuid NOT NULL,
    issuer_display_name_snapshot character varying NOT NULL,
    identifier_type character varying NOT NULL,
    context character varying NOT NULL,
    raw_value character varying NOT NULL,
    normalized_value character varying NOT NULL,
    issued_on date,
    received_on date,
    source_channel character varying,
    document_reference character varying,
    status character varying DEFAULT 'effective'::character varying NOT NULL,
    entered_by_membership_id uuid NOT NULL,
    superseded_at timestamp with time zone,
    superseded_by_membership_id uuid,
    supersession_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT supplier_confirmations_context_not_blank CHECK ((btrim((context)::text) <> ''::text)),
    CONSTRAINT supplier_confirmations_exactly_one_owner CHECK (((arrangement_id IS NULL) <> (reservation_id IS NULL))),
    CONSTRAINT supplier_confirmations_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_confirmations_normalized_value_not_blank CHECK ((btrim((normalized_value)::text) <> ''::text)),
    CONSTRAINT supplier_confirmations_raw_value_not_blank CHECK ((btrim((raw_value)::text) <> ''::text)),
    CONSTRAINT supplier_confirmations_status_metadata CHECK (((((status)::text = 'effective'::text) AND (superseded_at IS NULL) AND (superseded_by_membership_id IS NULL) AND (supersession_reason IS NULL)) OR (((status)::text = 'superseded'::text) AND (superseded_at IS NOT NULL) AND (superseded_by_membership_id IS NOT NULL) AND (btrim((supersession_reason)::text) <> ''::text)))),
    CONSTRAINT supplier_confirmations_status_valid CHECK (((status)::text = ANY ((ARRAY['effective'::character varying, 'superseded'::character varying])::text[]))),
    CONSTRAINT supplier_confirmations_type_not_blank CHECK ((btrim((identifier_type)::text) <> ''::text))
);


--
-- Name: supplier_cost_term_complimentary_ratio_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_cost_term_complimentary_ratio_rules (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_cost_term_id uuid CONSTRAINT supplier_cost_term_complimentary_supplier_cost_term_id_not_null NOT NULL,
    minimum_qualifying_quantity integer DEFAULT 1 CONSTRAINT supplier_cost_term_complime_minimum_qualifying_quantit_not_null NOT NULL,
    paid_unit_quantity integer CONSTRAINT supplier_cost_term_complimentary_ra_paid_unit_quantity_not_null NOT NULL,
    complimentary_unit_quantity integer CONSTRAINT supplier_cost_term_complime_complimentary_unit_quantit_not_null NOT NULL,
    unit_amount_minor_units bigint CONSTRAINT supplier_cost_term_complimenta_unit_amount_minor_units_not_null NOT NULL,
    rounding_rule character varying DEFAULT 'floor'::character varying CONSTRAINT supplier_cost_term_complimentary_ratio_r_rounding_rule_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT supplier_cost_term_complimentary_ratio_rule_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT supplier_cost_term_complimentary_ratio_rule_updated_at_not_null NOT NULL,
    CONSTRAINT sct_comp_rules_amount_nonnegative CHECK ((unit_amount_minor_units >= 0)),
    CONSTRAINT sct_comp_rules_comp_positive CHECK ((complimentary_unit_quantity > 0)),
    CONSTRAINT sct_comp_rules_minimum_positive CHECK ((minimum_qualifying_quantity > 0)),
    CONSTRAINT sct_comp_rules_paid_positive CHECK ((paid_unit_quantity > 0)),
    CONSTRAINT sct_comp_rules_rounding_valid CHECK (((rounding_rule)::text = ANY ((ARRAY['floor'::character varying, 'ceiling'::character varying, 'nearest'::character varying])::text[])))
);


--
-- Name: supplier_cost_term_fixed_details; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_cost_term_fixed_details (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_cost_term_id uuid NOT NULL,
    amount_minor_units bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT supplier_cost_term_fixed_details_amount_nonnegative CHECK ((amount_minor_units >= 0))
);


--
-- Name: supplier_cost_term_manual_estimate_details; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_cost_term_manual_estimate_details (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_cost_term_id uuid CONSTRAINT supplier_cost_term_manual_estima_supplier_cost_term_id_not_null NOT NULL,
    forecast_amount_minor_units bigint CONSTRAINT supplier_cost_term_manual_e_forecast_amount_minor_unit_not_null NOT NULL,
    reason text NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT sct_manual_estimate_reason_not_blank CHECK ((btrim(reason) <> ''::text)),
    CONSTRAINT supplier_cost_term_manual_estimate_details_amount_nonnegative CHECK ((forecast_amount_minor_units >= 0))
);


--
-- Name: supplier_cost_term_minimum_guarantee_details; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_cost_term_minimum_guarantee_details (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_cost_term_id uuid CONSTRAINT supplier_cost_term_minimum_guara_supplier_cost_term_id_not_null NOT NULL,
    minimum_quantity integer,
    unit_amount_minor_units bigint,
    minimum_amount_minor_units bigint,
    created_at timestamp(6) with time zone CONSTRAINT supplier_cost_term_minimum_guarantee_detail_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT supplier_cost_term_minimum_guarantee_detail_updated_at_not_null NOT NULL,
    CONSTRAINT sct_minimum_guarantee_amount_nonnegative CHECK (((minimum_amount_minor_units IS NULL) OR (minimum_amount_minor_units >= 0))),
    CONSTRAINT sct_minimum_guarantee_amount_or_quantity CHECK (((minimum_amount_minor_units IS NOT NULL) OR ((minimum_quantity IS NOT NULL) AND (unit_amount_minor_units IS NOT NULL)))),
    CONSTRAINT sct_minimum_guarantee_quantity_positive CHECK (((minimum_quantity IS NULL) OR (minimum_quantity > 0))),
    CONSTRAINT sct_minimum_guarantee_unit_nonnegative CHECK (((unit_amount_minor_units IS NULL) OR (unit_amount_minor_units >= 0)))
);


--
-- Name: supplier_cost_term_pass_through_provenances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_cost_term_pass_through_provenances (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_cost_term_id uuid CONSTRAINT supplier_cost_term_pass_through__supplier_cost_term_id_not_null NOT NULL,
    supplier_amount_minor_units bigint CONSTRAINT supplier_cost_term_pass_thr_supplier_amount_minor_unit_not_null NOT NULL,
    supplier_amount_reference character varying CONSTRAINT supplier_cost_term_pass_thro_supplier_amount_reference_not_null NOT NULL,
    provenance text NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT sct_pass_throughs_amount_nonnegative CHECK ((supplier_amount_minor_units >= 0)),
    CONSTRAINT sct_pass_throughs_provenance_not_blank CHECK ((btrim(provenance) <> ''::text)),
    CONSTRAINT sct_pass_throughs_reference_not_blank CHECK ((btrim((supplier_amount_reference)::text) <> ''::text))
);


--
-- Name: supplier_cost_term_per_night_details; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_cost_term_per_night_details (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_cost_term_id uuid CONSTRAINT supplier_cost_term_per_night_det_supplier_cost_term_id_not_null NOT NULL,
    unit_amount_minor_units bigint CONSTRAINT supplier_cost_term_per_night_d_unit_amount_minor_units_not_null NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT supplier_cost_term_per_night_details_amount_nonnegative CHECK ((unit_amount_minor_units >= 0))
);


--
-- Name: supplier_cost_term_per_person_details; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_cost_term_per_person_details (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_cost_term_id uuid CONSTRAINT supplier_cost_term_per_person_de_supplier_cost_term_id_not_null NOT NULL,
    unit_amount_minor_units bigint CONSTRAINT supplier_cost_term_per_person__unit_amount_minor_units_not_null NOT NULL,
    planning_person_quantity integer,
    guaranteed_person_quantity integer,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT sct_per_person_guaranteed_positive CHECK (((guaranteed_person_quantity IS NULL) OR (guaranteed_person_quantity > 0))),
    CONSTRAINT sct_per_person_planning_positive CHECK (((planning_person_quantity IS NULL) OR (planning_person_quantity > 0))),
    CONSTRAINT sct_per_person_quantity_present CHECK (((planning_person_quantity IS NOT NULL) OR (guaranteed_person_quantity IS NOT NULL))),
    CONSTRAINT supplier_cost_term_per_person_details_amount_nonnegative CHECK ((unit_amount_minor_units >= 0))
);


--
-- Name: supplier_cost_term_per_resource_details; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_cost_term_per_resource_details (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_cost_term_id uuid CONSTRAINT supplier_cost_term_per_resource__supplier_cost_term_id_not_null NOT NULL,
    unit_amount_minor_units bigint CONSTRAINT supplier_cost_term_per_resourc_unit_amount_minor_units_not_null NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT supplier_cost_term_per_resource_details_amount_nonnegative CHECK ((unit_amount_minor_units >= 0))
);


--
-- Name: supplier_cost_term_percentage_base_refs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_cost_term_percentage_base_refs (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_cost_term_id uuid CONSTRAINT supplier_cost_term_percentage_ba_supplier_cost_term_id_not_null NOT NULL,
    rate_basis_points integer CONSTRAINT supplier_cost_term_percentage_base_r_rate_basis_points_not_null NOT NULL,
    base_economic_item_id uuid,
    base_economic_item_key character varying,
    base_amount_minor_units bigint,
    base_reference character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT sct_percentage_refs_amount_nonnegative CHECK (((base_amount_minor_units IS NULL) OR (base_amount_minor_units >= 0))),
    CONSTRAINT sct_percentage_refs_base_present CHECK (((base_amount_minor_units IS NOT NULL) OR (base_economic_item_id IS NOT NULL) OR (COALESCE(btrim((base_economic_item_key)::text), ''::text) <> ''::text))),
    CONSTRAINT sct_percentage_refs_rate_nonnegative CHECK ((rate_basis_points >= 0)),
    CONSTRAINT sct_percentage_refs_reference_not_blank CHECK ((btrim((base_reference)::text) <> ''::text))
);


--
-- Name: supplier_cost_term_steps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_cost_term_steps (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_cost_term_id uuid NOT NULL,
    band_start_quantity integer NOT NULL,
    band_end_quantity integer,
    unit_amount_minor_units bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT sct_steps_amount_nonnegative CHECK ((unit_amount_minor_units >= 0)),
    CONSTRAINT sct_steps_end_after_start CHECK (((band_end_quantity IS NULL) OR (band_end_quantity >= band_start_quantity))),
    CONSTRAINT sct_steps_start_positive CHECK ((band_start_quantity > 0))
);


--
-- Name: supplier_cost_term_tiers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_cost_term_tiers (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_cost_term_id uuid NOT NULL,
    threshold_quantity integer NOT NULL,
    unit_amount_minor_units bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT sct_tiers_amount_nonnegative CHECK ((unit_amount_minor_units >= 0)),
    CONSTRAINT sct_tiers_threshold_positive CHECK ((threshold_quantity > 0))
);


--
-- Name: supplier_cost_terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_cost_terms (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    office_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    arrangement_id uuid NOT NULL,
    reservation_id uuid,
    resource_id uuid,
    service_occurrence_id uuid,
    economic_item_id uuid DEFAULT uuidv7() NOT NULL,
    economic_item_key character varying NOT NULL,
    cost_category character varying NOT NULL,
    quantity_basis character varying NOT NULL,
    quantity_unit character varying NOT NULL,
    shape character varying NOT NULL,
    basis character varying NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    currency character varying(3) NOT NULL,
    effective_on date,
    effective_until date,
    term_version integer DEFAULT 1 NOT NULL,
    rounding_method character varying DEFAULT 'nearest_minor_unit'::character varying NOT NULL,
    tax_fee_treatment character varying DEFAULT 'excluded'::character varying NOT NULL,
    source_reference character varying,
    provenance text NOT NULL,
    evaluation_inputs jsonb DEFAULT '{}'::jsonb NOT NULL,
    supersedes_term_id uuid,
    created_by_membership_id uuid NOT NULL,
    status_changed_at timestamp with time zone NOT NULL,
    status_changed_by_membership_id uuid NOT NULL,
    status_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT supplier_cost_terms_basis_valid CHECK (((basis)::text = ANY ((ARRAY['estimate'::character varying, 'contracted'::character varying])::text[]))),
    CONSTRAINT supplier_cost_terms_category_not_blank CHECK ((btrim((cost_category)::text) <> ''::text)),
    CONSTRAINT supplier_cost_terms_currency_format CHECK (((currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT supplier_cost_terms_effective_interval CHECK (((effective_until IS NULL) OR (effective_on IS NULL) OR (effective_until > effective_on))),
    CONSTRAINT supplier_cost_terms_key_not_blank CHECK ((btrim((economic_item_key)::text) <> ''::text)),
    CONSTRAINT supplier_cost_terms_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_cost_terms_provenance_not_blank CHECK ((btrim(provenance) <> ''::text)),
    CONSTRAINT supplier_cost_terms_quantity_basis_not_blank CHECK ((btrim((quantity_basis)::text) <> ''::text)),
    CONSTRAINT supplier_cost_terms_quantity_unit_not_blank CHECK ((btrim((quantity_unit)::text) <> ''::text)),
    CONSTRAINT supplier_cost_terms_shape_valid CHECK (((shape)::text = ANY ((ARRAY['fixed'::character varying, 'per_resource'::character varying, 'per_person'::character varying, 'per_night'::character varying, 'minimum_guarantee'::character varying, 'tiered'::character varying, 'stepped'::character varying, 'percentage'::character varying, 'complimentary_ratio'::character varying, 'pass_through'::character varying, 'manual_estimate'::character varying])::text[]))),
    CONSTRAINT supplier_cost_terms_status_metadata CHECK (((((status)::text = ANY ((ARRAY['draft'::character varying, 'active'::character varying])::text[])) AND (status_reason IS NULL)) OR (((status)::text = ANY ((ARRAY['superseded'::character varying, 'void'::character varying])::text[])) AND (btrim((status_reason)::text) <> ''::text)))),
    CONSTRAINT supplier_cost_terms_status_valid CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'active'::character varying, 'superseded'::character varying, 'void'::character varying])::text[]))),
    CONSTRAINT supplier_cost_terms_version_positive CHECK ((term_version > 0))
);


--
-- Name: supplier_deadlines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_deadlines (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    office_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    arrangement_id uuid NOT NULL,
    source_deposit_requirement_id uuid NOT NULL,
    name character varying NOT NULL,
    original_due_on date NOT NULL,
    due_on date NOT NULL,
    status character varying DEFAULT 'open'::character varying NOT NULL,
    created_by_membership_id uuid NOT NULL,
    rescheduled_at timestamp with time zone,
    rescheduled_by_membership_id uuid,
    reschedule_reason character varying,
    status_changed_at timestamp with time zone NOT NULL,
    status_changed_by_membership_id uuid NOT NULL,
    status_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT supplier_deadlines_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_deadlines_name_not_blank CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT supplier_deadlines_reschedule_metadata CHECK ((((rescheduled_at IS NULL) AND (rescheduled_by_membership_id IS NULL) AND (reschedule_reason IS NULL)) OR ((rescheduled_at IS NOT NULL) AND (rescheduled_by_membership_id IS NOT NULL) AND (btrim((reschedule_reason)::text) <> ''::text)))),
    CONSTRAINT supplier_deadlines_status_metadata CHECK (((((status)::text = 'open'::text) AND (status_reason IS NULL)) OR (((status)::text <> 'open'::text) AND (btrim((status_reason)::text) <> ''::text)))),
    CONSTRAINT supplier_deadlines_status_valid CHECK (((status)::text = ANY ((ARRAY['open'::character varying, 'completed'::character varying, 'waived'::character varying, 'cancelled'::character varying])::text[])))
);


--
-- Name: supplier_deposit_requirements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_deposit_requirements (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    office_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    arrangement_id uuid NOT NULL,
    supplier_cost_term_id uuid,
    name character varying NOT NULL,
    amount_minor_units bigint NOT NULL,
    currency character varying(3) NOT NULL,
    due_rule character varying NOT NULL,
    due_on date,
    refundable boolean DEFAULT false NOT NULL,
    applies_to_final_balance boolean DEFAULT true NOT NULL,
    trigger_condition character varying NOT NULL,
    provenance text NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    created_by_membership_id uuid NOT NULL,
    status_changed_by_membership_id uuid CONSTRAINT supplier_deposit_requiremen_status_changed_by_membersh_not_null NOT NULL,
    status_changed_at timestamp with time zone NOT NULL,
    status_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT supplier_deposits_amount_nonnegative CHECK ((amount_minor_units >= 0)),
    CONSTRAINT supplier_deposits_currency_format CHECK (((currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT supplier_deposits_due_rule_not_blank CHECK ((btrim((due_rule)::text) <> ''::text)),
    CONSTRAINT supplier_deposits_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_deposits_name_not_blank CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT supplier_deposits_provenance_not_blank CHECK ((btrim(provenance) <> ''::text)),
    CONSTRAINT supplier_deposits_status_metadata CHECK (((((status)::text = 'active'::text) AND (status_reason IS NULL)) OR (((status)::text = 'cancelled'::text) AND (btrim((status_reason)::text) <> ''::text)))),
    CONSTRAINT supplier_deposits_status_valid CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'cancelled'::character varying])::text[]))),
    CONSTRAINT supplier_deposits_trigger_not_blank CHECK ((btrim((trigger_condition)::text) <> ''::text))
);


--
-- Name: supplier_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_profiles (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    party_id uuid NOT NULL,
    party_kind character varying NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    party_status character varying,
    responsible_office_id uuid NOT NULL,
    responsible_office_status character varying,
    deactivated_at timestamp with time zone,
    deactivated_by_membership_id uuid,
    deactivation_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    default_currency character varying(3) NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    payment_term_notes text,
    commission_notes text,
    booking_instructions text,
    payment_instructions text,
    cancellation_policy_notes text,
    portal_url character varying,
    CONSTRAINT supplier_profiles_booking_instructions_length CHECK ((char_length(booking_instructions) <= 2000)),
    CONSTRAINT supplier_profiles_cancellation_policy_notes_length CHECK ((char_length(cancellation_policy_notes) <= 2000)),
    CONSTRAINT supplier_profiles_commission_notes_length CHECK ((char_length(commission_notes) <= 2000)),
    CONSTRAINT supplier_profiles_currency_format CHECK (((default_currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT supplier_profiles_lifecycle_and_status_projections CHECK (((((status)::text = 'active'::text) AND (party_status IS NOT NULL) AND ((party_status)::text = 'active'::text) AND (responsible_office_status IS NOT NULL) AND ((responsible_office_status)::text = 'active'::text) AND (deactivated_at IS NULL) AND (deactivated_by_membership_id IS NULL) AND (deactivation_reason IS NULL)) OR (((status)::text = 'inactive'::text) AND (party_status IS NULL) AND (responsible_office_status IS NULL) AND (deactivated_at IS NOT NULL) AND (deactivated_by_membership_id IS NOT NULL) AND (btrim((deactivation_reason)::text) <> ''::text)))),
    CONSTRAINT supplier_profiles_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_profiles_party_kind_valid CHECK (((party_kind)::text = ANY ((ARRAY['person'::character varying, 'organization'::character varying])::text[]))),
    CONSTRAINT supplier_profiles_payment_instructions_length CHECK ((char_length(payment_instructions) <= 2000)),
    CONSTRAINT supplier_profiles_payment_term_notes_length CHECK ((char_length(payment_term_notes) <= 2000)),
    CONSTRAINT supplier_profiles_portal_url_https CHECK (((portal_url IS NULL) OR (((portal_url)::text ~ '^https://'::text) AND ((portal_url)::text !~ '^https://[^/]*@'::text)))),
    CONSTRAINT supplier_profiles_status_valid CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
);


--
-- Name: supplier_reservation_resources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_reservation_resources (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    office_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    arrangement_id uuid NOT NULL,
    reservation_id uuid NOT NULL,
    resource_id uuid NOT NULL,
    created_by_membership_id uuid CONSTRAINT supplier_reservation_resource_created_by_membership_id_not_null NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: supplier_reservations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_reservations (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    office_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    arrangement_id uuid NOT NULL,
    name character varying NOT NULL,
    status character varying DEFAULT 'requested'::character varying NOT NULL,
    operational_notes text,
    confirmed_without_identifier_reason character varying,
    confirmed_without_identifier_at timestamp with time zone,
    confirmed_without_identifier_by_membership_id uuid,
    created_by_membership_id uuid NOT NULL,
    status_changed_at timestamp with time zone NOT NULL,
    status_changed_by_membership_id uuid NOT NULL,
    status_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT supplier_reservations_confirmation_metadata CHECK (((((status)::text = 'confirmed'::text) AND (((confirmed_without_identifier_reason IS NULL) AND (confirmed_without_identifier_at IS NULL) AND (confirmed_without_identifier_by_membership_id IS NULL)) OR ((btrim((confirmed_without_identifier_reason)::text) <> ''::text) AND (confirmed_without_identifier_at IS NOT NULL) AND (confirmed_without_identifier_by_membership_id IS NOT NULL)))) OR (((status)::text <> 'confirmed'::text) AND (confirmed_without_identifier_reason IS NULL) AND (confirmed_without_identifier_at IS NULL) AND (confirmed_without_identifier_by_membership_id IS NULL)))),
    CONSTRAINT supplier_reservations_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_reservations_name_not_blank CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT supplier_reservations_status_metadata CHECK (((((status)::text = ANY ((ARRAY['cancelled'::character varying, 'declined'::character varying, 'unable_to_confirm'::character varying])::text[])) AND (btrim((status_reason)::text) <> ''::text)) OR (((status)::text = ANY ((ARRAY['requested'::character varying, 'submitted'::character varying, 'confirmed'::character varying])::text[])) AND (status_reason IS NULL)))),
    CONSTRAINT supplier_reservations_status_valid CHECK (((status)::text = ANY ((ARRAY['requested'::character varying, 'submitted'::character varying, 'confirmed'::character varying, 'declined'::character varying, 'unable_to_confirm'::character varying, 'cancelled'::character varying])::text[])))
);


--
-- Name: supplier_resources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_resources (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    office_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    arrangement_id uuid NOT NULL,
    name character varying NOT NULL,
    resource_kind character varying NOT NULL,
    capacity_unit character varying NOT NULL,
    description text,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    created_by_membership_id uuid NOT NULL,
    status_changed_at timestamp with time zone NOT NULL,
    status_changed_by_membership_id uuid NOT NULL,
    status_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT supplier_resources_capacity_unit_valid CHECK (((capacity_unit)::text = ANY ((ARRAY['seat'::character varying, 'room'::character varying, 'cabin'::character varying, 'vehicle'::character varying, 'policy'::character varying, 'unit'::character varying])::text[]))),
    CONSTRAINT supplier_resources_kind_not_blank CHECK ((btrim((resource_kind)::text) <> ''::text)),
    CONSTRAINT supplier_resources_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_resources_name_not_blank CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT supplier_resources_status_metadata CHECK (((((status)::text = 'active'::text) AND (status_reason IS NULL)) OR (((status)::text = 'inactive'::text) AND (btrim((status_reason)::text) <> ''::text)))),
    CONSTRAINT supplier_resources_status_valid CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
);


--
-- Name: supplier_service_category_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_service_category_assignments (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_profile_id uuid CONSTRAINT supplier_service_category_assignme_supplier_profile_id_not_null NOT NULL,
    category_code character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT ssca_category_code_valid CHECK (((category_code)::text = ANY ((ARRAY['accommodation'::character varying, 'air'::character varying, 'cruise'::character varying, 'rail'::character varying, 'ground_transportation'::character varying, 'tour_operator'::character varying, 'activity'::character varying, 'venue'::character varying, 'dining'::character varying, 'insurance'::character varying, 'destination_management'::character varying])::text[])))
);


--
-- Name: supplier_service_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_service_occurrences (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    office_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    arrangement_id uuid NOT NULL,
    resource_id uuid NOT NULL,
    occurrence_kind character varying NOT NULL,
    service_date date,
    segment_type character varying,
    segment_identifier character varying,
    label character varying,
    created_by_membership_id uuid NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT supplier_occurrences_kind_identity CHECK (((((occurrence_kind)::text = 'night_slice'::text) AND (service_date IS NOT NULL) AND (segment_type IS NULL) AND (segment_identifier IS NULL)) OR (((occurrence_kind)::text = 'typed_segment'::text) AND (service_date IS NULL) AND (btrim((segment_type)::text) <> ''::text) AND (btrim((segment_identifier)::text) <> ''::text)))),
    CONSTRAINT supplier_occurrences_kind_valid CHECK (((occurrence_kind)::text = ANY ((ARRAY['night_slice'::character varying, 'typed_segment'::character varying])::text[]))),
    CONSTRAINT supplier_occurrences_lock_version_nonnegative CHECK ((lock_version >= 0))
);


--
-- Name: travel_programs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.travel_programs (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    name character varying NOT NULL,
    description text,
    client_facing_description text,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    inactivated_at timestamp with time zone,
    inactivated_by_membership_id uuid,
    inactivation_reason character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT travel_programs_lifecycle_metadata CHECK (((((status)::text = 'active'::text) AND (inactivated_at IS NULL) AND (inactivated_by_membership_id IS NULL) AND (inactivation_reason IS NULL)) OR (((status)::text = 'inactive'::text) AND (inactivated_at IS NOT NULL) AND (inactivated_by_membership_id IS NOT NULL) AND (btrim((inactivation_reason)::text) <> ''::text)))),
    CONSTRAINT travel_programs_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT travel_programs_name_not_blank CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT travel_programs_status_valid CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT uuidv7() NOT NULL,
    email_address character varying NOT NULL,
    password_digest character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    first_name character varying NOT NULL,
    last_name character varying NOT NULL,
    preferred_name character varying,
    password_reset_version integer DEFAULT 0 NOT NULL,
    CONSTRAINT users_first_name_not_blank CHECK ((btrim((first_name)::text) <> ''::text)),
    CONSTRAINT users_last_name_not_blank CHECK ((btrim((last_name)::text) <> ''::text)),
    CONSTRAINT users_password_reset_version_nonnegative CHECK ((password_reset_version >= 0)),
    CONSTRAINT users_preferred_name_null_or_not_blank CHECK (((preferred_name IS NULL) OR (btrim((preferred_name)::text) <> ''::text)))
);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: agencies agencies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agencies
    ADD CONSTRAINT agencies_pkey PRIMARY KEY (id);


--
-- Name: agency_memberships agency_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agency_memberships
    ADD CONSTRAINT agency_memberships_pkey PRIMARY KEY (id);


--
-- Name: agency_provisioning_requests agency_provisioning_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agency_provisioning_requests
    ADD CONSTRAINT agency_provisioning_requests_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: audit_events audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_pkey PRIMARY KEY (id);


--
-- Name: client_advisor_assignments caa_no_overlapping_intervals; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_advisor_assignments
    ADD CONSTRAINT caa_no_overlapping_intervals EXCLUDE USING gist (agency_id WITH =, client_profile_id WITH =, daterange(effective_from, effective_until, '[)'::text) WITH &&);


--
-- Name: client_advisor_assignments client_advisor_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_advisor_assignments
    ADD CONSTRAINT client_advisor_assignments_pkey PRIMARY KEY (id);


--
-- Name: client_profiles client_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_profiles
    ADD CONSTRAINT client_profiles_pkey PRIMARY KEY (id);


--
-- Name: contact_point_purpose_assignments contact_point_purpose_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact_point_purpose_assignments
    ADD CONSTRAINT contact_point_purpose_assignments_pkey PRIMARY KEY (id);


--
-- Name: contact_point_purpose_assignments cppa_unique_valid_primary; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact_point_purpose_assignments
    ADD CONSTRAINT cppa_unique_valid_primary EXCLUDE USING gist (agency_id WITH =, party_id WITH =, contact_kind WITH =, purpose WITH =, daterange(effective_from, effective_until, '[)'::text) WITH &&) WHERE ((((record_status)::text = 'valid'::text) AND (priority = 1)));


--
-- Name: delivery_intents delivery_intents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_intents
    ADD CONSTRAINT delivery_intents_pkey PRIMARY KEY (id);


--
-- Name: departure_party_role_assignments departure_party_role_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departure_party_role_assignments
    ADD CONSTRAINT departure_party_role_assignments_pkey PRIMARY KEY (id);


--
-- Name: departure_reference_counters departure_reference_counters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departure_reference_counters
    ADD CONSTRAINT departure_reference_counters_pkey PRIMARY KEY (agency_id);


--
-- Name: departure_team_assignments departure_team_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departure_team_assignments
    ADD CONSTRAINT departure_team_assignments_pkey PRIMARY KEY (id);


--
-- Name: departures departures_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departures
    ADD CONSTRAINT departures_pkey PRIMARY KEY (id);


--
-- Name: departure_party_role_assignments dpra_no_overlapping_intervals; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departure_party_role_assignments
    ADD CONSTRAINT dpra_no_overlapping_intervals EXCLUDE USING gist (agency_id WITH =, departure_id WITH =, role WITH =, party_id WITH =, daterange(effective_from, effective_until, '[)'::text) WITH &&);


--
-- Name: departure_team_assignments dta_no_overlapping_intervals; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departure_team_assignments
    ADD CONSTRAINT dta_no_overlapping_intervals EXCLUDE USING gist (agency_id WITH =, departure_id WITH =, assignment_role WITH =, agency_membership_id WITH =, daterange(effective_from, effective_until, '[)'::text) WITH &&);


--
-- Name: external_identifiers external_identifiers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_identifiers
    ADD CONSTRAINT external_identifiers_pkey PRIMARY KEY (id);


--
-- Name: households households_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.households
    ADD CONSTRAINT households_pkey PRIMARY KEY (party_id);


--
-- Name: office_assignments office_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.office_assignments
    ADD CONSTRAINT office_assignments_pkey PRIMARY KEY (id);


--
-- Name: offices offices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offices
    ADD CONSTRAINT offices_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (party_id);


--
-- Name: parties parties_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parties
    ADD CONSTRAINT parties_pkey PRIMARY KEY (id);


--
-- Name: party_alternate_names party_alternate_names_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_alternate_names
    ADD CONSTRAINT party_alternate_names_pkey PRIMARY KEY (id);


--
-- Name: party_contact_points party_contact_points_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_contact_points
    ADD CONSTRAINT party_contact_points_pkey PRIMARY KEY (id);


--
-- Name: party_email_addresses party_email_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_email_addresses
    ADD CONSTRAINT party_email_addresses_pkey PRIMARY KEY (contact_point_id);


--
-- Name: party_notes party_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_notes
    ADD CONSTRAINT party_notes_pkey PRIMARY KEY (id);


--
-- Name: party_phone_numbers party_phone_numbers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_phone_numbers
    ADD CONSTRAINT party_phone_numbers_pkey PRIMARY KEY (contact_point_id);


--
-- Name: party_postal_addresses party_postal_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_postal_addresses
    ADD CONSTRAINT party_postal_addresses_pkey PRIMARY KEY (contact_point_id);


--
-- Name: party_relationships party_relationships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_relationships
    ADD CONSTRAINT party_relationships_pkey PRIMARY KEY (id);


--
-- Name: people people_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.people
    ADD CONSTRAINT people_pkey PRIMARY KEY (party_id);


--
-- Name: party_relationships pr_affiliation_contact_conflict; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_relationships
    ADD CONSTRAINT pr_affiliation_contact_conflict EXCLUDE USING gist (agency_id WITH =, origin_party_id WITH =, related_party_id WITH =, daterange(effective_from, effective_until, '[)'::text) WITH &&) WHERE ((((record_status)::text = 'valid'::text) AND ((relationship_kind)::text = ANY (ARRAY[('organization_affiliation'::character varying)::text, ('organization_contact'::character varying)::text]))));


--
-- Name: party_relationships pr_one_valid_parent; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_relationships
    ADD CONSTRAINT pr_one_valid_parent EXCLUDE USING gist (agency_id WITH =, origin_party_id WITH =, daterange(effective_from, effective_until, '[)'::text) WITH &&) WHERE ((((record_status)::text = 'valid'::text) AND ((relationship_kind)::text = 'parent_organization'::text)));


--
-- Name: party_relationships pr_unique_valid_duplicate; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_relationships
    ADD CONSTRAINT pr_unique_valid_duplicate EXCLUDE USING gist (agency_id WITH =, origin_party_id WITH =, related_party_id WITH =, relationship_kind WITH =, COALESCE(relationship_label, ''::character varying) WITH =, daterange(effective_from, effective_until, '[)'::text) WITH &&) WHERE (((record_status)::text = 'valid'::text));


--
-- Name: party_relationships pr_unique_valid_spouse_pair; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_relationships
    ADD CONSTRAINT pr_unique_valid_spouse_pair EXCLUDE USING gist (agency_id WITH =, LEAST(origin_party_id, related_party_id) WITH =, GREATEST(origin_party_id, related_party_id) WITH =, relationship_label WITH =, daterange(effective_from, effective_until, '[)'::text) WITH &&) WHERE ((((record_status)::text = 'valid'::text) AND ((relationship_kind)::text = 'family'::text) AND ((relationship_label)::text = ANY (ARRAY[('spouse_of'::character varying)::text, ('partner_of'::character varying)::text]))));


--
-- Name: relationship_purpose_assignments relationship_purpose_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relationship_purpose_assignments
    ADD CONSTRAINT relationship_purpose_assignments_pkey PRIMARY KEY (id);


--
-- Name: relationship_purpose_assignments rpa_unique_valid_primary; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relationship_purpose_assignments
    ADD CONSTRAINT rpa_unique_valid_primary EXCLUDE USING gist (agency_id WITH =, organization_party_id WITH =, purpose WITH =, daterange(effective_from, effective_until, '[)'::text) WITH &&) WHERE ((((record_status)::text = 'valid'::text) AND (priority = 1)));


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: supplier_cost_term_steps sct_steps_no_overlapping_bands; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_steps
    ADD CONSTRAINT sct_steps_no_overlapping_bands EXCLUDE USING gist (supplier_cost_term_id WITH =, int4range(band_start_quantity, COALESCE(band_end_quantity, 2147483647), '[]'::text) WITH &&);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: supplier_arrangements supplier_arrangements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangements
    ADD CONSTRAINT supplier_arrangements_pkey PRIMARY KEY (id);


--
-- Name: supplier_capacity_events supplier_capacity_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_capacity_events
    ADD CONSTRAINT supplier_capacity_events_pkey PRIMARY KEY (id);


--
-- Name: supplier_capacity_positions supplier_capacity_positions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_capacity_positions
    ADD CONSTRAINT supplier_capacity_positions_pkey PRIMARY KEY (id);


--
-- Name: supplier_commitments supplier_commitments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_pkey PRIMARY KEY (id);


--
-- Name: supplier_confirmations supplier_confirmations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmations
    ADD CONSTRAINT supplier_confirmations_pkey PRIMARY KEY (id);


--
-- Name: supplier_cost_term_complimentary_ratio_rules supplier_cost_term_complimentary_ratio_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_complimentary_ratio_rules
    ADD CONSTRAINT supplier_cost_term_complimentary_ratio_rules_pkey PRIMARY KEY (id);


--
-- Name: supplier_cost_term_fixed_details supplier_cost_term_fixed_details_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_fixed_details
    ADD CONSTRAINT supplier_cost_term_fixed_details_pkey PRIMARY KEY (id);


--
-- Name: supplier_cost_term_manual_estimate_details supplier_cost_term_manual_estimate_details_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_manual_estimate_details
    ADD CONSTRAINT supplier_cost_term_manual_estimate_details_pkey PRIMARY KEY (id);


--
-- Name: supplier_cost_term_minimum_guarantee_details supplier_cost_term_minimum_guarantee_details_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_minimum_guarantee_details
    ADD CONSTRAINT supplier_cost_term_minimum_guarantee_details_pkey PRIMARY KEY (id);


--
-- Name: supplier_cost_term_pass_through_provenances supplier_cost_term_pass_through_provenances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_pass_through_provenances
    ADD CONSTRAINT supplier_cost_term_pass_through_provenances_pkey PRIMARY KEY (id);


--
-- Name: supplier_cost_term_per_night_details supplier_cost_term_per_night_details_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_per_night_details
    ADD CONSTRAINT supplier_cost_term_per_night_details_pkey PRIMARY KEY (id);


--
-- Name: supplier_cost_term_per_person_details supplier_cost_term_per_person_details_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_per_person_details
    ADD CONSTRAINT supplier_cost_term_per_person_details_pkey PRIMARY KEY (id);


--
-- Name: supplier_cost_term_per_resource_details supplier_cost_term_per_resource_details_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_per_resource_details
    ADD CONSTRAINT supplier_cost_term_per_resource_details_pkey PRIMARY KEY (id);


--
-- Name: supplier_cost_term_percentage_base_refs supplier_cost_term_percentage_base_refs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_percentage_base_refs
    ADD CONSTRAINT supplier_cost_term_percentage_base_refs_pkey PRIMARY KEY (id);


--
-- Name: supplier_cost_term_steps supplier_cost_term_steps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_steps
    ADD CONSTRAINT supplier_cost_term_steps_pkey PRIMARY KEY (id);


--
-- Name: supplier_cost_term_tiers supplier_cost_term_tiers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_tiers
    ADD CONSTRAINT supplier_cost_term_tiers_pkey PRIMARY KEY (id);


--
-- Name: supplier_cost_terms supplier_cost_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_terms
    ADD CONSTRAINT supplier_cost_terms_pkey PRIMARY KEY (id);


--
-- Name: supplier_deadlines supplier_deadlines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadlines
    ADD CONSTRAINT supplier_deadlines_pkey PRIMARY KEY (id);


--
-- Name: supplier_deposit_requirements supplier_deposit_requirements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deposit_requirements
    ADD CONSTRAINT supplier_deposit_requirements_pkey PRIMARY KEY (id);


--
-- Name: supplier_profiles supplier_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_profiles
    ADD CONSTRAINT supplier_profiles_pkey PRIMARY KEY (id);


--
-- Name: supplier_reservation_resources supplier_reservation_resources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_resources
    ADD CONSTRAINT supplier_reservation_resources_pkey PRIMARY KEY (id);


--
-- Name: supplier_reservations supplier_reservations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservations
    ADD CONSTRAINT supplier_reservations_pkey PRIMARY KEY (id);


--
-- Name: supplier_resources supplier_resources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_resources
    ADD CONSTRAINT supplier_resources_pkey PRIMARY KEY (id);


--
-- Name: supplier_service_category_assignments supplier_service_category_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_service_category_assignments
    ADD CONSTRAINT supplier_service_category_assignments_pkey PRIMARY KEY (id);


--
-- Name: supplier_service_occurrences supplier_service_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_service_occurrences
    ADD CONSTRAINT supplier_service_occurrences_pkey PRIMARY KEY (id);


--
-- Name: travel_programs travel_programs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.travel_programs
    ADD CONSTRAINT travel_programs_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_on_agency_id_56ed585f9d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_agency_id_56ed585f9d ON public.supplier_cost_term_complimentary_ratio_rules USING btree (agency_id);


--
-- Name: idx_on_agency_id_7fe41b44ab; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_agency_id_7fe41b44ab ON public.supplier_cost_term_minimum_guarantee_details USING btree (agency_id);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_agency_memberships_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agency_memberships_on_agency_id ON public.agency_memberships USING btree (agency_id);


--
-- Name: index_agency_memberships_on_agency_id_and_person_party_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agency_memberships_on_agency_id_and_person_party_id ON public.agency_memberships USING btree (agency_id, person_party_id);


--
-- Name: index_agency_memberships_on_agency_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agency_memberships_on_agency_id_and_status ON public.agency_memberships USING btree (agency_id, status);


--
-- Name: index_agency_memberships_on_id_agency_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agency_memberships_on_id_agency_id_and_status ON public.agency_memberships USING btree (id, agency_id, status);


--
-- Name: index_agency_memberships_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agency_memberships_on_id_and_agency_id ON public.agency_memberships USING btree (id, agency_id);


--
-- Name: index_agency_memberships_on_person_party_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agency_memberships_on_person_party_id ON public.agency_memberships USING btree (person_party_id);


--
-- Name: index_agency_memberships_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agency_memberships_on_user_id ON public.agency_memberships USING btree (user_id);


--
-- Name: index_agency_memberships_on_user_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agency_memberships_on_user_id_and_agency_id ON public.agency_memberships USING btree (user_id, agency_id);


--
-- Name: index_agency_memberships_one_active_per_user; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agency_memberships_one_active_per_user ON public.agency_memberships USING btree (user_id) WHERE ((status)::text = 'active'::text);


--
-- Name: index_agency_provisioning_requests_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agency_provisioning_requests_on_agency_id ON public.agency_provisioning_requests USING btree (agency_id);


--
-- Name: index_agency_provisioning_requests_on_idempotency_key_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agency_provisioning_requests_on_idempotency_key_digest ON public.agency_provisioning_requests USING btree (idempotency_key_digest);


--
-- Name: index_agency_provisioning_requests_on_intent_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agency_provisioning_requests_on_intent_digest ON public.agency_provisioning_requests USING btree (intent_digest);


--
-- Name: index_audit_events_on_actor_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_actor_user_id ON public.audit_events USING btree (actor_user_id);


--
-- Name: index_audit_events_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_agency_id ON public.audit_events USING btree (agency_id);


--
-- Name: index_audit_events_on_agency_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_agency_id_and_created_at ON public.audit_events USING btree (agency_id, created_at);


--
-- Name: index_client_advisor_assignments_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_advisor_assignments_on_agency_id ON public.client_advisor_assignments USING btree (agency_id);


--
-- Name: index_client_advisor_assignments_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_advisor_assignments_on_id_and_agency_id ON public.client_advisor_assignments USING btree (id, agency_id);


--
-- Name: index_client_advisor_assignments_on_membership; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_advisor_assignments_on_membership ON public.client_advisor_assignments USING btree (advisor_membership_id, agency_id);


--
-- Name: index_client_advisor_assignments_on_profile; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_advisor_assignments_on_profile ON public.client_advisor_assignments USING btree (client_profile_id, agency_id);


--
-- Name: index_client_profiles_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_profiles_on_agency_id ON public.client_profiles USING btree (agency_id);


--
-- Name: index_client_profiles_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_profiles_on_id_and_agency_id ON public.client_profiles USING btree (id, agency_id);


--
-- Name: index_client_profiles_on_office_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_profiles_on_office_id_and_agency_id ON public.client_profiles USING btree (responsible_office_id, agency_id);


--
-- Name: index_client_profiles_on_party_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_profiles_on_party_id_and_agency_id ON public.client_profiles USING btree (party_id, agency_id);


--
-- Name: index_contact_point_purpose_assignments_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contact_point_purpose_assignments_on_agency_id ON public.contact_point_purpose_assignments USING btree (agency_id);


--
-- Name: index_contact_point_purpose_assignments_on_contact_point; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contact_point_purpose_assignments_on_contact_point ON public.contact_point_purpose_assignments USING btree (contact_point_id, agency_id);


--
-- Name: index_cppa_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cppa_on_id_and_agency_id ON public.contact_point_purpose_assignments USING btree (id, agency_id);


--
-- Name: index_delivery_intents_for_reconciliation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_delivery_intents_for_reconciliation ON public.delivery_intents USING btree (status, available_at);


--
-- Name: index_delivery_intents_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_delivery_intents_on_agency_id ON public.delivery_intents USING btree (agency_id);


--
-- Name: index_delivery_intents_on_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_delivery_intents_on_idempotency_key ON public.delivery_intents USING btree (idempotency_key);


--
-- Name: index_delivery_intents_on_subject; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_delivery_intents_on_subject ON public.delivery_intents USING btree (subject_type, subject_id);


--
-- Name: index_departure_party_role_assignments_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departure_party_role_assignments_on_agency_id ON public.departure_party_role_assignments USING btree (agency_id);


--
-- Name: index_departure_team_assignments_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departure_team_assignments_on_agency_id ON public.departure_team_assignments USING btree (agency_id);


--
-- Name: index_departures_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departures_on_agency_id ON public.departures USING btree (agency_id);


--
-- Name: index_departures_on_agency_id_and_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_departures_on_agency_id_and_idempotency_key ON public.departures USING btree (agency_id, creation_idempotency_key);


--
-- Name: index_departures_on_agency_id_and_reference; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_departures_on_agency_id_and_reference ON public.departures USING btree (agency_id, departure_reference);


--
-- Name: index_departures_on_agency_office_status_start; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departures_on_agency_office_status_start ON public.departures USING btree (agency_id, office_id, status, start_date);


--
-- Name: index_departures_on_agency_program_start; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departures_on_agency_program_start ON public.departures USING btree (agency_id, travel_program_id, start_date);


--
-- Name: index_departures_on_agency_status_start; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departures_on_agency_status_start ON public.departures USING btree (agency_id, status, start_date);


--
-- Name: index_departures_on_destination_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departures_on_destination_trgm ON public.departures USING gin (primary_destination public.gin_trgm_ops);


--
-- Name: index_departures_on_id_agency_id_office_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_departures_on_id_agency_id_office_id ON public.departures USING btree (id, agency_id, office_id);


--
-- Name: index_departures_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_departures_on_id_and_agency_id ON public.departures USING btree (id, agency_id);


--
-- Name: index_departures_on_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departures_on_name_trgm ON public.departures USING gin (name public.gin_trgm_ops);


--
-- Name: index_departures_on_reference_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departures_on_reference_trgm ON public.departures USING gin (departure_reference public.gin_trgm_ops);


--
-- Name: index_dpra_on_departure_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dpra_on_departure_and_agency ON public.departure_party_role_assignments USING btree (departure_id, agency_id);


--
-- Name: index_dpra_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_dpra_on_id_and_agency_id ON public.departure_party_role_assignments USING btree (id, agency_id);


--
-- Name: index_dpra_on_party_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dpra_on_party_and_agency ON public.departure_party_role_assignments USING btree (party_id, agency_id);


--
-- Name: index_dpra_one_current_primary; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_dpra_one_current_primary ON public.departure_party_role_assignments USING btree (departure_id, role) WHERE ((effective_until IS NULL) AND is_primary);


--
-- Name: index_dta_on_departure_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dta_on_departure_and_agency ON public.departure_team_assignments USING btree (departure_id, agency_id);


--
-- Name: index_dta_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_dta_on_id_and_agency_id ON public.departure_team_assignments USING btree (id, agency_id);


--
-- Name: index_dta_on_membership_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dta_on_membership_and_agency ON public.departure_team_assignments USING btree (agency_membership_id, agency_id);


--
-- Name: index_dta_one_current_role; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_dta_one_current_role ON public.departure_team_assignments USING btree (departure_id, assignment_role) WHERE (effective_until IS NULL);


--
-- Name: index_external_identifiers_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_external_identifiers_on_agency_id ON public.external_identifiers USING btree (agency_id);


--
-- Name: index_external_identifiers_on_client_profile; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_external_identifiers_on_client_profile ON public.external_identifiers USING btree (client_profile_id, agency_id);


--
-- Name: index_external_identifiers_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_external_identifiers_on_id_and_agency_id ON public.external_identifiers USING btree (id, agency_id);


--
-- Name: index_external_identifiers_on_party; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_external_identifiers_on_party ON public.external_identifiers USING btree (party_id, agency_id);


--
-- Name: index_external_identifiers_on_supplier_profile; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_external_identifiers_on_supplier_profile ON public.external_identifiers USING btree (supplier_profile_id, agency_id);


--
-- Name: index_external_identifiers_unique_external_crm_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_external_identifiers_unique_external_crm_id ON public.external_identifiers USING btree (agency_id, issuer, normalized_value) WHERE (((status)::text = 'active'::text) AND ((identifier_type)::text = 'external_crm_id'::text));


--
-- Name: index_external_identifiers_unique_industry_supplier_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_external_identifiers_unique_industry_supplier_code ON public.external_identifiers USING btree (agency_id, issuer, normalized_value) WHERE (((status)::text = 'active'::text) AND ((identifier_type)::text = 'industry_supplier_code'::text));


--
-- Name: index_external_identifiers_unique_legacy_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_external_identifiers_unique_legacy_client_id ON public.external_identifiers USING btree (agency_id, issuer, normalized_value) WHERE (((status)::text = 'active'::text) AND ((identifier_type)::text = 'legacy_client_id'::text));


--
-- Name: index_external_identifiers_unique_supplier_account_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_external_identifiers_unique_supplier_account_number ON public.external_identifiers USING btree (agency_id, issuer, normalized_value) WHERE (((status)::text = 'active'::text) AND ((identifier_type)::text = 'supplier_account_number'::text));


--
-- Name: index_external_identifiers_unique_supplier_portal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_external_identifiers_unique_supplier_portal_id ON public.external_identifiers USING btree (agency_id, issuer, normalized_value) WHERE (((status)::text = 'active'::text) AND ((identifier_type)::text = 'supplier_portal_id'::text));


--
-- Name: index_households_on_party_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_households_on_party_id_and_agency_id ON public.households USING btree (party_id, agency_id);


--
-- Name: index_office_assignments_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_office_assignments_on_agency_id ON public.office_assignments USING btree (agency_id);


--
-- Name: index_office_assignments_on_agency_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_office_assignments_on_agency_membership_id ON public.office_assignments USING btree (agency_membership_id);


--
-- Name: index_office_assignments_on_membership_and_office; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_office_assignments_on_membership_and_office ON public.office_assignments USING btree (agency_membership_id, office_id);


--
-- Name: index_office_assignments_on_office_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_office_assignments_on_office_id ON public.office_assignments USING btree (office_id);


--
-- Name: index_office_assignments_one_default_per_membership; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_office_assignments_one_default_per_membership ON public.office_assignments USING btree (agency_membership_id) WHERE ((is_default = true) AND ((status)::text = 'active'::text));


--
-- Name: index_offices_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_offices_on_agency_id ON public.offices USING btree (agency_id);


--
-- Name: index_offices_on_agency_id_and_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_offices_on_agency_id_and_code ON public.offices USING btree (agency_id, code);


--
-- Name: index_offices_on_id_agency_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_offices_on_id_agency_id_and_status ON public.offices USING btree (id, agency_id, status);


--
-- Name: index_offices_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_offices_on_id_and_agency_id ON public.offices USING btree (id, agency_id);


--
-- Name: index_organizations_on_party_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_organizations_on_party_id_and_agency_id ON public.organizations USING btree (party_id, agency_id);


--
-- Name: index_parties_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_parties_on_agency_id ON public.parties USING btree (agency_id);


--
-- Name: index_parties_on_agency_id_and_party_kind_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_parties_on_agency_id_and_party_kind_and_status ON public.parties USING btree (agency_id, party_kind, status);


--
-- Name: index_parties_on_agency_id_and_sort_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_parties_on_agency_id_and_sort_name ON public.parties USING btree (agency_id, sort_name);


--
-- Name: index_parties_on_display_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_parties_on_display_name_trgm ON public.parties USING gin (display_name public.gin_trgm_ops);


--
-- Name: index_parties_on_id_agency_id_and_party_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_parties_on_id_agency_id_and_party_kind ON public.parties USING btree (id, agency_id, party_kind);


--
-- Name: index_parties_on_id_agency_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_parties_on_id_agency_id_and_status ON public.parties USING btree (id, agency_id, status);


--
-- Name: index_parties_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_parties_on_id_and_agency_id ON public.parties USING btree (id, agency_id);


--
-- Name: index_parties_on_sort_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_parties_on_sort_name_trgm ON public.parties USING gin (sort_name public.gin_trgm_ops);


--
-- Name: index_party_alternate_names_on_agency_id_and_normalized_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_party_alternate_names_on_agency_id_and_normalized_name ON public.party_alternate_names USING btree (agency_id, normalized_name);


--
-- Name: index_party_alternate_names_on_normalized_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_party_alternate_names_on_normalized_name_trgm ON public.party_alternate_names USING gin (normalized_name public.gin_trgm_ops);


--
-- Name: index_party_alternate_names_on_removed_by_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_party_alternate_names_on_removed_by_membership_id ON public.party_alternate_names USING btree (removed_by_membership_id);


--
-- Name: index_party_alternate_names_unique_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_party_alternate_names_unique_active ON public.party_alternate_names USING btree (party_id, name_kind, normalized_name) WHERE ((status)::text = 'active'::text);


--
-- Name: index_party_contact_points_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_party_contact_points_on_agency_id ON public.party_contact_points USING btree (agency_id);


--
-- Name: index_party_contact_points_on_agency_id_and_normalized_value; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_party_contact_points_on_agency_id_and_normalized_value ON public.party_contact_points USING btree (agency_id, normalized_value);


--
-- Name: index_party_contact_points_on_id_agency_id_and_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_party_contact_points_on_id_agency_id_and_kind ON public.party_contact_points USING btree (id, agency_id, contact_kind);


--
-- Name: index_party_contact_points_on_id_party_agency_and_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_party_contact_points_on_id_party_agency_and_kind ON public.party_contact_points USING btree (id, party_id, agency_id, contact_kind);


--
-- Name: index_party_contact_points_on_party_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_party_contact_points_on_party_id_and_agency_id ON public.party_contact_points USING btree (party_id, agency_id);


--
-- Name: index_party_contact_points_unique_active_normalized; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_party_contact_points_unique_active_normalized ON public.party_contact_points USING btree (party_id, contact_kind, normalized_value) WHERE ((status)::text = 'active'::text);


--
-- Name: index_party_email_addresses_on_contact_point_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_party_email_addresses_on_contact_point_and_agency ON public.party_email_addresses USING btree (contact_point_id, agency_id);


--
-- Name: index_party_notes_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_party_notes_on_agency_id ON public.party_notes USING btree (agency_id);


--
-- Name: index_party_notes_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_party_notes_on_id_and_agency_id ON public.party_notes USING btree (id, agency_id);


--
-- Name: index_party_notes_on_party_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_party_notes_on_party_id_and_agency_id ON public.party_notes USING btree (party_id, agency_id);


--
-- Name: index_party_notes_on_party_pinned_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_party_notes_on_party_pinned_and_created_at ON public.party_notes USING btree (party_id, pinned, created_at);


--
-- Name: index_party_phone_numbers_on_contact_point_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_party_phone_numbers_on_contact_point_and_agency ON public.party_phone_numbers USING btree (contact_point_id, agency_id);


--
-- Name: index_party_postal_addresses_on_contact_point_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_party_postal_addresses_on_contact_point_and_agency ON public.party_postal_addresses USING btree (contact_point_id, agency_id);


--
-- Name: index_party_relationships_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_party_relationships_on_agency_id ON public.party_relationships USING btree (agency_id);


--
-- Name: index_party_relationships_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_party_relationships_on_id_and_agency_id ON public.party_relationships USING btree (id, agency_id);


--
-- Name: index_party_relationships_on_id_related_party_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_party_relationships_on_id_related_party_and_agency ON public.party_relationships USING btree (id, related_party_id, agency_id);


--
-- Name: index_party_relationships_on_origin_party; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_party_relationships_on_origin_party ON public.party_relationships USING btree (origin_party_id, agency_id);


--
-- Name: index_party_relationships_on_related_party; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_party_relationships_on_related_party ON public.party_relationships USING btree (related_party_id, agency_id);


--
-- Name: index_people_on_party_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_people_on_party_id_and_agency_id ON public.people USING btree (party_id, agency_id);


--
-- Name: index_relationship_purpose_assignments_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_relationship_purpose_assignments_on_agency_id ON public.relationship_purpose_assignments USING btree (agency_id);


--
-- Name: index_rpa_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_rpa_on_id_and_agency_id ON public.relationship_purpose_assignments USING btree (id, agency_id);


--
-- Name: index_rpa_on_relationship; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rpa_on_relationship ON public.relationship_purpose_assignments USING btree (relationship_id, agency_id);


--
-- Name: index_sa_on_departure_agency_office; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sa_on_departure_agency_office ON public.supplier_arrangements USING btree (departure_id, agency_id, office_id);


--
-- Name: index_sa_on_id_agency_office_departure; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sa_on_id_agency_office_departure ON public.supplier_arrangements USING btree (id, agency_id, office_id, departure_id);


--
-- Name: index_sa_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sa_on_id_and_agency_id ON public.supplier_arrangements USING btree (id, agency_id);


--
-- Name: index_sa_on_parent_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sa_on_parent_and_agency ON public.supplier_arrangements USING btree (parent_arrangement_id, agency_id);


--
-- Name: index_sa_on_provider_party_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sa_on_provider_party_and_agency ON public.supplier_arrangements USING btree (service_provider_party_id, agency_id);


--
-- Name: index_sa_on_supplier_party_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sa_on_supplier_party_and_agency ON public.supplier_arrangements USING btree (supplier_party_id, agency_id);


--
-- Name: index_sc_on_arrangement_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sc_on_arrangement_and_agency ON public.supplier_confirmations USING btree (arrangement_id, agency_id);


--
-- Name: index_sc_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sc_on_id_and_agency_id ON public.supplier_confirmations USING btree (id, agency_id);


--
-- Name: index_sc_on_reservation_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sc_on_reservation_and_agency ON public.supplier_confirmations USING btree (reservation_id, agency_id);


--
-- Name: index_sc_unique_issuer_context_value; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sc_unique_issuer_context_value ON public.supplier_confirmations USING btree (agency_id, issuer_party_id, identifier_type, context, normalized_value);


--
-- Name: index_sce_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sce_on_id_and_agency_id ON public.supplier_capacity_events USING btree (id, agency_id);


--
-- Name: index_sce_on_position_commanded; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sce_on_position_commanded ON public.supplier_capacity_events USING btree (supplier_capacity_position_id, commanded_at, id);


--
-- Name: index_sce_on_reservation_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sce_on_reservation_and_agency ON public.supplier_capacity_events USING btree (reservation_id, agency_id);


--
-- Name: index_sce_on_resource_occurrence_unit; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sce_on_resource_occurrence_unit ON public.supplier_capacity_events USING btree (resource_id, service_occurrence_id, capacity_unit);


--
-- Name: index_sce_unique_idempotency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sce_unique_idempotency ON public.supplier_capacity_events USING btree (agency_id, idempotency_key);


--
-- Name: index_scom_on_arrangement_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scom_on_arrangement_and_agency ON public.supplier_commitments USING btree (arrangement_id, agency_id);


--
-- Name: index_scom_on_governing_term_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scom_on_governing_term_and_agency ON public.supplier_commitments USING btree (governing_term_id, agency_id);


--
-- Name: index_scom_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_scom_on_id_and_agency_id ON public.supplier_commitments USING btree (id, agency_id);


--
-- Name: index_scom_one_open_per_item; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_scom_one_open_per_item ON public.supplier_commitments USING btree (agency_id, economic_item_key) WHERE ((status)::text = 'open'::text);


--
-- Name: index_scp_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_scp_on_id_and_agency_id ON public.supplier_capacity_positions USING btree (id, agency_id);


--
-- Name: index_scp_unique_resource_occurrence_unit; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_scp_unique_resource_occurrence_unit ON public.supplier_capacity_positions USING btree (resource_id, service_occurrence_id, capacity_unit);


--
-- Name: index_sct_comp_ratio_rules_on_term_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sct_comp_ratio_rules_on_term_and_agency ON public.supplier_cost_term_complimentary_ratio_rules USING btree (supplier_cost_term_id, agency_id);


--
-- Name: index_sct_comp_rules_on_term_and_min_qty; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sct_comp_rules_on_term_and_min_qty ON public.supplier_cost_term_complimentary_ratio_rules USING btree (supplier_cost_term_id, minimum_qualifying_quantity);


--
-- Name: index_sct_fixed_on_term_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sct_fixed_on_term_and_agency ON public.supplier_cost_term_fixed_details USING btree (supplier_cost_term_id, agency_id);


--
-- Name: index_sct_manual_estimate_on_term_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sct_manual_estimate_on_term_and_agency ON public.supplier_cost_term_manual_estimate_details USING btree (supplier_cost_term_id, agency_id);


--
-- Name: index_sct_minimum_guarantee_on_term_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sct_minimum_guarantee_on_term_and_agency ON public.supplier_cost_term_minimum_guarantee_details USING btree (supplier_cost_term_id, agency_id);


--
-- Name: index_sct_on_arrangement_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sct_on_arrangement_and_agency ON public.supplier_cost_terms USING btree (arrangement_id, agency_id);


--
-- Name: index_sct_on_economic_item_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sct_on_economic_item_and_agency ON public.supplier_cost_terms USING btree (economic_item_id, agency_id);


--
-- Name: index_sct_on_id_agency_office_departure; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sct_on_id_agency_office_departure ON public.supplier_cost_terms USING btree (id, agency_id, office_id, departure_id);


--
-- Name: index_sct_on_id_agency_office_departure_arrangement; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sct_on_id_agency_office_departure_arrangement ON public.supplier_cost_terms USING btree (id, agency_id, office_id, departure_id, arrangement_id);


--
-- Name: index_sct_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sct_on_id_and_agency_id ON public.supplier_cost_terms USING btree (id, agency_id);


--
-- Name: index_sct_one_active_basis_per_item; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sct_one_active_basis_per_item ON public.supplier_cost_terms USING btree (agency_id, economic_item_key, basis) WHERE ((status)::text = 'active'::text);


--
-- Name: index_sct_pass_throughs_on_term_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sct_pass_throughs_on_term_and_agency ON public.supplier_cost_term_pass_through_provenances USING btree (supplier_cost_term_id, agency_id);


--
-- Name: index_sct_per_night_on_term_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sct_per_night_on_term_and_agency ON public.supplier_cost_term_per_night_details USING btree (supplier_cost_term_id, agency_id);


--
-- Name: index_sct_per_person_on_term_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sct_per_person_on_term_and_agency ON public.supplier_cost_term_per_person_details USING btree (supplier_cost_term_id, agency_id);


--
-- Name: index_sct_per_resource_on_term_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sct_per_resource_on_term_and_agency ON public.supplier_cost_term_per_resource_details USING btree (supplier_cost_term_id, agency_id);


--
-- Name: index_sct_percentage_refs_on_term_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sct_percentage_refs_on_term_and_agency ON public.supplier_cost_term_percentage_base_refs USING btree (supplier_cost_term_id, agency_id);


--
-- Name: index_sct_steps_on_term_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sct_steps_on_term_and_agency ON public.supplier_cost_term_steps USING btree (supplier_cost_term_id, agency_id);


--
-- Name: index_sct_tiers_on_term_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sct_tiers_on_term_and_agency ON public.supplier_cost_term_tiers USING btree (supplier_cost_term_id, agency_id);


--
-- Name: index_sct_tiers_on_term_and_threshold; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sct_tiers_on_term_and_threshold ON public.supplier_cost_term_tiers USING btree (supplier_cost_term_id, threshold_quantity);


--
-- Name: index_sdl_on_deposit_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sdl_on_deposit_and_agency ON public.supplier_deadlines USING btree (source_deposit_requirement_id, agency_id);


--
-- Name: index_sdl_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sdl_on_id_and_agency_id ON public.supplier_deadlines USING btree (id, agency_id);


--
-- Name: index_sdr_on_arrangement_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sdr_on_arrangement_and_agency ON public.supplier_deposit_requirements USING btree (arrangement_id, agency_id);


--
-- Name: index_sdr_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sdr_on_id_and_agency_id ON public.supplier_deposit_requirements USING btree (id, agency_id);


--
-- Name: index_sessions_on_office_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_office_id ON public.sessions USING btree (office_id);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


--
-- Name: index_sr_on_arrangement_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sr_on_arrangement_and_agency ON public.supplier_reservations USING btree (arrangement_id, agency_id);


--
-- Name: index_sr_on_departure_agency_office; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sr_on_departure_agency_office ON public.supplier_reservations USING btree (departure_id, agency_id, office_id);


--
-- Name: index_sr_on_id_agency_office_departure; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sr_on_id_agency_office_departure ON public.supplier_reservations USING btree (id, agency_id, office_id, departure_id);


--
-- Name: index_sr_on_id_agency_office_departure_arrangement; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sr_on_id_agency_office_departure_arrangement ON public.supplier_reservations USING btree (id, agency_id, office_id, departure_id, arrangement_id);


--
-- Name: index_sr_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sr_on_id_and_agency_id ON public.supplier_reservations USING btree (id, agency_id);


--
-- Name: index_sres_on_arrangement_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sres_on_arrangement_and_agency ON public.supplier_resources USING btree (arrangement_id, agency_id);


--
-- Name: index_sres_on_id_agency_office_departure; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sres_on_id_agency_office_departure ON public.supplier_resources USING btree (id, agency_id, office_id, departure_id);


--
-- Name: index_sres_on_id_agency_office_departure_arrangement; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sres_on_id_agency_office_departure_arrangement ON public.supplier_resources USING btree (id, agency_id, office_id, departure_id, arrangement_id);


--
-- Name: index_sres_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sres_on_id_and_agency_id ON public.supplier_resources USING btree (id, agency_id);


--
-- Name: index_srr_on_reservation_and_resource; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_srr_on_reservation_and_resource ON public.supplier_reservation_resources USING btree (reservation_id, resource_id);


--
-- Name: index_srr_on_resource_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_srr_on_resource_and_agency ON public.supplier_reservation_resources USING btree (resource_id, agency_id);


--
-- Name: index_ssca_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ssca_on_id_and_agency_id ON public.supplier_service_category_assignments USING btree (id, agency_id);


--
-- Name: index_ssca_on_profile_and_category; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ssca_on_profile_and_category ON public.supplier_service_category_assignments USING btree (agency_id, supplier_profile_id, category_code);


--
-- Name: index_sso_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sso_on_id_and_agency_id ON public.supplier_service_occurrences USING btree (id, agency_id);


--
-- Name: index_sso_on_resource_and_agency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sso_on_resource_and_agency ON public.supplier_service_occurrences USING btree (resource_id, agency_id);


--
-- Name: index_sso_unique_night_slice; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sso_unique_night_slice ON public.supplier_service_occurrences USING btree (resource_id, occurrence_kind, service_date) WHERE ((occurrence_kind)::text = 'night_slice'::text);


--
-- Name: index_sso_unique_typed_segment; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sso_unique_typed_segment ON public.supplier_service_occurrences USING btree (resource_id, occurrence_kind, segment_type, segment_identifier) WHERE ((occurrence_kind)::text = 'typed_segment'::text);


--
-- Name: index_supplier_arrangements_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_arrangements_on_agency_id ON public.supplier_arrangements USING btree (agency_id);


--
-- Name: index_supplier_capacity_events_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_capacity_events_on_agency_id ON public.supplier_capacity_events USING btree (agency_id);


--
-- Name: index_supplier_capacity_positions_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_capacity_positions_on_agency_id ON public.supplier_capacity_positions USING btree (agency_id);


--
-- Name: index_supplier_commitments_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_commitments_on_agency_id ON public.supplier_commitments USING btree (agency_id);


--
-- Name: index_supplier_confirmations_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_confirmations_on_agency_id ON public.supplier_confirmations USING btree (agency_id);


--
-- Name: index_supplier_cost_term_fixed_details_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_cost_term_fixed_details_on_agency_id ON public.supplier_cost_term_fixed_details USING btree (agency_id);


--
-- Name: index_supplier_cost_term_manual_estimate_details_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_cost_term_manual_estimate_details_on_agency_id ON public.supplier_cost_term_manual_estimate_details USING btree (agency_id);


--
-- Name: index_supplier_cost_term_pass_through_provenances_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_cost_term_pass_through_provenances_on_agency_id ON public.supplier_cost_term_pass_through_provenances USING btree (agency_id);


--
-- Name: index_supplier_cost_term_per_night_details_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_cost_term_per_night_details_on_agency_id ON public.supplier_cost_term_per_night_details USING btree (agency_id);


--
-- Name: index_supplier_cost_term_per_person_details_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_cost_term_per_person_details_on_agency_id ON public.supplier_cost_term_per_person_details USING btree (agency_id);


--
-- Name: index_supplier_cost_term_per_resource_details_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_cost_term_per_resource_details_on_agency_id ON public.supplier_cost_term_per_resource_details USING btree (agency_id);


--
-- Name: index_supplier_cost_term_percentage_base_refs_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_cost_term_percentage_base_refs_on_agency_id ON public.supplier_cost_term_percentage_base_refs USING btree (agency_id);


--
-- Name: index_supplier_cost_term_steps_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_cost_term_steps_on_agency_id ON public.supplier_cost_term_steps USING btree (agency_id);


--
-- Name: index_supplier_cost_term_tiers_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_cost_term_tiers_on_agency_id ON public.supplier_cost_term_tiers USING btree (agency_id);


--
-- Name: index_supplier_cost_terms_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_cost_terms_on_agency_id ON public.supplier_cost_terms USING btree (agency_id);


--
-- Name: index_supplier_deadlines_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_deadlines_on_agency_id ON public.supplier_deadlines USING btree (agency_id);


--
-- Name: index_supplier_deposit_requirements_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_deposit_requirements_on_agency_id ON public.supplier_deposit_requirements USING btree (agency_id);


--
-- Name: index_supplier_profiles_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_profiles_on_agency_id ON public.supplier_profiles USING btree (agency_id);


--
-- Name: index_supplier_profiles_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_profiles_on_id_and_agency_id ON public.supplier_profiles USING btree (id, agency_id);


--
-- Name: index_supplier_profiles_on_office_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_profiles_on_office_id_and_agency_id ON public.supplier_profiles USING btree (responsible_office_id, agency_id);


--
-- Name: index_supplier_profiles_on_party_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_profiles_on_party_id_and_agency_id ON public.supplier_profiles USING btree (party_id, agency_id);


--
-- Name: index_supplier_reservation_resources_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_reservation_resources_on_agency_id ON public.supplier_reservation_resources USING btree (agency_id);


--
-- Name: index_supplier_reservations_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_reservations_on_agency_id ON public.supplier_reservations USING btree (agency_id);


--
-- Name: index_supplier_resources_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_resources_on_agency_id ON public.supplier_resources USING btree (agency_id);


--
-- Name: index_supplier_service_category_assignments_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_service_category_assignments_on_agency_id ON public.supplier_service_category_assignments USING btree (agency_id);


--
-- Name: index_supplier_service_occurrences_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_service_occurrences_on_agency_id ON public.supplier_service_occurrences USING btree (agency_id);


--
-- Name: index_travel_programs_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_travel_programs_on_agency_id ON public.travel_programs USING btree (agency_id);


--
-- Name: index_travel_programs_on_agency_id_status_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_travel_programs_on_agency_id_status_and_name ON public.travel_programs USING btree (agency_id, status, name);


--
-- Name: index_travel_programs_on_id_agency_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_travel_programs_on_id_agency_id_and_status ON public.travel_programs USING btree (id, agency_id, status);


--
-- Name: index_travel_programs_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_travel_programs_on_id_and_agency_id ON public.travel_programs USING btree (id, agency_id);


--
-- Name: index_travel_programs_on_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_travel_programs_on_name_trgm ON public.travel_programs USING gin (name public.gin_trgm_ops);


--
-- Name: index_users_on_email_address; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email_address ON public.users USING btree (email_address);


--
-- Name: audit_events audit_events_prevent_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_events_prevent_delete BEFORE DELETE ON public.audit_events FOR EACH ROW EXECUTE FUNCTION public.prevent_audit_event_mutation();


--
-- Name: audit_events audit_events_prevent_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_events_prevent_update BEFORE UPDATE ON public.audit_events FOR EACH ROW EXECUTE FUNCTION public.prevent_audit_event_mutation();


--
-- Name: client_advisor_assignments client_advisor_assignments_agree_with_profile_pointer; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER client_advisor_assignments_agree_with_profile_pointer AFTER INSERT OR DELETE OR UPDATE ON public.client_advisor_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.client_advisor_current_matches_open_assignment();


--
-- Name: client_advisor_assignments client_advisor_assignments_identity_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_advisor_assignments_identity_immutable BEFORE UPDATE ON public.client_advisor_assignments FOR EACH ROW EXECUTE FUNCTION public.client_advisor_assignments_prevent_identity_change();


--
-- Name: client_profiles client_profiles_advisor_agrees_with_open_assignment; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER client_profiles_advisor_agrees_with_open_assignment AFTER INSERT OR DELETE OR UPDATE ON public.client_profiles DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.client_advisor_current_matches_open_assignment();


--
-- Name: client_profiles client_profiles_identity_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_profiles_identity_immutable BEFORE UPDATE ON public.client_profiles FOR EACH ROW EXECUTE FUNCTION public.role_profiles_prevent_identity_change();


--
-- Name: departure_party_role_assignments dpra_current_role_has_one_primary; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER dpra_current_role_has_one_primary AFTER INSERT OR DELETE OR UPDATE ON public.departure_party_role_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.departure_party_role_current_has_one_primary();


--
-- Name: external_identifiers external_identifiers_identity_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER external_identifiers_identity_immutable BEFORE UPDATE ON public.external_identifiers FOR EACH ROW EXECUTE FUNCTION public.external_identifiers_prevent_identity_change();


--
-- Name: parties parties_kind_and_agency_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER parties_kind_and_agency_immutable BEFORE UPDATE ON public.parties FOR EACH ROW EXECUTE FUNCTION public.parties_prevent_kind_or_agency_change();


--
-- Name: party_contact_points party_contact_points_kind_agency_party_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER party_contact_points_kind_agency_party_immutable BEFORE UPDATE ON public.party_contact_points FOR EACH ROW EXECUTE FUNCTION public.party_contact_points_prevent_kind_or_agency_change();


--
-- Name: party_notes party_notes_body_identity_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER party_notes_body_identity_immutable BEFORE UPDATE ON public.party_notes FOR EACH ROW EXECUTE FUNCTION public.party_notes_prevent_body_or_identity_change();


--
-- Name: party_relationships party_relationships_identity_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER party_relationships_identity_immutable BEFORE UPDATE ON public.party_relationships FOR EACH ROW EXECUTE FUNCTION public.party_relationships_prevent_immutable_change();


--
-- Name: supplier_arrangements supplier_arrangements_cycle_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER supplier_arrangements_cycle_guard AFTER INSERT OR UPDATE OF parent_arrangement_id ON public.supplier_arrangements DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION public.supplier_arrangements_prevent_cycle();


--
-- Name: supplier_capacity_events supplier_capacity_events_prevent_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_capacity_events_prevent_delete BEFORE DELETE ON public.supplier_capacity_events FOR EACH ROW EXECUTE FUNCTION public.prevent_supplier_capacity_event_mutation();


--
-- Name: supplier_capacity_events supplier_capacity_events_prevent_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_capacity_events_prevent_update BEFORE UPDATE ON public.supplier_capacity_events FOR EACH ROW EXECUTE FUNCTION public.prevent_supplier_capacity_event_mutation();


--
-- Name: supplier_profiles supplier_profiles_identity_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_profiles_identity_immutable BEFORE UPDATE ON public.supplier_profiles FOR EACH ROW EXECUTE FUNCTION public.role_profiles_prevent_identity_change();


--
-- Name: agency_memberships agency_memberships_person_party_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agency_memberships
    ADD CONSTRAINT agency_memberships_person_party_same_agency_fk FOREIGN KEY (person_party_id, agency_id) REFERENCES public.people(party_id, agency_id);


--
-- Name: client_advisor_assignments caa_advisor_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_advisor_assignments
    ADD CONSTRAINT caa_advisor_same_agency_fk FOREIGN KEY (advisor_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: client_advisor_assignments caa_ended_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_advisor_assignments
    ADD CONSTRAINT caa_ended_by_membership_fk FOREIGN KEY (ended_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: client_advisor_assignments caa_profile_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_advisor_assignments
    ADD CONSTRAINT caa_profile_same_agency_fk FOREIGN KEY (client_profile_id, agency_id) REFERENCES public.client_profiles(id, agency_id);


--
-- Name: client_profiles client_profiles_advisor_active_projection_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_profiles
    ADD CONSTRAINT client_profiles_advisor_active_projection_fk FOREIGN KEY (primary_advisor_membership_id, agency_id, primary_advisor_membership_status) REFERENCES public.agency_memberships(id, agency_id, status);


--
-- Name: client_profiles client_profiles_advisor_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_profiles
    ADD CONSTRAINT client_profiles_advisor_same_agency_fk FOREIGN KEY (primary_advisor_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: client_profiles client_profiles_deactivated_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_profiles
    ADD CONSTRAINT client_profiles_deactivated_by_membership_fk FOREIGN KEY (deactivated_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: client_profiles client_profiles_office_active_projection_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_profiles
    ADD CONSTRAINT client_profiles_office_active_projection_fk FOREIGN KEY (responsible_office_id, agency_id, responsible_office_status) REFERENCES public.offices(id, agency_id, status);


--
-- Name: client_profiles client_profiles_office_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_profiles
    ADD CONSTRAINT client_profiles_office_same_agency_fk FOREIGN KEY (responsible_office_id, agency_id) REFERENCES public.offices(id, agency_id);


--
-- Name: client_profiles client_profiles_party_active_projection_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_profiles
    ADD CONSTRAINT client_profiles_party_active_projection_fk FOREIGN KEY (party_id, agency_id, party_status) REFERENCES public.parties(id, agency_id, status);


--
-- Name: client_profiles client_profiles_party_kind_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_profiles
    ADD CONSTRAINT client_profiles_party_kind_same_agency_fk FOREIGN KEY (party_id, agency_id, party_kind) REFERENCES public.parties(id, agency_id, party_kind);


--
-- Name: contact_point_purpose_assignments cppa_contact_point_owner_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact_point_purpose_assignments
    ADD CONSTRAINT cppa_contact_point_owner_fk FOREIGN KEY (contact_point_id, party_id, agency_id, contact_kind) REFERENCES public.party_contact_points(id, party_id, agency_id, contact_kind);


--
-- Name: contact_point_purpose_assignments cppa_corrected_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact_point_purpose_assignments
    ADD CONSTRAINT cppa_corrected_by_membership_fk FOREIGN KEY (corrected_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: contact_point_purpose_assignments cppa_ended_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact_point_purpose_assignments
    ADD CONSTRAINT cppa_ended_by_membership_fk FOREIGN KEY (ended_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: contact_point_purpose_assignments cppa_party_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact_point_purpose_assignments
    ADD CONSTRAINT cppa_party_same_agency_fk FOREIGN KEY (party_id, agency_id) REFERENCES public.parties(id, agency_id);


--
-- Name: contact_point_purpose_assignments cppa_superseded_by_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact_point_purpose_assignments
    ADD CONSTRAINT cppa_superseded_by_fk FOREIGN KEY (superseded_by_assignment_id, agency_id) REFERENCES public.contact_point_purpose_assignments(id, agency_id);


--
-- Name: departure_reference_counters departure_reference_counters_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departure_reference_counters
    ADD CONSTRAINT departure_reference_counters_agency_fk FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: departures departures_created_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departures
    ADD CONSTRAINT departures_created_by_membership_fk FOREIGN KEY (created_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: departures departures_office_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departures
    ADD CONSTRAINT departures_office_same_agency_fk FOREIGN KEY (office_id, agency_id) REFERENCES public.offices(id, agency_id);


--
-- Name: departures departures_owning_office_active_projection_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departures
    ADD CONSTRAINT departures_owning_office_active_projection_fk FOREIGN KEY (office_id, agency_id, owning_office_status) REFERENCES public.offices(id, agency_id, status);


--
-- Name: departures departures_program_active_projection_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departures
    ADD CONSTRAINT departures_program_active_projection_fk FOREIGN KEY (travel_program_id, agency_id, travel_program_status) REFERENCES public.travel_programs(id, agency_id, status);


--
-- Name: departures departures_program_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departures
    ADD CONSTRAINT departures_program_same_agency_fk FOREIGN KEY (travel_program_id, agency_id) REFERENCES public.travel_programs(id, agency_id);


--
-- Name: departures departures_status_changed_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departures
    ADD CONSTRAINT departures_status_changed_by_membership_fk FOREIGN KEY (status_changed_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: departure_party_role_assignments dpra_assigned_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departure_party_role_assignments
    ADD CONSTRAINT dpra_assigned_by_membership_fk FOREIGN KEY (assigned_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: departure_party_role_assignments dpra_departure_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departure_party_role_assignments
    ADD CONSTRAINT dpra_departure_same_agency_fk FOREIGN KEY (departure_id, agency_id) REFERENCES public.departures(id, agency_id);


--
-- Name: departure_party_role_assignments dpra_ended_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departure_party_role_assignments
    ADD CONSTRAINT dpra_ended_by_membership_fk FOREIGN KEY (ended_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: departure_party_role_assignments dpra_party_kind_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departure_party_role_assignments
    ADD CONSTRAINT dpra_party_kind_same_agency_fk FOREIGN KEY (party_id, agency_id, party_kind) REFERENCES public.parties(id, agency_id, party_kind);


--
-- Name: departure_team_assignments dta_assigned_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departure_team_assignments
    ADD CONSTRAINT dta_assigned_by_membership_fk FOREIGN KEY (assigned_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: departure_team_assignments dta_departure_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departure_team_assignments
    ADD CONSTRAINT dta_departure_same_agency_fk FOREIGN KEY (departure_id, agency_id) REFERENCES public.departures(id, agency_id);


--
-- Name: departure_team_assignments dta_ended_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departure_team_assignments
    ADD CONSTRAINT dta_ended_by_membership_fk FOREIGN KEY (ended_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: departure_team_assignments dta_membership_active_projection_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departure_team_assignments
    ADD CONSTRAINT dta_membership_active_projection_fk FOREIGN KEY (agency_membership_id, agency_id, membership_status) REFERENCES public.agency_memberships(id, agency_id, status);


--
-- Name: departure_team_assignments dta_membership_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departure_team_assignments
    ADD CONSTRAINT dta_membership_same_agency_fk FOREIGN KEY (agency_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: external_identifiers external_identifiers_client_profile_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_identifiers
    ADD CONSTRAINT external_identifiers_client_profile_same_agency_fk FOREIGN KEY (client_profile_id, agency_id) REFERENCES public.client_profiles(id, agency_id);


--
-- Name: external_identifiers external_identifiers_deactivated_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_identifiers
    ADD CONSTRAINT external_identifiers_deactivated_by_membership_fk FOREIGN KEY (deactivated_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: external_identifiers external_identifiers_party_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_identifiers
    ADD CONSTRAINT external_identifiers_party_same_agency_fk FOREIGN KEY (party_id, agency_id) REFERENCES public.parties(id, agency_id);


--
-- Name: external_identifiers external_identifiers_supplier_profile_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_identifiers
    ADD CONSTRAINT external_identifiers_supplier_profile_same_agency_fk FOREIGN KEY (supplier_profile_id, agency_id) REFERENCES public.supplier_profiles(id, agency_id);


--
-- Name: supplier_arrangements fk_rails_089363381e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangements
    ADD CONSTRAINT fk_rails_089363381e FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_confirmations fk_rails_1d834ae4a2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmations
    ADD CONSTRAINT fk_rails_1d834ae4a2 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: agency_memberships fk_rails_273f2f9052; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agency_memberships
    ADD CONSTRAINT fk_rails_273f2f9052 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: party_contact_points fk_rails_28f93dab28; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_contact_points
    ADD CONSTRAINT fk_rails_28f93dab28 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: offices fk_rails_29d71841aa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offices
    ADD CONSTRAINT fk_rails_29d71841aa FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: parties fk_rails_2e0d960990; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parties
    ADD CONSTRAINT fk_rails_2e0d960990 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: audit_events fk_rails_2e3720791c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT fk_rails_2e3720791c FOREIGN KEY (actor_user_id) REFERENCES public.users(id);


--
-- Name: office_assignments fk_rails_317cda774f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.office_assignments
    ADD CONSTRAINT fk_rails_317cda774f FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_cost_term_per_resource_details fk_rails_3a6c8a0318; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_per_resource_details
    ADD CONSTRAINT fk_rails_3a6c8a0318 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: agency_memberships fk_rails_3bdac11d3b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agency_memberships
    ADD CONSTRAINT fk_rails_3bdac11d3b FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_commitments fk_rails_3c8531ba76; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT fk_rails_3c8531ba76 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: agency_provisioning_requests fk_rails_427be59e8d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agency_provisioning_requests
    ADD CONSTRAINT fk_rails_427be59e8d FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: relationship_purpose_assignments fk_rails_45c236232c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relationship_purpose_assignments
    ADD CONSTRAINT fk_rails_45c236232c FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_cost_term_complimentary_ratio_rules fk_rails_497524eca0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_complimentary_ratio_rules
    ADD CONSTRAINT fk_rails_497524eca0 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_cost_term_percentage_base_refs fk_rails_4f3c5924f5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_percentage_base_refs
    ADD CONSTRAINT fk_rails_4f3c5924f5 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: party_email_addresses fk_rails_51fb47a3a2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_email_addresses
    ADD CONSTRAINT fk_rails_51fb47a3a2 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_deposit_requirements fk_rails_5649f47db3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deposit_requirements
    ADD CONSTRAINT fk_rails_5649f47db3 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: departure_party_role_assignments fk_rails_6248ee0923; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departure_party_role_assignments
    ADD CONSTRAINT fk_rails_6248ee0923 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: client_profiles fk_rails_63be60e7aa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_profiles
    ADD CONSTRAINT fk_rails_63be60e7aa FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: contact_point_purpose_assignments fk_rails_728112529a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact_point_purpose_assignments
    ADD CONSTRAINT fk_rails_728112529a FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: supplier_cost_term_tiers fk_rails_7627d7033c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_tiers
    ADD CONSTRAINT fk_rails_7627d7033c FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_cost_terms fk_rails_7b4be51c40; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_terms
    ADD CONSTRAINT fk_rails_7b4be51c40 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: audit_events fk_rails_8512cd9707; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT fk_rails_8512cd9707 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: departure_team_assignments fk_rails_854a5d32fc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departure_team_assignments
    ADD CONSTRAINT fk_rails_854a5d32fc FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_reservation_resources fk_rails_8743c41126; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_resources
    ADD CONSTRAINT fk_rails_8743c41126 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_cost_term_per_person_details fk_rails_965b7508be; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_per_person_details
    ADD CONSTRAINT fk_rails_965b7508be FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: sessions fk_rails_9866443dac; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_9866443dac FOREIGN KEY (office_id) REFERENCES public.offices(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: supplier_service_occurrences fk_rails_9d4d023d39; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_service_occurrences
    ADD CONSTRAINT fk_rails_9d4d023d39 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_reservations fk_rails_a1b8a7498f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservations
    ADD CONSTRAINT fk_rails_a1b8a7498f FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_cost_term_steps fk_rails_a4dee77103; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_steps
    ADD CONSTRAINT fk_rails_a4dee77103 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: external_identifiers fk_rails_a66f964ec8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_identifiers
    ADD CONSTRAINT fk_rails_a66f964ec8 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: party_relationships fk_rails_a851e339a0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_relationships
    ADD CONSTRAINT fk_rails_a851e339a0 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: organizations fk_rails_aa10f62a8c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT fk_rails_aa10f62a8c FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_deadlines fk_rails_ae852b93f1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadlines
    ADD CONSTRAINT fk_rails_ae852b93f1 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_cost_term_fixed_details fk_rails_af9064d71d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_fixed_details
    ADD CONSTRAINT fk_rails_af9064d71d FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_cost_term_manual_estimate_details fk_rails_bc46a44dc3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_manual_estimate_details
    ADD CONSTRAINT fk_rails_bc46a44dc3 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_profiles fk_rails_be0b77b682; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_profiles
    ADD CONSTRAINT fk_rails_be0b77b682 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: people fk_rails_beffb17c89; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.people
    ADD CONSTRAINT fk_rails_beffb17c89 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_capacity_events fk_rails_c1ff2fa5e9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_capacity_events
    ADD CONSTRAINT fk_rails_c1ff2fa5e9 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: supplier_cost_term_per_night_details fk_rails_c81521e283; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_per_night_details
    ADD CONSTRAINT fk_rails_c81521e283 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: households fk_rails_cb67d6c8a8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.households
    ADD CONSTRAINT fk_rails_cb67d6c8a8 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: party_postal_addresses fk_rails_cc74c21c38; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_postal_addresses
    ADD CONSTRAINT fk_rails_cc74c21c38 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: departures fk_rails_d0941bcf52; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departures
    ADD CONSTRAINT fk_rails_d0941bcf52 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_service_category_assignments fk_rails_d1256876d4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_service_category_assignments
    ADD CONSTRAINT fk_rails_d1256876d4 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: client_advisor_assignments fk_rails_dca68ed391; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_advisor_assignments
    ADD CONSTRAINT fk_rails_dca68ed391 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_cost_term_minimum_guarantee_details fk_rails_def4b4e02f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_minimum_guarantee_details
    ADD CONSTRAINT fk_rails_def4b4e02f FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_cost_term_pass_through_provenances fk_rails_e2adec4f82; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_pass_through_provenances
    ADD CONSTRAINT fk_rails_e2adec4f82 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: delivery_intents fk_rails_e89726e351; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_intents
    ADD CONSTRAINT fk_rails_e89726e351 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: party_notes fk_rails_e930c2d819; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_notes
    ADD CONSTRAINT fk_rails_e930c2d819 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: party_phone_numbers fk_rails_edd3d13317; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_phone_numbers
    ADD CONSTRAINT fk_rails_edd3d13317 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: travel_programs fk_rails_eeb062d829; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.travel_programs
    ADD CONSTRAINT fk_rails_eeb062d829 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_resources fk_rails_f4555dab68; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_resources
    ADD CONSTRAINT fk_rails_f4555dab68 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_capacity_positions fk_rails_ff46f0143c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_capacity_positions
    ADD CONSTRAINT fk_rails_ff46f0143c FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: households households_party_kind_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.households
    ADD CONSTRAINT households_party_kind_same_agency_fk FOREIGN KEY (party_id, agency_id, party_kind) REFERENCES public.parties(id, agency_id, party_kind);


--
-- Name: office_assignments office_assignments_membership_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.office_assignments
    ADD CONSTRAINT office_assignments_membership_same_agency_fk FOREIGN KEY (agency_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: office_assignments office_assignments_office_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.office_assignments
    ADD CONSTRAINT office_assignments_office_same_agency_fk FOREIGN KEY (office_id, agency_id) REFERENCES public.offices(id, agency_id);


--
-- Name: organizations organizations_party_kind_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_party_kind_same_agency_fk FOREIGN KEY (party_id, agency_id, party_kind) REFERENCES public.parties(id, agency_id, party_kind);


--
-- Name: parties parties_deactivated_by_membership_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parties
    ADD CONSTRAINT parties_deactivated_by_membership_same_agency_fk FOREIGN KEY (deactivated_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: party_alternate_names party_alternate_names_party_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_alternate_names
    ADD CONSTRAINT party_alternate_names_party_same_agency_fk FOREIGN KEY (party_id, agency_id) REFERENCES public.parties(id, agency_id);


--
-- Name: party_alternate_names party_alternate_names_removed_by_membership_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_alternate_names
    ADD CONSTRAINT party_alternate_names_removed_by_membership_same_agency_fk FOREIGN KEY (removed_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: party_contact_points party_contact_points_deactivated_by_membership_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_contact_points
    ADD CONSTRAINT party_contact_points_deactivated_by_membership_same_agency_fk FOREIGN KEY (deactivated_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: party_contact_points party_contact_points_party_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_contact_points
    ADD CONSTRAINT party_contact_points_party_same_agency_fk FOREIGN KEY (party_id, agency_id) REFERENCES public.parties(id, agency_id);


--
-- Name: party_contact_points party_contact_points_suppressed_by_membership_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_contact_points
    ADD CONSTRAINT party_contact_points_suppressed_by_membership_same_agency_fk FOREIGN KEY (suppressed_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: party_email_addresses party_email_addresses_contact_kind_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_email_addresses
    ADD CONSTRAINT party_email_addresses_contact_kind_same_agency_fk FOREIGN KEY (contact_point_id, agency_id, contact_kind) REFERENCES public.party_contact_points(id, agency_id, contact_kind);


--
-- Name: party_notes party_notes_author_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_notes
    ADD CONSTRAINT party_notes_author_membership_fk FOREIGN KEY (author_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: party_notes party_notes_corrected_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_notes
    ADD CONSTRAINT party_notes_corrected_by_membership_fk FOREIGN KEY (corrected_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: party_notes party_notes_party_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_notes
    ADD CONSTRAINT party_notes_party_same_agency_fk FOREIGN KEY (party_id, agency_id) REFERENCES public.parties(id, agency_id);


--
-- Name: party_notes party_notes_removed_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_notes
    ADD CONSTRAINT party_notes_removed_by_membership_fk FOREIGN KEY (removed_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: party_notes party_notes_superseded_by_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_notes
    ADD CONSTRAINT party_notes_superseded_by_fk FOREIGN KEY (superseded_by_note_id, agency_id) REFERENCES public.party_notes(id, agency_id);


--
-- Name: party_phone_numbers party_phone_numbers_contact_kind_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_phone_numbers
    ADD CONSTRAINT party_phone_numbers_contact_kind_same_agency_fk FOREIGN KEY (contact_point_id, agency_id, contact_kind) REFERENCES public.party_contact_points(id, agency_id, contact_kind);


--
-- Name: party_postal_addresses party_postal_addresses_contact_kind_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_postal_addresses
    ADD CONSTRAINT party_postal_addresses_contact_kind_same_agency_fk FOREIGN KEY (contact_point_id, agency_id, contact_kind) REFERENCES public.party_contact_points(id, agency_id, contact_kind);


--
-- Name: people people_party_kind_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.people
    ADD CONSTRAINT people_party_kind_same_agency_fk FOREIGN KEY (party_id, agency_id, party_kind) REFERENCES public.parties(id, agency_id, party_kind);


--
-- Name: party_relationships pr_corrected_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_relationships
    ADD CONSTRAINT pr_corrected_by_membership_fk FOREIGN KEY (corrected_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: party_relationships pr_ended_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_relationships
    ADD CONSTRAINT pr_ended_by_membership_fk FOREIGN KEY (ended_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: party_relationships pr_origin_party_kind_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_relationships
    ADD CONSTRAINT pr_origin_party_kind_same_agency_fk FOREIGN KEY (origin_party_id, agency_id, origin_party_kind) REFERENCES public.parties(id, agency_id, party_kind);


--
-- Name: party_relationships pr_related_party_kind_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_relationships
    ADD CONSTRAINT pr_related_party_kind_same_agency_fk FOREIGN KEY (related_party_id, agency_id, related_party_kind) REFERENCES public.parties(id, agency_id, party_kind);


--
-- Name: party_relationships pr_superseded_by_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_relationships
    ADD CONSTRAINT pr_superseded_by_fk FOREIGN KEY (superseded_by_relationship_id, agency_id) REFERENCES public.party_relationships(id, agency_id);


--
-- Name: relationship_purpose_assignments rpa_corrected_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relationship_purpose_assignments
    ADD CONSTRAINT rpa_corrected_by_membership_fk FOREIGN KEY (corrected_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: relationship_purpose_assignments rpa_ended_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relationship_purpose_assignments
    ADD CONSTRAINT rpa_ended_by_membership_fk FOREIGN KEY (ended_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: relationship_purpose_assignments rpa_organization_party_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relationship_purpose_assignments
    ADD CONSTRAINT rpa_organization_party_fk FOREIGN KEY (organization_party_id, agency_id) REFERENCES public.organizations(party_id, agency_id);


--
-- Name: relationship_purpose_assignments rpa_relationship_owner_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relationship_purpose_assignments
    ADD CONSTRAINT rpa_relationship_owner_fk FOREIGN KEY (relationship_id, organization_party_id, agency_id) REFERENCES public.party_relationships(id, related_party_id, agency_id);


--
-- Name: relationship_purpose_assignments rpa_superseded_by_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relationship_purpose_assignments
    ADD CONSTRAINT rpa_superseded_by_fk FOREIGN KEY (superseded_by_assignment_id, agency_id) REFERENCES public.relationship_purpose_assignments(id, agency_id);


--
-- Name: supplier_capacity_events sce_actor_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_capacity_events
    ADD CONSTRAINT sce_actor_membership_fk FOREIGN KEY (actor_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: supplier_capacity_events sce_arrangement_scope_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_capacity_events
    ADD CONSTRAINT sce_arrangement_scope_fk FOREIGN KEY (arrangement_id, agency_id, office_id, departure_id) REFERENCES public.supplier_arrangements(id, agency_id, office_id, departure_id);


--
-- Name: supplier_capacity_events sce_causation_event_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_capacity_events
    ADD CONSTRAINT sce_causation_event_fk FOREIGN KEY (causation_event_id, agency_id) REFERENCES public.supplier_capacity_events(id, agency_id);


--
-- Name: supplier_capacity_events sce_corrected_event_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_capacity_events
    ADD CONSTRAINT sce_corrected_event_fk FOREIGN KEY (corrected_event_id, agency_id) REFERENCES public.supplier_capacity_events(id, agency_id);


--
-- Name: supplier_capacity_events sce_departure_office_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_capacity_events
    ADD CONSTRAINT sce_departure_office_fk FOREIGN KEY (departure_id, agency_id, office_id) REFERENCES public.departures(id, agency_id, office_id);


--
-- Name: supplier_capacity_events sce_occurrence_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_capacity_events
    ADD CONSTRAINT sce_occurrence_fk FOREIGN KEY (service_occurrence_id, agency_id) REFERENCES public.supplier_service_occurrences(id, agency_id);


--
-- Name: supplier_capacity_events sce_position_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_capacity_events
    ADD CONSTRAINT sce_position_fk FOREIGN KEY (supplier_capacity_position_id, agency_id) REFERENCES public.supplier_capacity_positions(id, agency_id);


--
-- Name: supplier_capacity_events sce_reservation_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_capacity_events
    ADD CONSTRAINT sce_reservation_fk FOREIGN KEY (reservation_id, agency_id) REFERENCES public.supplier_reservations(id, agency_id);


--
-- Name: supplier_capacity_events sce_resource_scope_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_capacity_events
    ADD CONSTRAINT sce_resource_scope_fk FOREIGN KEY (resource_id, agency_id, office_id, departure_id, arrangement_id) REFERENCES public.supplier_resources(id, agency_id, office_id, departure_id, arrangement_id);


--
-- Name: supplier_capacity_positions scp_arrangement_scope_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_capacity_positions
    ADD CONSTRAINT scp_arrangement_scope_fk FOREIGN KEY (arrangement_id, agency_id, office_id, departure_id) REFERENCES public.supplier_arrangements(id, agency_id, office_id, departure_id);


--
-- Name: supplier_capacity_positions scp_departure_office_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_capacity_positions
    ADD CONSTRAINT scp_departure_office_fk FOREIGN KEY (departure_id, agency_id, office_id) REFERENCES public.departures(id, agency_id, office_id);


--
-- Name: supplier_capacity_positions scp_occurrence_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_capacity_positions
    ADD CONSTRAINT scp_occurrence_fk FOREIGN KEY (service_occurrence_id, agency_id) REFERENCES public.supplier_service_occurrences(id, agency_id);


--
-- Name: supplier_capacity_positions scp_resource_scope_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_capacity_positions
    ADD CONSTRAINT scp_resource_scope_fk FOREIGN KEY (resource_id, agency_id, office_id, departure_id, arrangement_id) REFERENCES public.supplier_resources(id, agency_id, office_id, departure_id, arrangement_id);


--
-- Name: supplier_cost_term_complimentary_ratio_rules sct_comp_ratio_rules_term_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_complimentary_ratio_rules
    ADD CONSTRAINT sct_comp_ratio_rules_term_fk FOREIGN KEY (supplier_cost_term_id, agency_id) REFERENCES public.supplier_cost_terms(id, agency_id);


--
-- Name: supplier_cost_term_fixed_details sct_fixed_term_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_fixed_details
    ADD CONSTRAINT sct_fixed_term_fk FOREIGN KEY (supplier_cost_term_id, agency_id) REFERENCES public.supplier_cost_terms(id, agency_id);


--
-- Name: supplier_cost_term_manual_estimate_details sct_manual_estimate_term_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_manual_estimate_details
    ADD CONSTRAINT sct_manual_estimate_term_fk FOREIGN KEY (supplier_cost_term_id, agency_id) REFERENCES public.supplier_cost_terms(id, agency_id);


--
-- Name: supplier_cost_term_minimum_guarantee_details sct_minimum_guarantee_term_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_minimum_guarantee_details
    ADD CONSTRAINT sct_minimum_guarantee_term_fk FOREIGN KEY (supplier_cost_term_id, agency_id) REFERENCES public.supplier_cost_terms(id, agency_id);


--
-- Name: supplier_cost_term_pass_through_provenances sct_pass_throughs_term_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_pass_through_provenances
    ADD CONSTRAINT sct_pass_throughs_term_fk FOREIGN KEY (supplier_cost_term_id, agency_id) REFERENCES public.supplier_cost_terms(id, agency_id);


--
-- Name: supplier_cost_term_per_night_details sct_per_night_term_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_per_night_details
    ADD CONSTRAINT sct_per_night_term_fk FOREIGN KEY (supplier_cost_term_id, agency_id) REFERENCES public.supplier_cost_terms(id, agency_id);


--
-- Name: supplier_cost_term_per_person_details sct_per_person_term_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_per_person_details
    ADD CONSTRAINT sct_per_person_term_fk FOREIGN KEY (supplier_cost_term_id, agency_id) REFERENCES public.supplier_cost_terms(id, agency_id);


--
-- Name: supplier_cost_term_per_resource_details sct_per_resource_term_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_per_resource_details
    ADD CONSTRAINT sct_per_resource_term_fk FOREIGN KEY (supplier_cost_term_id, agency_id) REFERENCES public.supplier_cost_terms(id, agency_id);


--
-- Name: supplier_cost_term_percentage_base_refs sct_percentage_refs_term_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_percentage_base_refs
    ADD CONSTRAINT sct_percentage_refs_term_fk FOREIGN KEY (supplier_cost_term_id, agency_id) REFERENCES public.supplier_cost_terms(id, agency_id);


--
-- Name: supplier_cost_term_steps sct_steps_term_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_steps
    ADD CONSTRAINT sct_steps_term_fk FOREIGN KEY (supplier_cost_term_id, agency_id) REFERENCES public.supplier_cost_terms(id, agency_id);


--
-- Name: supplier_cost_term_tiers sct_tiers_term_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_term_tiers
    ADD CONSTRAINT sct_tiers_term_fk FOREIGN KEY (supplier_cost_term_id, agency_id) REFERENCES public.supplier_cost_terms(id, agency_id);


--
-- Name: supplier_reservation_resources srr_created_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_resources
    ADD CONSTRAINT srr_created_by_membership_fk FOREIGN KEY (created_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: supplier_reservation_resources srr_reservation_scope_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_resources
    ADD CONSTRAINT srr_reservation_scope_fk FOREIGN KEY (reservation_id, agency_id, office_id, departure_id, arrangement_id) REFERENCES public.supplier_reservations(id, agency_id, office_id, departure_id, arrangement_id);


--
-- Name: supplier_reservation_resources srr_resource_scope_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_resources
    ADD CONSTRAINT srr_resource_scope_fk FOREIGN KEY (resource_id, agency_id, office_id, departure_id, arrangement_id) REFERENCES public.supplier_resources(id, agency_id, office_id, departure_id, arrangement_id);


--
-- Name: supplier_service_category_assignments ssca_profile_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_service_category_assignments
    ADD CONSTRAINT ssca_profile_same_agency_fk FOREIGN KEY (supplier_profile_id, agency_id) REFERENCES public.supplier_profiles(id, agency_id);


--
-- Name: supplier_service_occurrences sso_created_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_service_occurrences
    ADD CONSTRAINT sso_created_by_membership_fk FOREIGN KEY (created_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: supplier_service_occurrences sso_resource_scope_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_service_occurrences
    ADD CONSTRAINT sso_resource_scope_fk FOREIGN KEY (resource_id, agency_id, office_id, departure_id, arrangement_id) REFERENCES public.supplier_resources(id, agency_id, office_id, departure_id, arrangement_id);


--
-- Name: supplier_arrangements supplier_arrangements_created_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangements
    ADD CONSTRAINT supplier_arrangements_created_by_membership_fk FOREIGN KEY (created_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: supplier_arrangements supplier_arrangements_departure_office_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangements
    ADD CONSTRAINT supplier_arrangements_departure_office_fk FOREIGN KEY (departure_id, agency_id, office_id) REFERENCES public.departures(id, agency_id, office_id);


--
-- Name: supplier_arrangements supplier_arrangements_office_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangements
    ADD CONSTRAINT supplier_arrangements_office_same_agency_fk FOREIGN KEY (office_id, agency_id) REFERENCES public.offices(id, agency_id);


--
-- Name: supplier_arrangements supplier_arrangements_parent_same_scope_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangements
    ADD CONSTRAINT supplier_arrangements_parent_same_scope_fk FOREIGN KEY (parent_arrangement_id, agency_id, office_id, departure_id) REFERENCES public.supplier_arrangements(id, agency_id, office_id, departure_id);


--
-- Name: supplier_arrangements supplier_arrangements_provider_party_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangements
    ADD CONSTRAINT supplier_arrangements_provider_party_fk FOREIGN KEY (service_provider_party_id, agency_id) REFERENCES public.parties(id, agency_id);


--
-- Name: supplier_arrangements supplier_arrangements_status_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangements
    ADD CONSTRAINT supplier_arrangements_status_by_membership_fk FOREIGN KEY (status_changed_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: supplier_arrangements supplier_arrangements_supplier_party_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangements
    ADD CONSTRAINT supplier_arrangements_supplier_party_fk FOREIGN KEY (supplier_party_id, agency_id) REFERENCES public.parties(id, agency_id);


--
-- Name: supplier_commitments supplier_commitments_arrangement_scope_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_arrangement_scope_fk FOREIGN KEY (arrangement_id, agency_id, office_id, departure_id) REFERENCES public.supplier_arrangements(id, agency_id, office_id, departure_id);


--
-- Name: supplier_commitments supplier_commitments_created_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_created_by_membership_fk FOREIGN KEY (created_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: supplier_commitments supplier_commitments_departure_office_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_departure_office_fk FOREIGN KEY (departure_id, agency_id, office_id) REFERENCES public.departures(id, agency_id, office_id);


--
-- Name: supplier_commitments supplier_commitments_governing_term_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_governing_term_fk FOREIGN KEY (governing_term_id, agency_id) REFERENCES public.supplier_cost_terms(id, agency_id);


--
-- Name: supplier_commitments supplier_commitments_status_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_status_by_membership_fk FOREIGN KEY (status_changed_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: supplier_commitments supplier_commitments_supersedes_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_commitments
    ADD CONSTRAINT supplier_commitments_supersedes_fk FOREIGN KEY (supersedes_commitment_id, agency_id) REFERENCES public.supplier_commitments(id, agency_id);


--
-- Name: supplier_confirmations supplier_confirmations_arrangement_scope_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmations
    ADD CONSTRAINT supplier_confirmations_arrangement_scope_fk FOREIGN KEY (arrangement_id, agency_id, office_id, departure_id) REFERENCES public.supplier_arrangements(id, agency_id, office_id, departure_id);


--
-- Name: supplier_confirmations supplier_confirmations_departure_office_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmations
    ADD CONSTRAINT supplier_confirmations_departure_office_fk FOREIGN KEY (departure_id, agency_id, office_id) REFERENCES public.departures(id, agency_id, office_id);


--
-- Name: supplier_confirmations supplier_confirmations_entered_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmations
    ADD CONSTRAINT supplier_confirmations_entered_by_membership_fk FOREIGN KEY (entered_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: supplier_confirmations supplier_confirmations_issuer_party_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmations
    ADD CONSTRAINT supplier_confirmations_issuer_party_fk FOREIGN KEY (issuer_party_id, agency_id) REFERENCES public.parties(id, agency_id);


--
-- Name: supplier_confirmations supplier_confirmations_reservation_scope_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmations
    ADD CONSTRAINT supplier_confirmations_reservation_scope_fk FOREIGN KEY (reservation_id, agency_id, office_id, departure_id) REFERENCES public.supplier_reservations(id, agency_id, office_id, departure_id);


--
-- Name: supplier_confirmations supplier_confirmations_superseded_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_confirmations
    ADD CONSTRAINT supplier_confirmations_superseded_by_membership_fk FOREIGN KEY (superseded_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: supplier_cost_terms supplier_cost_terms_arrangement_scope_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_terms
    ADD CONSTRAINT supplier_cost_terms_arrangement_scope_fk FOREIGN KEY (arrangement_id, agency_id, office_id, departure_id) REFERENCES public.supplier_arrangements(id, agency_id, office_id, departure_id);


--
-- Name: supplier_cost_terms supplier_cost_terms_created_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_terms
    ADD CONSTRAINT supplier_cost_terms_created_by_membership_fk FOREIGN KEY (created_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: supplier_cost_terms supplier_cost_terms_departure_office_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_terms
    ADD CONSTRAINT supplier_cost_terms_departure_office_fk FOREIGN KEY (departure_id, agency_id, office_id) REFERENCES public.departures(id, agency_id, office_id);


--
-- Name: supplier_cost_terms supplier_cost_terms_occurrence_scope_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_terms
    ADD CONSTRAINT supplier_cost_terms_occurrence_scope_fk FOREIGN KEY (service_occurrence_id, agency_id) REFERENCES public.supplier_service_occurrences(id, agency_id);


--
-- Name: supplier_cost_terms supplier_cost_terms_reservation_scope_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_terms
    ADD CONSTRAINT supplier_cost_terms_reservation_scope_fk FOREIGN KEY (reservation_id, agency_id, office_id, departure_id, arrangement_id) REFERENCES public.supplier_reservations(id, agency_id, office_id, departure_id, arrangement_id);


--
-- Name: supplier_cost_terms supplier_cost_terms_resource_scope_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_terms
    ADD CONSTRAINT supplier_cost_terms_resource_scope_fk FOREIGN KEY (resource_id, agency_id, office_id, departure_id, arrangement_id) REFERENCES public.supplier_resources(id, agency_id, office_id, departure_id, arrangement_id);


--
-- Name: supplier_cost_terms supplier_cost_terms_status_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_terms
    ADD CONSTRAINT supplier_cost_terms_status_by_membership_fk FOREIGN KEY (status_changed_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: supplier_cost_terms supplier_cost_terms_supersedes_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_cost_terms
    ADD CONSTRAINT supplier_cost_terms_supersedes_fk FOREIGN KEY (supersedes_term_id, agency_id) REFERENCES public.supplier_cost_terms(id, agency_id);


--
-- Name: supplier_deadlines supplier_deadlines_arrangement_scope_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadlines
    ADD CONSTRAINT supplier_deadlines_arrangement_scope_fk FOREIGN KEY (arrangement_id, agency_id, office_id, departure_id) REFERENCES public.supplier_arrangements(id, agency_id, office_id, departure_id);


--
-- Name: supplier_deadlines supplier_deadlines_created_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadlines
    ADD CONSTRAINT supplier_deadlines_created_by_membership_fk FOREIGN KEY (created_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: supplier_deadlines supplier_deadlines_departure_office_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadlines
    ADD CONSTRAINT supplier_deadlines_departure_office_fk FOREIGN KEY (departure_id, agency_id, office_id) REFERENCES public.departures(id, agency_id, office_id);


--
-- Name: supplier_deadlines supplier_deadlines_deposit_source_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadlines
    ADD CONSTRAINT supplier_deadlines_deposit_source_fk FOREIGN KEY (source_deposit_requirement_id, agency_id) REFERENCES public.supplier_deposit_requirements(id, agency_id);


--
-- Name: supplier_deadlines supplier_deadlines_rescheduled_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadlines
    ADD CONSTRAINT supplier_deadlines_rescheduled_by_membership_fk FOREIGN KEY (rescheduled_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: supplier_deadlines supplier_deadlines_status_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadlines
    ADD CONSTRAINT supplier_deadlines_status_by_membership_fk FOREIGN KEY (status_changed_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: supplier_deposit_requirements supplier_deposits_arrangement_scope_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deposit_requirements
    ADD CONSTRAINT supplier_deposits_arrangement_scope_fk FOREIGN KEY (arrangement_id, agency_id, office_id, departure_id) REFERENCES public.supplier_arrangements(id, agency_id, office_id, departure_id);


--
-- Name: supplier_deposit_requirements supplier_deposits_cost_term_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deposit_requirements
    ADD CONSTRAINT supplier_deposits_cost_term_fk FOREIGN KEY (supplier_cost_term_id, agency_id) REFERENCES public.supplier_cost_terms(id, agency_id);


--
-- Name: supplier_deposit_requirements supplier_deposits_created_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deposit_requirements
    ADD CONSTRAINT supplier_deposits_created_by_membership_fk FOREIGN KEY (created_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: supplier_deposit_requirements supplier_deposits_departure_office_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deposit_requirements
    ADD CONSTRAINT supplier_deposits_departure_office_fk FOREIGN KEY (departure_id, agency_id, office_id) REFERENCES public.departures(id, agency_id, office_id);


--
-- Name: supplier_deposit_requirements supplier_deposits_status_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deposit_requirements
    ADD CONSTRAINT supplier_deposits_status_by_membership_fk FOREIGN KEY (status_changed_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: supplier_profiles supplier_profiles_deactivated_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_profiles
    ADD CONSTRAINT supplier_profiles_deactivated_by_membership_fk FOREIGN KEY (deactivated_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: supplier_profiles supplier_profiles_office_active_projection_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_profiles
    ADD CONSTRAINT supplier_profiles_office_active_projection_fk FOREIGN KEY (responsible_office_id, agency_id, responsible_office_status) REFERENCES public.offices(id, agency_id, status);


--
-- Name: supplier_profiles supplier_profiles_office_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_profiles
    ADD CONSTRAINT supplier_profiles_office_same_agency_fk FOREIGN KEY (responsible_office_id, agency_id) REFERENCES public.offices(id, agency_id);


--
-- Name: supplier_profiles supplier_profiles_party_active_projection_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_profiles
    ADD CONSTRAINT supplier_profiles_party_active_projection_fk FOREIGN KEY (party_id, agency_id, party_status) REFERENCES public.parties(id, agency_id, status);


--
-- Name: supplier_profiles supplier_profiles_party_kind_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_profiles
    ADD CONSTRAINT supplier_profiles_party_kind_same_agency_fk FOREIGN KEY (party_id, agency_id, party_kind) REFERENCES public.parties(id, agency_id, party_kind);


--
-- Name: supplier_reservations supplier_reservations_arrangement_scope_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservations
    ADD CONSTRAINT supplier_reservations_arrangement_scope_fk FOREIGN KEY (arrangement_id, agency_id, office_id, departure_id) REFERENCES public.supplier_arrangements(id, agency_id, office_id, departure_id);


--
-- Name: supplier_reservations supplier_reservations_confirmed_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservations
    ADD CONSTRAINT supplier_reservations_confirmed_by_membership_fk FOREIGN KEY (confirmed_without_identifier_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: supplier_reservations supplier_reservations_created_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservations
    ADD CONSTRAINT supplier_reservations_created_by_membership_fk FOREIGN KEY (created_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: supplier_reservations supplier_reservations_departure_office_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservations
    ADD CONSTRAINT supplier_reservations_departure_office_fk FOREIGN KEY (departure_id, agency_id, office_id) REFERENCES public.departures(id, agency_id, office_id);


--
-- Name: supplier_reservations supplier_reservations_status_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservations
    ADD CONSTRAINT supplier_reservations_status_by_membership_fk FOREIGN KEY (status_changed_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: supplier_resources supplier_resources_arrangement_scope_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_resources
    ADD CONSTRAINT supplier_resources_arrangement_scope_fk FOREIGN KEY (arrangement_id, agency_id, office_id, departure_id) REFERENCES public.supplier_arrangements(id, agency_id, office_id, departure_id);


--
-- Name: supplier_resources supplier_resources_created_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_resources
    ADD CONSTRAINT supplier_resources_created_by_membership_fk FOREIGN KEY (created_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: supplier_resources supplier_resources_departure_office_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_resources
    ADD CONSTRAINT supplier_resources_departure_office_fk FOREIGN KEY (departure_id, agency_id, office_id) REFERENCES public.departures(id, agency_id, office_id);


--
-- Name: supplier_resources supplier_resources_status_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_resources
    ADD CONSTRAINT supplier_resources_status_by_membership_fk FOREIGN KEY (status_changed_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- Name: travel_programs travel_programs_inactivated_by_membership_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.travel_programs
    ADD CONSTRAINT travel_programs_inactivated_by_membership_fk FOREIGN KEY (inactivated_by_membership_id, agency_id) REFERENCES public.agency_memberships(id, agency_id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260909200000'),
('20260909190000'),
('20260909180000'),
('20260909170000'),
('20260909120000'),
('20260909011000'),
('20260909010000'),
('20260908010000'),
('20260907185600'),
('20260907185500'),
('20260907185000'),
('20260907184500'),
('20260907184000'),
('20260907173000'),
('20260907050000'),
('20260907040000'),
('20260907030000'),
('20260907020000'),
('20260907010000'),
('20260906030000'),
('20260906020000'),
('20260906010000'),
('20260905234500'),
('20260905230000'),
('20260905220000'),
('20260905210000'),
('20260905200000'),
('20260905190000'),
('20260905180000'),
('20260905034356'),
('20260905034233'),
('20260905031826'),
('20260905031825'),
('20260905031803');

