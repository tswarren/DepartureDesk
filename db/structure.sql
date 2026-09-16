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
-- Name: dd_search_normalize(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dd_search_normalize(input text) RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    RETURN regexp_replace(btrim(NORMALIZE(casefold((NORMALIZE(input, NFKC) COLLATE pg_unicode_fast)), NFKC)), '[[:space:]]+'::text, ' '::text, 'g'::text);


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
    CONSTRAINT arrangement_item_definitions_capacity_management CHECK (((capacity_management IS NULL) OR ((capacity_management)::text = ANY ((ARRAY['managed'::character varying, 'unmanaged'::character varying])::text[])))),
    CONSTRAINT arrangement_item_definitions_category CHECK (((category)::text = ANY (ARRAY[('cruise'::character varying)::text, ('lodging'::character varying)::text, ('air'::character varying)::text, ('ground_transportation'::character varying)::text, ('dining'::character varying)::text, ('activity_attraction'::character varying)::text, ('insurance'::character varying)::text, ('other'::character varying)::text]))),
    CONSTRAINT arrangement_item_definitions_description CHECK (((description IS NULL) OR ((btrim((description)::text) <> ''::text) AND (char_length((description)::text) <= 2000)))),
    CONSTRAINT arrangement_item_definitions_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT arrangement_item_definitions_name CHECK (((btrim((name)::text) <> ''::text) AND (char_length((name)::text) <= 160))),
    CONSTRAINT arrangement_item_definitions_other_label CHECK (((((category)::text = 'other'::text) = (other_category_label IS NOT NULL)) AND ((other_category_label IS NULL) OR ((btrim((other_category_label)::text) <> ''::text) AND (char_length((other_category_label)::text) <= 80))))),
    CONSTRAINT arrangement_item_definitions_position_positive CHECK (("position" > 0))
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
    CONSTRAINT client_org_email_addresses_status CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('inactive'::character varying)::text]))),
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
    CONSTRAINT client_org_phone_numbers_status CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('inactive'::character varying)::text]))),
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
    CONSTRAINT client_org_postal_addresses_status CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('inactive'::character varying)::text]))),
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
    CONSTRAINT client_org_websites_status CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('inactive'::character varying)::text]))),
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
    CONSTRAINT client_organizations_status CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('inactive'::character varying)::text])))
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
    CONSTRAINT client_people_status CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('inactive'::character varying)::text])))
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
    CONSTRAINT client_person_email_addresses_status CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('inactive'::character varying)::text])))
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
    CONSTRAINT client_person_phone_numbers_status CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('inactive'::character varying)::text])))
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
    CONSTRAINT client_person_postal_addresses_status CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('inactive'::character varying)::text])))
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
    CONSTRAINT clients_status CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('inactive'::character varying)::text])))
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
    CONSTRAINT departures_status CHECK (((status)::text = ANY (ARRAY[('draft'::character varying)::text, ('active'::character varying)::text, ('departed'::character varying)::text])))
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
    CONSTRAINT reference_sequences_namespace CHECK (((namespace)::text = ANY (ARRAY[('client'::character varying)::text, ('supplier'::character varying)::text, ('departure'::character varying)::text]))),
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
    CONSTRAINT service_occurrences_status CHECK (((status)::text = ANY (ARRAY[('planned'::character varying)::text, ('cancelled'::character varying)::text])))
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
    CONSTRAINT supplier_arrangement_versions_abandoned_at_pair CHECK ((((status)::text = 'abandoned'::text) = (abandoned_at IS NOT NULL))),
    CONSTRAINT supplier_arrangement_versions_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_arrangement_versions_number_positive CHECK ((version_number > 0)),
    CONSTRAINT supplier_arrangement_versions_reason CHECK (((abandoned_reason IS NULL) OR ((btrim((abandoned_reason)::text) <> ''::text) AND (char_length((abandoned_reason)::text) <= 500)))),
    CONSTRAINT supplier_arrangement_versions_reason_pair CHECK ((((status)::text = 'abandoned'::text) = (abandoned_reason IS NOT NULL))),
    CONSTRAINT supplier_arrangement_versions_status CHECK (((status)::text = ANY (ARRAY[('draft'::character varying)::text, ('activated'::character varying)::text, ('superseded'::character varying)::text, ('abandoned'::character varying)::text])))
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
    CONSTRAINT supplier_arrangements_abandoned_at_pair CHECK ((((status)::text = 'abandoned'::text) = (abandoned_at IS NOT NULL))),
    CONSTRAINT supplier_arrangements_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_arrangements_name CHECK (((btrim((name)::text) <> ''::text) AND (char_length((name)::text) <= 160))),
    CONSTRAINT supplier_arrangements_status CHECK (((status)::text = ANY (ARRAY[('draft'::character varying)::text, ('active'::character varying)::text, ('ended'::character varying)::text, ('abandoned'::character varying)::text])))
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
    CONSTRAINT supplier_category_assignments_code CHECK (((category_code)::text = ANY (ARRAY[('cruise_line'::character varying)::text, ('lodging'::character varying)::text, ('air'::character varying)::text, ('ground_transportation'::character varying)::text, ('tour_operator_dmc'::character varying)::text, ('dining'::character varying)::text, ('activity_attraction'::character varying)::text, ('insurance'::character varying)::text, ('other'::character varying)::text]))),
    CONSTRAINT supplier_category_assignments_other_label CHECK (((((category_code)::text = 'other'::text) AND (other_label IS NOT NULL) AND ((other_label)::text = btrim((other_label)::text)) AND (btrim((other_label)::text) <> ''::text) AND (char_length((other_label)::text) <= 80)) OR (((category_code)::text <> 'other'::text) AND (other_label IS NULL))))
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
    CONSTRAINT supplier_contact_email_addresses_status CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('inactive'::character varying)::text])))
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
    CONSTRAINT supplier_contact_phone_numbers_status CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('inactive'::character varying)::text])))
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
    CONSTRAINT supplier_contacts_status CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('inactive'::character varying)::text]))),
    CONSTRAINT supplier_contacts_title CHECK (((title IS NULL) OR ((btrim((title)::text) <> ''::text) AND (char_length((title)::text) <= 120))))
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
    CONSTRAINT supplier_email_addresses_status CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('inactive'::character varying)::text])))
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
    CONSTRAINT supplier_locations_status CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('inactive'::character varying)::text])))
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
    CONSTRAINT supplier_phone_numbers_status CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('inactive'::character varying)::text])))
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
    CONSTRAINT supplier_postal_addresses_status CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('inactive'::character varying)::text])))
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
    CONSTRAINT supplier_websites_status CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('inactive'::character varying)::text]))),
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
    CONSTRAINT suppliers_kind CHECK (((kind)::text = ANY (ARRAY[('organization'::character varying)::text, ('individual'::character varying)::text]))),
    CONSTRAINT suppliers_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT suppliers_name_shape CHECK (((((kind)::text = 'organization'::text) AND (display_name IS NOT NULL) AND (btrim((display_name)::text) <> ''::text) AND (first_name IS NULL) AND (last_name IS NULL)) OR (((kind)::text = 'individual'::text) AND (first_name IS NOT NULL) AND (btrim((first_name)::text) <> ''::text) AND (last_name IS NOT NULL) AND (btrim((last_name)::text) <> ''::text) AND (display_name IS NULL) AND (legal_name IS NULL)))),
    CONSTRAINT suppliers_reference_format CHECK (((supplier_reference)::text ~ '^SUP-[0-9]{6}$'::text)),
    CONSTRAINT suppliers_status CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('inactive'::character varying)::text])))
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
-- Name: supplier_email_addresses supplier_email_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_email_addresses
    ADD CONSTRAINT supplier_email_addresses_pkey PRIMARY KEY (id);


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

CREATE UNIQUE INDEX index_capacity_events_on_idempotency_key ON public.capacity_events USING btree (agency_command_idempotency_key_id) WHERE (agency_command_idempotency_key_id IS NOT NULL);


--
-- Name: index_capacity_events_on_pool_date_sequence; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_events_on_pool_date_sequence ON public.capacity_events USING btree (capacity_pool_id, effective_on, effective_sequence);


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
-- Name: index_command_idempotency_on_agency_command_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_command_idempotency_on_agency_command_key ON public.agency_command_idempotency_keys USING btree (agency_id, command_name, idempotency_key);


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
-- Name: index_sessions_on_agency_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_agency_user_id ON public.sessions USING btree (agency_user_id);


--
-- Name: index_sessions_on_office_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_office_id ON public.sessions USING btree (office_id);


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
-- Name: agencies agencies_reject_workspace_code_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER agencies_reject_workspace_code_change BEFORE UPDATE ON public.agencies FOR EACH ROW EXECUTE FUNCTION public.reject_agency_workspace_code_change();


--
-- Name: agency_users agency_users_reject_agency_id_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER agency_users_reject_agency_id_change BEFORE UPDATE ON public.agency_users FOR EACH ROW EXECUTE FUNCTION public.reject_agency_user_agency_change();


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
-- Name: capacity_events capacity_events_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_events_reject_update BEFORE UPDATE ON public.capacity_events FOR EACH ROW EXECUTE FUNCTION public.reject_capacity_event_mutation();


--
-- Name: capacity_pair_definitions capacity_pair_definitions_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_pair_definitions_reject_owner_change BEFORE UPDATE ON public.capacity_pair_definitions FOR EACH ROW EXECUTE FUNCTION public.reject_capacity_pair_definition_owner_change();


--
-- Name: capacity_pair_definitions capacity_pairs_reject_cancelled_occurrence; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_pairs_reject_cancelled_occurrence BEFORE INSERT OR UPDATE OF service_occurrence_id ON public.capacity_pair_definitions FOR EACH ROW EXECUTE FUNCTION public.reject_capacity_pair_for_cancelled_occurrence();


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
-- Name: service_occurrence_definitions service_occurrence_definitions_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER service_occurrence_definitions_reject_owner_change BEFORE UPDATE ON public.service_occurrence_definitions FOR EACH ROW EXECUTE FUNCTION public.reject_service_occurrence_definition_owner_change();


--
-- Name: service_occurrences service_occurrences_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER service_occurrences_reject_owner_change BEFORE UPDATE ON public.service_occurrences FOR EACH ROW EXECUTE FUNCTION public.reject_service_occurrence_owner_change();


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
-- Name: supplier_email_addresses supplier_email_addresses_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_email_addresses_reject_owner_change BEFORE UPDATE ON public.supplier_email_addresses FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_contact_owner_change();


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
-- Name: agency_users agency_users_default_office_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agency_users
    ADD CONSTRAINT agency_users_default_office_fk FOREIGN KEY (default_office_id, agency_id) REFERENCES public.offices(id, agency_id);


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
-- Name: capacity_projections fk_rails_308824deff; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_projections
    ADD CONSTRAINT fk_rails_308824deff FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_resource_definitions fk_rails_32a78d1b5b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_resource_definitions
    ADD CONSTRAINT fk_rails_32a78d1b5b FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


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
-- Name: capacity_reconciliation_resolutions fk_rails_6af96c37bf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_reconciliation_resolutions
    ADD CONSTRAINT fk_rails_6af96c37bf FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


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
-- Name: supplier_contacts fk_rails_8eda2b4f49; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_contacts
    ADD CONSTRAINT fk_rails_8eda2b4f49 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


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
-- Name: supplier_contact_phone_numbers fk_rails_a8cbb23af8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_contact_phone_numbers
    ADD CONSTRAINT fk_rails_a8cbb23af8 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: client_organization_email_addresses fk_rails_b2180601e2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_organization_email_addresses
    ADD CONSTRAINT fk_rails_b2180601e2 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


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
-- Name: supplier_category_assignments supplier_category_assignments_supplier_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_category_assignments
    ADD CONSTRAINT supplier_category_assignments_supplier_agency_fk FOREIGN KEY (supplier_id, agency_id) REFERENCES public.suppliers(id, agency_id);


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
-- Name: supplier_email_addresses supplier_email_addresses_supplier_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_email_addresses
    ADD CONSTRAINT supplier_email_addresses_supplier_agency_fk FOREIGN KEY (supplier_id, agency_id) REFERENCES public.suppliers(id, agency_id);


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

