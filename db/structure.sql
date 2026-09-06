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
    CONSTRAINT agency_memberships_role_valid CHECK (((role)::text = ANY ((ARRAY['staff'::character varying, 'administrator'::character varying])::text[]))),
    CONSTRAINT agency_memberships_status_valid CHECK (((status)::text = ANY ((ARRAY['invited'::character varying, 'active'::character varying, 'suspended'::character varying, 'revoked'::character varying])::text[])))
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
    CONSTRAINT contact_point_purpose_assignments_purpose_valid CHECK (((purpose)::text = ANY ((ARRAY['general'::character varying, 'correspondence'::character varying, 'billing'::character varying])::text[]))),
    CONSTRAINT contact_point_purpose_assignments_range_order CHECK (((effective_until IS NULL) OR (effective_from IS NULL) OR (effective_until > effective_from))),
    CONSTRAINT contact_point_purpose_assignments_record_status_valid CHECK (((record_status)::text = ANY ((ARRAY['valid'::character varying, 'superseded'::character varying, 'voided'::character varying])::text[]))),
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
    CONSTRAINT delivery_intents_purpose_valid CHECK (((purpose)::text = ANY ((ARRAY['team_invitation'::character varying, 'password_reset'::character varying])::text[]))),
    CONSTRAINT delivery_intents_status_valid CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'processing'::character varying, 'succeeded'::character varying, 'discarded'::character varying])::text[]))),
    CONSTRAINT delivery_intents_success_has_delivery_time CHECK (((((status)::text = 'succeeded'::text) AND (delivered_at IS NOT NULL)) OR (((status)::text <> 'succeeded'::text) AND (delivered_at IS NULL))))
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
    CONSTRAINT office_assignments_status_valid CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'revoked'::character varying])::text[])))
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
    CONSTRAINT offices_status_valid CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[]))),
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
    CONSTRAINT parties_party_kind_valid CHECK (((party_kind)::text = ANY ((ARRAY['person'::character varying, 'household'::character varying, 'organization'::character varying])::text[]))),
    CONSTRAINT parties_sort_name_not_blank CHECK ((btrim((sort_name)::text) <> ''::text)),
    CONSTRAINT parties_status_valid CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'deactivated'::character varying])::text[])))
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
    CONSTRAINT party_alternate_names_name_kind_valid CHECK (((name_kind)::text = ANY ((ARRAY['former_name'::character varying, 'alias'::character varying, 'additional_trading_name'::character varying, 'acronym'::character varying, 'imported_name'::character varying])::text[]))),
    CONSTRAINT party_alternate_names_name_not_blank CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT party_alternate_names_normalized_name_not_blank CHECK ((btrim((normalized_name)::text) <> ''::text)),
    CONSTRAINT party_alternate_names_removal_matches_status CHECK (((((status)::text = 'active'::text) AND (removed_at IS NULL) AND (removed_by_membership_id IS NULL)) OR (((status)::text = 'removed'::text) AND (removed_at IS NOT NULL) AND (removed_by_membership_id IS NOT NULL)))),
    CONSTRAINT party_alternate_names_status_valid CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'removed'::character varying])::text[])))
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
    CONSTRAINT party_contact_points_contact_kind_valid CHECK (((contact_kind)::text = ANY ((ARRAY['postal_address'::character varying, 'phone'::character varying, 'email'::character varying])::text[]))),
    CONSTRAINT party_contact_points_deactivation_matches_status CHECK (((((status)::text = 'active'::text) AND (deactivated_at IS NULL) AND (deactivated_by_membership_id IS NULL) AND (deactivation_reason IS NULL)) OR (((status)::text = 'deactivated'::text) AND (deactivated_at IS NOT NULL) AND (deactivated_by_membership_id IS NOT NULL) AND (btrim((deactivation_reason)::text) <> ''::text)))),
    CONSTRAINT party_contact_points_label_null_or_not_blank CHECK (((label IS NULL) OR (btrim((label)::text) <> ''::text))),
    CONSTRAINT party_contact_points_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT party_contact_points_normalized_value_not_blank CHECK ((btrim((normalized_value)::text) <> ''::text)),
    CONSTRAINT party_contact_points_status_valid CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'deactivated'::character varying])::text[]))),
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
    CONSTRAINT party_email_addresses_email_type_valid CHECK (((email_type)::text = ANY ((ARRAY['personal'::character varying, 'work'::character varying, 'general'::character varying, 'booking'::character varying, 'accounting'::character varying, 'other'::character varying])::text[]))),
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
    CONSTRAINT party_notes_record_status_valid CHECK (((record_status)::text = ANY ((ARRAY['active'::character varying, 'superseded'::character varying, 'removed'::character varying])::text[]))),
    CONSTRAINT party_notes_visibility_valid CHECK (((visibility)::text = ANY ((ARRAY['standard'::character varying, 'administrator_only'::character varying])::text[])))
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
    CONSTRAINT party_phone_numbers_parse_status_valid CHECK (((parse_status)::text = ANY ((ARRAY['valid'::character varying, 'possible'::character varying, 'unparsed'::character varying])::text[]))),
    CONSTRAINT party_phone_numbers_parsed_country_code_format CHECK (((parsed_country_code IS NULL) OR ((parsed_country_code)::text ~ '^[A-Z]{2}$'::text))),
    CONSTRAINT party_phone_numbers_phone_type_valid CHECK (((phone_type)::text = ANY ((ARRAY['mobile'::character varying, 'home'::character varying, 'work'::character varying, 'main'::character varying, 'fax'::character varying, 'other'::character varying])::text[])))
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
    CONSTRAINT party_relationships_kind_valid CHECK (((relationship_kind)::text = ANY ((ARRAY['household_member'::character varying, 'family'::character varying, 'organization_affiliation'::character varying, 'organization_contact'::character varying, 'parent_organization'::character varying, 'service_provider_for'::character varying])::text[]))),
    CONSTRAINT party_relationships_label_matches_kind CHECK (((((relationship_kind)::text = 'family'::text) AND ((relationship_label)::text = ANY ((ARRAY['parent_of'::character varying, 'child_of'::character varying, 'guardian_of'::character varying, 'dependent_of'::character varying, 'spouse_of'::character varying, 'partner_of'::character varying, 'other_family'::character varying])::text[]))) OR (((relationship_kind)::text = 'organization_affiliation'::text) AND ((relationship_label)::text = ANY ((ARRAY['employee'::character varying, 'contractor'::character varying, 'owner'::character varying, 'member'::character varying, 'representative'::character varying, 'other'::character varying])::text[]))) OR (((relationship_kind)::text = ANY ((ARRAY['household_member'::character varying, 'organization_contact'::character varying, 'parent_organization'::character varying, 'service_provider_for'::character varying])::text[])) AND (relationship_label IS NULL)))),
    CONSTRAINT party_relationships_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT party_relationships_no_self CHECK ((origin_party_id <> related_party_id)),
    CONSTRAINT party_relationships_range_order CHECK (((effective_until IS NULL) OR (effective_from IS NULL) OR (effective_until > effective_from))),
    CONSTRAINT party_relationships_record_status_valid CHECK (((record_status)::text = ANY ((ARRAY['valid'::character varying, 'superseded'::character varying, 'voided'::character varying])::text[]))),
    CONSTRAINT party_relationships_spouse_canonical_order CHECK ((((relationship_kind)::text <> 'family'::text) OR ((relationship_label)::text <> ALL ((ARRAY['spouse_of'::character varying, 'partner_of'::character varying])::text[])) OR (origin_party_id < related_party_id))),
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
    CONSTRAINT rpa_purpose_valid CHECK (((purpose)::text = ANY ((ARRAY['general'::character varying, 'booking'::character varying, 'accounting'::character varying])::text[]))),
    CONSTRAINT rpa_range_order CHECK (((effective_until IS NULL) OR (effective_from IS NULL) OR (effective_until > effective_from))),
    CONSTRAINT rpa_record_status_valid CHECK (((record_status)::text = ANY ((ARRAY['valid'::character varying, 'superseded'::character varying, 'voided'::character varying])::text[])))
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
    ADD CONSTRAINT pr_affiliation_contact_conflict EXCLUDE USING gist (agency_id WITH =, origin_party_id WITH =, related_party_id WITH =, daterange(effective_from, effective_until, '[)'::text) WITH &&) WHERE ((((record_status)::text = 'valid'::text) AND ((relationship_kind)::text = ANY ((ARRAY['organization_affiliation'::character varying, 'organization_contact'::character varying])::text[]))));


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
    ADD CONSTRAINT pr_unique_valid_spouse_pair EXCLUDE USING gist (agency_id WITH =, LEAST(origin_party_id, related_party_id) WITH =, GREATEST(origin_party_id, related_party_id) WITH =, relationship_label WITH =, daterange(effective_from, effective_until, '[)'::text) WITH &&) WHERE ((((record_status)::text = 'valid'::text) AND ((relationship_kind)::text = 'family'::text) AND ((relationship_label)::text = ANY ((ARRAY['spouse_of'::character varying, 'partner_of'::character varying])::text[]))));


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
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


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
-- Name: index_contact_point_purpose_assignments_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contact_point_purpose_assignments_on_agency_id ON public.contact_point_purpose_assignments USING btree (agency_id);


--
-- Name: index_contact_point_purpose_assignments_on_contact_point; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contact_point_purpose_assignments_on_contact_point ON public.contact_point_purpose_assignments USING btree (contact_point_id, agency_id);


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
-- Name: index_parties_on_id_agency_id_and_party_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_parties_on_id_agency_id_and_party_kind ON public.parties USING btree (id, agency_id, party_kind);


--
-- Name: index_parties_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_parties_on_id_and_agency_id ON public.parties USING btree (id, agency_id);


--
-- Name: index_party_alternate_names_on_agency_id_and_normalized_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_party_alternate_names_on_agency_id_and_normalized_name ON public.party_alternate_names USING btree (agency_id, normalized_name);


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
-- Name: index_rpa_on_relationship; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rpa_on_relationship ON public.relationship_purpose_assignments USING btree (relationship_id, agency_id);


--
-- Name: index_sessions_on_office_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_office_id ON public.sessions USING btree (office_id);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


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
-- Name: agency_memberships agency_memberships_person_party_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agency_memberships
    ADD CONSTRAINT agency_memberships_person_party_same_agency_fk FOREIGN KEY (person_party_id, agency_id) REFERENCES public.people(party_id, agency_id);


--
-- Name: contact_point_purpose_assignments cppa_contact_kind_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact_point_purpose_assignments
    ADD CONSTRAINT cppa_contact_kind_same_agency_fk FOREIGN KEY (contact_point_id, agency_id, contact_kind) REFERENCES public.party_contact_points(id, agency_id, contact_kind);


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
    ADD CONSTRAINT cppa_superseded_by_fk FOREIGN KEY (superseded_by_assignment_id) REFERENCES public.contact_point_purpose_assignments(id);


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
-- Name: agency_memberships fk_rails_3bdac11d3b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agency_memberships
    ADD CONSTRAINT fk_rails_3bdac11d3b FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


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
-- Name: party_email_addresses fk_rails_51fb47a3a2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.party_email_addresses
    ADD CONSTRAINT fk_rails_51fb47a3a2 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


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
-- Name: audit_events fk_rails_8512cd9707; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT fk_rails_8512cd9707 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


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
-- Name: people fk_rails_beffb17c89; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.people
    ADD CONSTRAINT fk_rails_beffb17c89 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


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
-- Name: relationship_purpose_assignments rpa_organization_party_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relationship_purpose_assignments
    ADD CONSTRAINT rpa_organization_party_same_agency_fk FOREIGN KEY (organization_party_id, agency_id) REFERENCES public.parties(id, agency_id);


--
-- Name: relationship_purpose_assignments rpa_relationship_same_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relationship_purpose_assignments
    ADD CONSTRAINT rpa_relationship_same_agency_fk FOREIGN KEY (relationship_id, agency_id) REFERENCES public.party_relationships(id, agency_id);


--
-- Name: relationship_purpose_assignments rpa_superseded_by_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relationship_purpose_assignments
    ADD CONSTRAINT rpa_superseded_by_fk FOREIGN KEY (superseded_by_assignment_id) REFERENCES public.relationship_purpose_assignments(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
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

