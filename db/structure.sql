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
    OR NEW.client_reference IS DISTINCT FROM OLD.client_reference THEN
    RAISE EXCEPTION 'client identity is immutable';
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
    label character varying,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    preferred boolean DEFAULT false NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    address character varying NOT NULL,
    normalized_address text GENERATED ALWAYS AS (lower(btrim((address)::text))) STORED,
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
    label character varying,
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
    label character varying,
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
    client_person_id uuid NOT NULL,
    client_reference character varying NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT clients_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT clients_reference_format CHECK (((client_reference)::text ~ '^CL-[0-9]{6}$'::text)),
    CONSTRAINT clients_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
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
    CONSTRAINT reference_sequences_namespace CHECK (((namespace)::text = 'client'::text)),
    CONSTRAINT reference_sequences_next_value CHECK (((next_value >= 1) AND (next_value <= 1000000)))
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
-- Name: agencies agencies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agencies
    ADD CONSTRAINT agencies_pkey PRIMARY KEY (id);


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
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: index_agencies_on_workspace_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agencies_on_workspace_code ON public.agencies USING btree (workspace_code);


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
-- Name: index_audit_events_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_agency_id ON public.audit_events USING btree (agency_id);


--
-- Name: index_audit_events_on_agency_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_agency_id_and_created_at ON public.audit_events USING btree (agency_id, created_at);


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
-- Name: index_clients_on_client_person_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_clients_on_client_person_id ON public.clients USING btree (client_person_id);


--
-- Name: index_clients_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_clients_on_id_and_agency_id ON public.clients USING btree (id, agency_id);


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
-- Name: index_sessions_on_agency_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_agency_user_id ON public.sessions USING btree (agency_user_id);


--
-- Name: index_sessions_on_office_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_office_id ON public.sessions USING btree (office_id);


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
-- Name: offices offices_reject_identity_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER offices_reject_identity_change BEFORE UPDATE ON public.offices FOR EACH ROW EXECUTE FUNCTION public.reject_office_identity_change();


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
-- Name: clients clients_person_agency_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_person_agency_fk FOREIGN KEY (client_person_id, agency_id) REFERENCES public.client_people(id, agency_id);


--
-- Name: client_person_postal_addresses fk_rails_14e390d793; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_person_postal_addresses
    ADD CONSTRAINT fk_rails_14e390d793 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: offices fk_rails_29d71841aa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offices
    ADD CONSTRAINT fk_rails_29d71841aa FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: reference_sequences fk_rails_4fafc1651c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reference_sequences
    ADD CONSTRAINT fk_rails_4fafc1651c FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: audit_events fk_rails_8512cd9707; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT fk_rails_8512cd9707 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


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
-- Name: client_people fk_rails_ca3cbcb220; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_people
    ADD CONSTRAINT fk_rails_ca3cbcb220 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: client_person_email_addresses fk_rails_d40f0804a1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_person_email_addresses
    ADD CONSTRAINT fk_rails_d40f0804a1 FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


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
-- Name: sessions sessions_office_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_office_fk FOREIGN KEY (office_id) REFERENCES public.offices(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260914040000'),
('20260914030000'),
('20260914020000'),
('20260914010000');

