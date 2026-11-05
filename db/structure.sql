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
-- Name: reject_departure_decision_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_departure_decision_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'departure decisions are append-only';
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
  IF NEW.departure_reference IS DISTINCT FROM OLD.departure_reference THEN
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
    legal_name character varying,
    workspace_code character varying NOT NULL,
    country_code character varying(2) NOT NULL,
    default_currency character varying(3) NOT NULL,
    default_timezone character varying NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    contact_email character varying,
    agency_contact_name character varying,
    phone_number character varying,
    phone_normalized_number character varying,
    phone_extension character varying,
    phone_country_code character varying,
    address_line_1 character varying,
    address_line_2 character varying,
    address_locality character varying,
    address_region character varying,
    address_postal_code character varying,
    address_country_code character varying,
    seller_of_travel_disclosure text,
    confirmation_footer text,
    financial_document_footer text,
    hold_duration_days integer DEFAULT 2 NOT NULL,
    installment_buffer_days integer DEFAULT 14 NOT NULL,
    CONSTRAINT agencies_address_complete CHECK ((((address_line_1 IS NULL) AND (address_line_2 IS NULL) AND (address_locality IS NULL) AND (address_region IS NULL) AND (address_postal_code IS NULL) AND (address_country_code IS NULL)) OR ((address_line_1 IS NOT NULL) AND (btrim((address_line_1)::text) <> ''::text) AND (address_country_code IS NOT NULL) AND ((address_country_code)::text ~ '^[A-Z]{2}$'::text)))),
    CONSTRAINT agencies_contact_email_normalized CHECK (((contact_email IS NULL) OR ((contact_email)::text = lower(btrim((contact_email)::text))))),
    CONSTRAINT agencies_country_code_format CHECK (((country_code)::text ~ '^[A-Z]{2}$'::text)),
    CONSTRAINT agencies_currency_format CHECK (((default_currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT agencies_hold_duration_positive CHECK ((hold_duration_days >= 1)),
    CONSTRAINT agencies_installment_buffer_nonnegative CHECK ((installment_buffer_days >= 0)),
    CONSTRAINT agencies_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT agencies_name_not_blank CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT agencies_phone_complete CHECK (((phone_number IS NULL) OR ((phone_normalized_number IS NOT NULL) AND ((phone_normalized_number)::text ~ '^\+[1-9][0-9]{0,14}$'::text) AND (phone_country_code IS NOT NULL) AND ((phone_country_code)::text ~ '^[A-Z]{2}$'::text)))),
    CONSTRAINT agencies_phone_extension_needs_number CHECK (((phone_extension IS NULL) OR (phone_number IS NOT NULL))),
    CONSTRAINT agencies_status_valid CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('suspended'::character varying)::text, ('closed'::character varying)::text]))),
    CONSTRAINT agencies_workspace_code_format CHECK (((workspace_code)::text ~ '^[a-z][a-z0-9-]{1,39}$'::text))
);


--
-- Name: agency_document_inclusions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agency_document_inclusions (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    document_family character varying NOT NULL,
    include_display_name boolean NOT NULL,
    include_contact_email boolean NOT NULL,
    include_phone boolean NOT NULL,
    include_legal_name boolean NOT NULL,
    include_mailing_address boolean NOT NULL,
    include_agency_contact_name boolean NOT NULL,
    include_seller_of_travel_disclosure boolean CONSTRAINT agency_document_inclusions_include_seller_of_travel_di_not_null NOT NULL,
    include_footer boolean NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT agency_document_inclusions_family_valid CHECK (((document_family)::text = ANY ((ARRAY['confirmation'::character varying, 'invoice'::character varying, 'receipt'::character varying, 'statement'::character varying])::text[])))
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
    user_type character varying CONSTRAINT agency_users_access_role_not_null NOT NULL,
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
    reseller_id uuid,
    CONSTRAINT agency_users_credential_version_nonnegative CHECK ((credential_version >= 0)),
    CONSTRAINT agency_users_email_normalized CHECK (((email_address)::text = lower(btrim((email_address)::text)))),
    CONSTRAINT agency_users_email_not_blank CHECK ((btrim((email_address)::text) <> ''::text)),
    CONSTRAINT agency_users_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT agency_users_name_not_blank CHECK (((btrim((first_name)::text) <> ''::text) AND (btrim((last_name)::text) <> ''::text))),
    CONSTRAINT agency_users_reseller_iff_reseller_type CHECK ((((user_type)::text = 'reseller'::text) = (reseller_id IS NOT NULL))),
    CONSTRAINT agency_users_status_credentials CHECK (((((status)::text = 'invited'::text) AND (invitation_token_digest IS NOT NULL) AND (invitation_expires_at IS NOT NULL) AND (password_digest IS NULL)) OR (((status)::text = 'active'::text) AND (password_digest IS NOT NULL) AND (invitation_token_digest IS NULL)) OR (((status)::text = ANY (ARRAY[('suspended'::character varying)::text, ('closed'::character varying)::text])) AND (invitation_token_digest IS NULL)))),
    CONSTRAINT agency_users_status_valid CHECK (((status)::text = ANY (ARRAY[('invited'::character varying)::text, ('active'::character varying)::text, ('suspended'::character varying)::text, ('closed'::character varying)::text]))),
    CONSTRAINT agency_users_user_type_valid CHECK (((user_type)::text = ANY ((ARRAY['agency_admin'::character varying, 'staff'::character varying, 'reseller'::character varying])::text[])))
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
-- Name: departure_decisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.departure_decisions (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    decision character varying NOT NULL,
    note text,
    decided_by_id uuid NOT NULL,
    decided_at timestamp(6) with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT departure_decisions_decision CHECK (((decision)::text = ANY ((ARRAY['proceed'::character varying, 'postpone'::character varying, 'cancel'::character varying])::text[]))),
    CONSTRAINT departure_decisions_note CHECK (((note IS NULL) OR ((btrim(note) <> ''::text) AND (char_length(note) <= 2000)))),
    CONSTRAINT departure_decisions_note_required CHECK ((((decision)::text = 'proceed'::text) OR (note IS NOT NULL)))
);


--
-- Name: departure_team_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.departure_team_members (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    agency_user_id uuid NOT NULL,
    default_task_owner boolean DEFAULT false NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: departures; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.departures (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_reference character varying NOT NULL,
    name character varying(160) NOT NULL,
    description character varying(2000),
    starts_on date,
    ends_on date,
    time_zone character varying,
    operating_currency character varying(3),
    departed_at timestamp with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    name_search_key text GENERATED ALWAYS AS (public.dd_search_normalize((name)::text)) STORED,
    sales_status character varying DEFAULT 'draft'::character varying NOT NULL,
    operating_decision character varying DEFAULT 'undecided'::character varying NOT NULL,
    completion_status character varying DEFAULT 'active'::character varying NOT NULL,
    hold_duration_days integer,
    installment_buffer_days integer,
    CONSTRAINT departures_completion_status CHECK (((completion_status)::text = ANY ((ARRAY['active'::character varying, 'departed'::character varying, 'cancelled'::character varying, 'superseded'::character varying])::text[]))),
    CONSTRAINT departures_date_order CHECK (((starts_on IS NULL) OR (starts_on <= ends_on))),
    CONSTRAINT departures_dates_paired CHECK (((starts_on IS NULL) = (ends_on IS NULL))),
    CONSTRAINT departures_departed_at_pair CHECK ((((completion_status)::text = 'departed'::text) = (departed_at IS NOT NULL))),
    CONSTRAINT departures_description CHECK (((description IS NULL) OR ((btrim((description)::text) <> ''::text) AND (char_length((description)::text) <= 2000)))),
    CONSTRAINT departures_hold_duration_positive CHECK (((hold_duration_days IS NULL) OR (hold_duration_days >= 1))),
    CONSTRAINT departures_installment_buffer_nonnegative CHECK (((installment_buffer_days IS NULL) OR (installment_buffer_days >= 0))),
    CONSTRAINT departures_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT departures_name CHECK (((name IS NOT NULL) AND (btrim((name)::text) <> ''::text) AND (char_length((name)::text) <= 160))),
    CONSTRAINT departures_operating_currency CHECK (((operating_currency IS NULL) OR ((operating_currency)::text ~ '^[A-Z]{3}$'::text))),
    CONSTRAINT departures_operating_decision CHECK (((operating_decision)::text = ANY ((ARRAY['undecided'::character varying, 'proceed'::character varying, 'postpone'::character varying, 'cancel'::character varying])::text[]))),
    CONSTRAINT departures_ready_to_sell_completeness CHECK ((((sales_status)::text = 'draft'::text) OR ((name IS NOT NULL) AND (btrim((name)::text) <> ''::text) AND (starts_on IS NOT NULL) AND (ends_on IS NOT NULL) AND (time_zone IS NOT NULL) AND (btrim((time_zone)::text) <> ''::text) AND (operating_currency IS NOT NULL)))),
    CONSTRAINT departures_reference_format CHECK (((departure_reference IS NULL) OR ((departure_reference)::text ~ '^DEP-[0-9]{4,}$'::text))),
    CONSTRAINT departures_sales_status CHECK (((sales_status)::text = ANY ((ARRAY['draft'::character varying, 'ready_to_sell'::character varying])::text[])))
);


--
-- Name: offices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offices (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    name character varying NOT NULL,
    code character varying NOT NULL,
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
-- Name: payee_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payee_accounts (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_id uuid NOT NULL,
    name character varying NOT NULL,
    currency character varying NOT NULL,
    payment_instructions text,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT payee_accounts_currency CHECK (((currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT payee_accounts_instructions CHECK (((payment_instructions IS NULL) OR (char_length(payment_instructions) <= 4000))),
    CONSTRAINT payee_accounts_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT payee_accounts_name CHECK (((btrim((name)::text) <> ''::text) AND (char_length((name)::text) <= 120)))
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
    CONSTRAINT reference_sequences_namespace CHECK (((namespace)::text = ANY ((ARRAY['client'::character varying, 'supplier'::character varying, 'departure'::character varying, 'trip'::character varying, 'client_payment'::character varying, 'arrangement'::character varying, 'supplier_payment'::character varying, 'confirmation'::character varying, 'invoice'::character varying, 'receipt'::character varying])::text[]))),
    CONSTRAINT reference_sequences_next_value CHECK (((next_value >= 1) AND (((namespace)::text <> ALL ((ARRAY['client'::character varying, 'supplier'::character varying])::text[])) OR (next_value <= 1000000))))
);


--
-- Name: resellers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.resellers (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    name character varying NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    direct_contact_allowed boolean DEFAULT true NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT resellers_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT resellers_name CHECK (((btrim((name)::text) <> ''::text) AND (char_length((name)::text) <= 160))),
    CONSTRAINT resellers_status_valid CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'booking_paused'::character varying, 'suspended'::character varying, 'ended'::character varying])::text[])))
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
    agency_user_id uuid NOT NULL,
    office_id uuid,
    credential_version integer NOT NULL,
    ip_address character varying,
    user_agent character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
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
-- Name: traveler_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.traveler_types (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    name character varying NOT NULL,
    "position" integer NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT traveler_types_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT traveler_types_name CHECK (((btrim((name)::text) <> ''::text) AND (char_length((name)::text) <= 60))),
    CONSTRAINT traveler_types_position_nonnegative CHECK (("position" >= 0)),
    CONSTRAINT traveler_types_status_valid CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
);


--
-- Name: user_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_permissions (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    agency_user_id uuid NOT NULL,
    permission character varying NOT NULL,
    user_type character varying DEFAULT 'staff'::character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT user_permissions_permission_valid CHECK (((permission)::text = ANY ((ARRAY['departure_management'::character varying, 'supplier_arrangements'::character varying, 'financial_records'::character varying, 'passport_access'::character varying, 'reseller_relationships'::character varying])::text[]))),
    CONSTRAINT user_permissions_staff_only CHECK (((user_type)::text = 'staff'::text))
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
-- Name: agency_document_inclusions agency_document_inclusions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agency_document_inclusions
    ADD CONSTRAINT agency_document_inclusions_pkey PRIMARY KEY (id);


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
-- Name: audit_events audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_pkey PRIMARY KEY (id);


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
-- Name: departure_decisions departure_decisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departure_decisions
    ADD CONSTRAINT departure_decisions_pkey PRIMARY KEY (id);


--
-- Name: departure_team_members departure_team_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departure_team_members
    ADD CONSTRAINT departure_team_members_pkey PRIMARY KEY (id);


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
-- Name: payee_accounts payee_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payee_accounts
    ADD CONSTRAINT payee_accounts_pkey PRIMARY KEY (id);


--
-- Name: reference_sequences reference_sequences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reference_sequences
    ADD CONSTRAINT reference_sequences_pkey PRIMARY KEY (id);


--
-- Name: resellers resellers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resellers
    ADD CONSTRAINT resellers_pkey PRIMARY KEY (id);


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
-- Name: traveler_types traveler_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traveler_types
    ADD CONSTRAINT traveler_types_pkey PRIMARY KEY (id);


--
-- Name: user_permissions user_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_permissions
    ADD CONSTRAINT user_permissions_pkey PRIMARY KEY (id);


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
-- Name: index_agencies_on_workspace_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agencies_on_workspace_code ON public.agencies USING btree (workspace_code);


--
-- Name: index_agency_document_inclusions_on_agency_family; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agency_document_inclusions_on_agency_family ON public.agency_document_inclusions USING btree (agency_id, document_family);


--
-- Name: index_agency_users_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agency_users_on_agency_id ON public.agency_users USING btree (agency_id);


--
-- Name: index_agency_users_on_agency_id_and_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agency_users_on_agency_id_and_email ON public.agency_users USING btree (agency_id, email_address);


--
-- Name: index_agency_users_on_agency_id_id_user_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agency_users_on_agency_id_id_user_type ON public.agency_users USING btree (agency_id, id, user_type);


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
-- Name: index_agency_users_on_reseller_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agency_users_on_reseller_id ON public.agency_users USING btree (reseller_id);


--
-- Name: index_audit_events_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_agency_id ON public.audit_events USING btree (agency_id);


--
-- Name: index_audit_events_on_agency_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_agency_id_and_created_at ON public.audit_events USING btree (agency_id, created_at);


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
-- Name: index_departure_decisions_on_departure_and_decided_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departure_decisions_on_departure_and_decided_at ON public.departure_decisions USING btree (departure_id, decided_at);


--
-- Name: index_departure_team_members_on_agency_and_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departure_team_members_on_agency_and_user ON public.departure_team_members USING btree (agency_id, agency_user_id);


--
-- Name: index_departure_team_members_on_departure_and_user; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_departure_team_members_on_departure_and_user ON public.departure_team_members USING btree (departure_id, agency_user_id);


--
-- Name: index_departure_team_members_one_default_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_departure_team_members_one_default_owner ON public.departure_team_members USING btree (departure_id) WHERE default_task_owner;


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
-- Name: index_departures_on_agency_starts_on_name_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departures_on_agency_starts_on_name_id ON public.departures USING btree (agency_id, starts_on, name_search_key, id);


--
-- Name: index_departures_on_agency_statuses_starts_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departures_on_agency_statuses_starts_on_id ON public.departures USING btree (agency_id, completion_status, sales_status, starts_on, id);


--
-- Name: index_departures_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_departures_on_id_and_agency_id ON public.departures USING btree (id, agency_id);


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
-- Name: index_payee_accounts_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_payee_accounts_on_id_and_agency_id ON public.payee_accounts USING btree (id, agency_id);


--
-- Name: index_payee_accounts_on_id_and_supplier_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_payee_accounts_on_id_and_supplier_id ON public.payee_accounts USING btree (id, supplier_id);


--
-- Name: index_payee_accounts_on_supplier_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_payee_accounts_on_supplier_and_name ON public.payee_accounts USING btree (supplier_id, name);


--
-- Name: index_reference_sequences_on_agency_and_namespace; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reference_sequences_on_agency_and_namespace ON public.reference_sequences USING btree (agency_id, namespace);


--
-- Name: index_reference_sequences_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reference_sequences_on_agency_id ON public.reference_sequences USING btree (agency_id);


--
-- Name: index_resellers_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_resellers_on_agency_id ON public.resellers USING btree (agency_id);


--
-- Name: index_resellers_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_resellers_on_id_and_agency_id ON public.resellers USING btree (id, agency_id);


--
-- Name: index_sessions_on_agency_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_agency_user_id ON public.sessions USING btree (agency_user_id);


--
-- Name: index_sessions_on_office_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_office_id ON public.sessions USING btree (office_id);


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
-- Name: index_traveler_types_on_agency_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_traveler_types_on_agency_and_name ON public.traveler_types USING btree (agency_id, lower((name)::text));


--
-- Name: index_traveler_types_on_agency_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_types_on_agency_and_position ON public.traveler_types USING btree (agency_id, "position");


--
-- Name: index_traveler_types_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_traveler_types_on_id_and_agency_id ON public.traveler_types USING btree (id, agency_id);


--
-- Name: index_user_permissions_on_agency_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_permissions_on_agency_user_id ON public.user_permissions USING btree (agency_user_id);


--
-- Name: index_user_permissions_on_agency_user_permission; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_permissions_on_agency_user_permission ON public.user_permissions USING btree (agency_id, agency_user_id, permission);


--
-- Name: agencies agencies_reject_workspace_code_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER agencies_reject_workspace_code_change BEFORE UPDATE ON public.agencies FOR EACH ROW EXECUTE FUNCTION public.reject_agency_workspace_code_change();


--
-- Name: agency_users agency_users_reject_agency_id_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER agency_users_reject_agency_id_change BEFORE UPDATE ON public.agency_users FOR EACH ROW EXECUTE FUNCTION public.reject_agency_user_agency_change();


--
-- Name: audit_events audit_events_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_events_reject_update BEFORE DELETE OR UPDATE ON public.audit_events FOR EACH ROW EXECUTE FUNCTION public.reject_audit_event_mutation();


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
-- Name: departure_decisions departure_decisions_reject_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER departure_decisions_reject_mutation BEFORE DELETE OR UPDATE ON public.departure_decisions FOR EACH ROW EXECUTE FUNCTION public.reject_departure_decision_mutation();


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
-- Name: audit_events audit_events_actor_agency_user_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_actor_agency_user_fk FOREIGN KEY (actor_agency_user_id, agency_id) REFERENCES public.agency_users(id, agency_id);


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
-- Name: agency_users fk_agency_users_reseller_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agency_users
    ADD CONSTRAINT fk_agency_users_reseller_same_agency FOREIGN KEY (reseller_id, agency_id) REFERENCES public.resellers(id, agency_id);


--
-- Name: departure_decisions fk_departure_decisions_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departure_decisions
    ADD CONSTRAINT fk_departure_decisions_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: departure_decisions fk_departure_decisions_decided_by_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departure_decisions
    ADD CONSTRAINT fk_departure_decisions_decided_by_same_agency FOREIGN KEY (decided_by_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: departure_decisions fk_departure_decisions_departure_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departure_decisions
    ADD CONSTRAINT fk_departure_decisions_departure_same_agency FOREIGN KEY (departure_id, agency_id) REFERENCES public.departures(id, agency_id);


--
-- Name: departure_team_members fk_departure_team_members_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departure_team_members
    ADD CONSTRAINT fk_departure_team_members_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: departure_team_members fk_departure_team_members_departure_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departure_team_members
    ADD CONSTRAINT fk_departure_team_members_departure_same_agency FOREIGN KEY (departure_id, agency_id) REFERENCES public.departures(id, agency_id);


--
-- Name: departure_team_members fk_departure_team_members_user_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departure_team_members
    ADD CONSTRAINT fk_departure_team_members_user_same_agency FOREIGN KEY (agency_user_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: payee_accounts fk_payee_accounts_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payee_accounts
    ADD CONSTRAINT fk_payee_accounts_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: payee_accounts fk_payee_accounts_supplier_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payee_accounts
    ADD CONSTRAINT fk_payee_accounts_supplier_same_agency FOREIGN KEY (supplier_id, agency_id) REFERENCES public.suppliers(id, agency_id);


--
-- Name: client_person_postal_addresses fk_rails_14e390d793; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_person_postal_addresses
    ADD CONSTRAINT fk_rails_14e390d793 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: client_organization_phone_numbers fk_rails_1f83ac8034; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_organization_phone_numbers
    ADD CONSTRAINT fk_rails_1f83ac8034 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: offices fk_rails_29d71841aa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offices
    ADD CONSTRAINT fk_rails_29d71841aa FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


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
-- Name: traveler_types fk_rails_92c256bba0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traveler_types
    ADD CONSTRAINT fk_rails_92c256bba0 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


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
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: agency_users fk_rails_9b56937ae8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agency_users
    ADD CONSTRAINT fk_rails_9b56937ae8 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: suppliers fk_rails_a0dd1fca19; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suppliers
    ADD CONSTRAINT fk_rails_a0dd1fca19 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: agency_document_inclusions fk_rails_a2f50cb165; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agency_document_inclusions
    ADD CONSTRAINT fk_rails_a2f50cb165 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


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
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


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
-- Name: supplier_email_addresses fk_rails_e4b48618c0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_email_addresses
    ADD CONSTRAINT fk_rails_e4b48618c0 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: client_person_phone_numbers fk_rails_f3401476d8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_person_phone_numbers
    ADD CONSTRAINT fk_rails_f3401476d8 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: sessions fk_rails_fda020f2ca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_fda020f2ca FOREIGN KEY (agency_user_id) REFERENCES public.agency_users(id);


--
-- Name: resellers fk_resellers_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resellers
    ADD CONSTRAINT fk_resellers_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: user_permissions fk_user_permissions_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_permissions
    ADD CONSTRAINT fk_user_permissions_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: user_permissions fk_user_permissions_staff_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_permissions
    ADD CONSTRAINT fk_user_permissions_staff_user FOREIGN KEY (agency_id, agency_user_id, user_type) REFERENCES public.agency_users(agency_id, id, user_type) ON UPDATE CASCADE;


--
-- Name: sessions sessions_office_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_office_fk FOREIGN KEY (office_id) REFERENCES public.offices(id);


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
-- Name: supplier_websites supplier_websites_supplier_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_websites
    ADD CONSTRAINT supplier_websites_supplier_agency_fk FOREIGN KEY (supplier_id, agency_id) REFERENCES public.suppliers(id, agency_id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261105170000'),
('20261105160000'),
('20261105150000'),
('20261105140000'),
('20261105130000'),
('20261105120000'),
('20261104190000'),
('20261104180000'),
('20261104170000'),
('20261104160000'),
('20261104150000'),
('20261104140000'),
('20261104130000'),
('20261104120000'),
('20261006180000'),
('20261005220000'),
('20261002270000'),
('20261002260000'),
('20261002250000'),
('20261002240000'),
('20261002230000'),
('20261002220000'),
('20261002210000'),
('20261002200000'),
('20261002190000'),
('20261002050000'),
('20261002040000'),
('20261002030000'),
('20261002020000'),
('20261002010000'),
('20261001210000'),
('20261001193000'),
('20261001180000'),
('20260930170000'),
('20260928020000'),
('20260928010000'),
('20260926220000'),
('20260924180000'),
('20260923190000'),
('20260923010000'),
('20260922010000'),
('20260921120000'),
('20260921010000'),
('20260920230000'),
('20260920220000'),
('20260920210000'),
('20260920200000'),
('20260920160000'),
('20260920150000'),
('20260920140000'),
('20260920030000'),
('20260920020000'),
('20260920010000'),
('20260919210000'),
('20260919200000'),
('20260919190000'),
('20260919180000'),
('20260919140000'),
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

