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
-- Name: check_inventory_allocation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_inventory_allocation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NOT EXISTS (
      SELECT 1 FROM choice_selections s JOIN offering_options o ON o.id = s.offering_option_id
      WHERE s.id = NEW.choice_selection_id AND s.client_booking_id = NEW.client_booking_id AND o.inventory_group_id = NEW.inventory_group_id
    ) THEN
      RAISE EXCEPTION 'inventory allocation % must draw on its selection''s group', NEW.id;
    END IF;
    IF NEW.unit_shell_id IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM unit_shells WHERE id = NEW.unit_shell_id AND inventory_group_id = NEW.inventory_group_id
    ) THEN
      RAISE EXCEPTION 'inventory allocation % names a shell of another group', NEW.id;
    END IF;
    IF NEW.state <> 'held' THEN
      RAISE EXCEPTION 'inventory allocation % must start Held', NEW.id;
    END IF;
    RETURN NEW;
  END IF;
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'inventory allocations are never deleted';
  END IF;
  IF NEW.client_booking_id IS DISTINCT FROM OLD.client_booking_id OR NEW.choice_selection_id IS DISTINCT FROM OLD.choice_selection_id
    OR NEW.inventory_group_id IS DISTINCT FROM OLD.inventory_group_id OR NEW.unit_shell_id IS DISTINCT FROM OLD.unit_shell_id
    OR NEW.quantity IS DISTINCT FROM OLD.quantity OR NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.held_at IS DISTINCT FROM OLD.held_at OR NEW.replaces_allocation_id IS DISTINCT FROM OLD.replaces_allocation_id THEN
    RAISE EXCEPTION 'inventory allocation % may change only its state', OLD.id;
  END IF;
  IF OLD.state = 'released' AND NEW IS DISTINCT FROM OLD THEN
    RAISE EXCEPTION 'released inventory allocation % never changes', OLD.id;
  END IF;
  IF OLD.state = 'reserved' AND NEW.state = 'held' THEN
    RAISE EXCEPTION 'inventory allocation % cannot return to Held', OLD.id;
  END IF;
  IF (OLD.reserved_at IS NOT NULL AND NEW.reserved_at IS DISTINCT FROM OLD.reserved_at)
    OR (OLD.hold_extended_at IS NOT NULL AND NEW.hold_extended_at IS DISTINCT FROM OLD.hold_extended_at) THEN
    RAISE EXCEPTION 'inventory allocation % timestamps are set once', OLD.id;
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
-- Name: reject_booking_acceptance_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_booking_acceptance_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND (to_jsonb(NEW) - 'updated_at') = (to_jsonb(OLD) - 'updated_at') THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'booking_acceptances rows are append-only';
END;
$$;


--
-- Name: reject_capacity_event_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_capacity_event_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'capacity events are append-only';
END;
$$;


--
-- Name: reject_capacity_owner_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_capacity_owner_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id OR NEW.inventory_group_id IS DISTINCT FROM OLD.inventory_group_id THEN
    RAISE EXCEPTION 'capacity record ownership is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_choice_selection_other_offering(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_choice_selection_other_offering() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM client_bookings b
      JOIN offering_choices c ON c.offering_id = b.offering_id
      JOIN offering_options o ON o.offering_choice_id = c.id
    WHERE b.id = NEW.client_booking_id AND o.id = NEW.offering_option_id
  ) THEN
    RAISE EXCEPTION 'choice selection % uses an option from another offering', NEW.id;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_client_booking_identity_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_client_booking_identity_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id OR NEW.client_trip_id IS DISTINCT FROM OLD.client_trip_id
    OR NEW.booking_reference IS DISTINCT FROM OLD.booking_reference OR NEW.sequence IS DISTINCT FROM OLD.sequence
    OR NEW.offering_id IS DISTINCT FROM OLD.offering_id THEN
    RAISE EXCEPTION 'client booking identity is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_client_booking_other_departure(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_client_booking_other_departure() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM client_trips t JOIN offerings o ON o.departure_id = t.departure_id
    WHERE t.id = NEW.client_trip_id AND o.id = NEW.offering_id
  ) THEN
    RAISE EXCEPTION 'client booking % must buy an offering of its trip''s Departure', NEW.id;
  END IF;
  RETURN NEW;
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
-- Name: reject_client_money_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_client_money_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION '% rows are append-only', TG_TABLE_NAME;
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
-- Name: reject_client_trip_identity_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_client_trip_identity_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id OR NEW.trip_reference IS DISTINCT FROM OLD.trip_reference THEN
    RAISE EXCEPTION 'client trip identity is immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_confirmed_booking_contents_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_confirmed_booking_contents_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  booking_id uuid;
BEGIN
  booking_id := CASE WHEN TG_OP = 'INSERT' THEN NEW.client_booking_id ELSE OLD.client_booking_id END;
  IF EXISTS (SELECT 1 FROM client_bookings WHERE id = booking_id AND status <> 'draft') THEN
    RAISE EXCEPTION 'booking % is no longer a draft; its contents are fixed', booking_id;
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
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
-- Name: reject_document_attachment_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_document_attachment_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF OLD.record_type = 'DocumentVersion' THEN
    RAISE EXCEPTION 'an issued document''s PDF cannot be removed or replaced';
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;


--
-- Name: reject_document_delivery_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_document_delivery_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'document_deliveries rows are append-only';
END;
$$;


--
-- Name: reject_document_version_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_document_version_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND (to_jsonb(NEW) - 'updated_at') = (to_jsonb(OLD) - 'updated_at') THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'document_versions rows are append-only';
END;
$$;


--
-- Name: reject_frozen_supplier_rate_band_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_frozen_supplier_rate_band_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  arrangement_status text;
BEGIN
  IF TG_OP = 'UPDATE' AND (NEW.agency_id IS DISTINCT FROM OLD.agency_id OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id) THEN
    RAISE EXCEPTION 'supplier rate band ownership is immutable';
  END IF;
  SELECT status INTO arrangement_status FROM supplier_arrangements
    WHERE id = CASE WHEN TG_OP = 'INSERT' THEN NEW.supplier_arrangement_id ELSE OLD.supplier_arrangement_id END;
  IF arrangement_status IS DISTINCT FROM 'draft' THEN
    RAISE EXCEPTION 'supplier rate bands are frozen once the arrangement leaves draft';
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;


--
-- Name: reject_frozen_supplier_rate_line_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_frozen_supplier_rate_line_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  arrangement_status text;
BEGIN
  IF TG_OP = 'UPDATE' AND (NEW.agency_id IS DISTINCT FROM OLD.agency_id
      OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
      OR NEW.inventory_group_id IS DISTINCT FROM OLD.inventory_group_id) THEN
    RAISE EXCEPTION 'supplier rate line ownership is immutable';
  END IF;
  SELECT status INTO arrangement_status FROM supplier_arrangements
    WHERE id = CASE WHEN TG_OP = 'INSERT' THEN NEW.supplier_arrangement_id ELSE OLD.supplier_arrangement_id END;
  IF arrangement_status IS DISTINCT FROM 'draft' THEN
    RAISE EXCEPTION 'supplier rate lines are frozen once the arrangement leaves draft';
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;


--
-- Name: reject_invalid_capacity_event_zone(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_invalid_capacity_event_zone() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  PERFORM now() AT TIME ZONE NEW.effective_time_zone;
  RETURN NEW;
EXCEPTION WHEN invalid_parameter_value THEN
  RAISE EXCEPTION 'capacity event zone % is not a recognized time zone', NEW.effective_time_zone;
END;
$$;


--
-- Name: reject_locked_client_terms_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_locked_client_terms_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  version_id uuid;
BEGIN
  IF TG_TABLE_NAME = 'client_terms_versions' THEN
    IF OLD.locked_at IS NOT NULL THEN
      RAISE EXCEPTION 'client terms version % is locked', OLD.id;
    END IF;
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
  END IF;
  version_id := CASE WHEN TG_OP = 'INSERT' THEN NEW.client_terms_version_id ELSE OLD.client_terms_version_id END;
  IF EXISTS (SELECT 1 FROM client_terms_versions WHERE id = version_id AND locked_at IS NOT NULL) THEN
    RAISE EXCEPTION 'client terms version % is locked', version_id;
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;


--
-- Name: reject_nonnumeric_capacity_record(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_nonnumeric_capacity_record() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  grp record;
BEGIN
  SELECT representation, availability_promise INTO grp FROM inventory_groups WHERE id = NEW.inventory_group_id;
  IF grp.representation = 'none' OR grp.availability_promise IN ('on_request', 'rate_only') THEN
    RAISE EXCEPTION 'inventory group % holds no numeric capacity', NEW.inventory_group_id;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_offering_option_other_departure(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_offering_option_other_departure() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM offering_choices c
      JOIN offerings o ON o.id = c.offering_id
      JOIN inventory_groups g ON g.id = NEW.inventory_group_id
      JOIN supplier_arrangements a ON a.id = g.supplier_arrangement_id
    WHERE c.id = NEW.offering_choice_id AND a.departure_id = o.departure_id
  ) THEN
    RAISE EXCEPTION 'offering option % draws on another departure''s inventory', NEW.id;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: reject_offering_publication_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_offering_publication_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'offering_publications rows cannot be deleted';
  END IF;
  IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
    OR NEW.offering_id IS DISTINCT FROM OLD.offering_id
    OR NEW.reseller_id IS DISTINCT FROM OLD.reseller_id
    OR NEW.published_at IS DISTINCT FROM OLD.published_at
    OR NEW.published_by_id IS DISTINCT FROM OLD.published_by_id
    OR OLD.withdrawn_at IS NOT NULL THEN
    RAISE EXCEPTION 'an offering publication only records its withdrawal, once';
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
-- Name: reject_self_link_to_organization(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_self_link_to_organization() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.relationship = 'self' AND EXISTS (SELECT 1 FROM clients WHERE id = NEW.client_id AND client_person_id IS NULL) THEN
    RAISE EXCEPTION 'only a person client can be linked as Self';
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
-- Name: reject_supplier_money_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_supplier_money_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION '% rows are append-only', TG_TABLE_NAME;
END;
$$;


--
-- Name: reject_supplier_reservation_event_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_supplier_reservation_event_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'supplier_reservation_events rows are append-only';
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
    client_terms_wording text,
    CONSTRAINT agencies_address_complete CHECK ((((address_line_1 IS NULL) AND (address_line_2 IS NULL) AND (address_locality IS NULL) AND (address_region IS NULL) AND (address_postal_code IS NULL) AND (address_country_code IS NULL)) OR ((address_line_1 IS NOT NULL) AND (btrim((address_line_1)::text) <> ''::text) AND (address_country_code IS NOT NULL) AND ((address_country_code)::text ~ '^[A-Z]{2}$'::text)))),
    CONSTRAINT agencies_client_terms_wording_length CHECK (((client_terms_wording IS NULL) OR (char_length(client_terms_wording) <= 20000))),
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
-- Name: agency_cancellation_tiers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agency_cancellation_tiers (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    min_days_before_departure integer NOT NULL,
    charge_kind character varying NOT NULL,
    percentage numeric(7,4),
    amount_minor_units bigint,
    currency character varying,
    service_category character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT agency_cancellation_tiers_charge CHECK (COALESCE(((((charge_kind)::text = 'percentage'::text) AND (percentage > (0)::numeric) AND (percentage <= (100)::numeric) AND (amount_minor_units IS NULL) AND (currency IS NULL) AND (service_category IS NULL)) OR (((charge_kind)::text = 'fixed_per_traveler'::text) AND (percentage IS NULL) AND (amount_minor_units >= 0) AND ((currency)::text ~ '^[A-Z]{3}$'::text) AND (service_category IS NULL)) OR (((charge_kind)::text = 'fixed_per_unit'::text) AND (percentage IS NULL) AND (amount_minor_units >= 0) AND ((currency)::text ~ '^[A-Z]{3}$'::text) AND ((service_category)::text = ANY (ARRAY[('hotel'::character varying)::text, ('all_inclusive_resort'::character varying)::text, ('cruise'::character varying)::text, ('air'::character varying)::text, ('rail'::character varying)::text, ('transportation'::character varying)::text, ('activity'::character varying)::text, ('meal'::character varying)::text, ('insurance'::character varying)::text])))), false)),
    CONSTRAINT agency_cancellation_tiers_counters CHECK (((min_days_before_departure >= 0) AND (lock_version >= 0)))
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
    CONSTRAINT agency_document_inclusions_family_valid CHECK (((document_family)::text = ANY (ARRAY[('confirmation'::character varying)::text, ('invoice'::character varying)::text, ('receipt'::character varying)::text, ('statement'::character varying)::text])))
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
    CONSTRAINT agency_users_user_type_valid CHECK (((user_type)::text = ANY (ARRAY[('agency_admin'::character varying)::text, ('staff'::character varying)::text, ('reseller'::character varying)::text])))
);


--
-- Name: amounts_due; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.amounts_due (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    schedule_line_id uuid,
    unit_shell_id uuid,
    trigger_event_id uuid,
    description character varying NOT NULL,
    amount_minor_units bigint NOT NULL,
    currency character varying NOT NULL,
    due_on date NOT NULL,
    quantity integer,
    rate_minor_units bigint,
    percentage numeric(7,4),
    base_minor_units bigint,
    posted_by_id uuid,
    posted_by_identifier character varying,
    posted_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT amounts_due_amount CHECK ((amount_minor_units >= 0)),
    CONSTRAINT amounts_due_currency CHECK (((currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT amounts_due_description CHECK (((btrim((description)::text) <> ''::text) AND (char_length((description)::text) <= 200))),
    CONSTRAINT amounts_due_posted_by CHECK (((posted_by_id IS NULL) <> (posted_by_identifier IS NULL))),
    CONSTRAINT amounts_due_shell_needs_line CHECK (((unit_shell_id IS NULL) OR (schedule_line_id IS NOT NULL)))
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
-- Name: arrangement_documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.arrangement_documents (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    kind character varying NOT NULL,
    description character varying,
    uploaded_by_id uuid NOT NULL,
    sha256 character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT arrangement_documents_description CHECK (((description IS NULL) OR ((btrim((description)::text) <> ''::text) AND (char_length((description)::text) <= 200)))),
    CONSTRAINT arrangement_documents_kind CHECK (((kind)::text = ANY (ARRAY[('quote'::character varying)::text, ('agreement'::character varying)::text, ('confirmation'::character varying)::text, ('other'::character varying)::text]))),
    CONSTRAINT arrangement_documents_sha256 CHECK (((sha256)::text ~ '^[0-9a-f]{64}$'::text))
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
-- Name: booking_acceptances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.booking_acceptances (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_booking_id uuid NOT NULL,
    client_terms_version_id uuid NOT NULL,
    accepted_by character varying NOT NULL,
    acceptance_method character varying NOT NULL,
    accepted_on date NOT NULL,
    accepted_total_minor_units bigint NOT NULL,
    currency character varying NOT NULL,
    lines_fingerprint character varying NOT NULL,
    note text,
    evidence_reference character varying,
    evidence_sha256 character varying,
    payment_on date,
    payment_amount_minor_units bigint,
    payment_reference character varying,
    recorded_by_id uuid NOT NULL,
    recorded_at timestamp(6) with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    client_payment_id uuid,
    CONSTRAINT booking_acceptances_accepted_by CHECK (((btrim((accepted_by)::text) <> ''::text) AND (char_length((accepted_by)::text) <= 160))),
    CONSTRAINT booking_acceptances_evidence CHECK (COALESCE(((((acceptance_method)::text = ANY (ARRAY[('email'::character varying)::text, ('signed'::character varying)::text])) AND ((evidence_sha256 IS NOT NULL) OR (evidence_reference IS NOT NULL))) OR (((acceptance_method)::text = ANY (ARRAY[('phone'::character varying)::text, ('in_person'::character varying)::text])) AND (note IS NOT NULL)) OR ((acceptance_method)::text = 'designated_payment'::text)), false)),
    CONSTRAINT booking_acceptances_evidence_reference CHECK (((evidence_reference IS NULL) OR ((btrim((evidence_reference)::text) <> ''::text) AND (char_length((evidence_reference)::text) <= 300)))),
    CONSTRAINT booking_acceptances_evidence_sha256 CHECK (((evidence_sha256 IS NULL) OR ((evidence_sha256)::text ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT booking_acceptances_fingerprint CHECK (((lines_fingerprint)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT booking_acceptances_method CHECK (((acceptance_method)::text = ANY (ARRAY[('email'::character varying)::text, ('signed'::character varying)::text, ('phone'::character varying)::text, ('in_person'::character varying)::text, ('designated_payment'::character varying)::text]))),
    CONSTRAINT booking_acceptances_note CHECK (((note IS NULL) OR ((btrim(note) <> ''::text) AND (char_length(note) <= 2000)))),
    CONSTRAINT booking_acceptances_payment CHECK ((COALESCE(((((acceptance_method)::text = 'designated_payment'::text) AND (client_payment_id IS NOT NULL)) OR (((acceptance_method)::text <> 'designated_payment'::text) AND (client_payment_id IS NULL))), false) AND (payment_on IS NULL) AND (payment_amount_minor_units IS NULL) AND (payment_reference IS NULL))),
    CONSTRAINT booking_acceptances_total CHECK (((accepted_total_minor_units >= 0) AND ((currency)::text ~ '^[A-Z]{3}$'::text)))
);


--
-- Name: booking_price_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.booking_price_lines (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_booking_id uuid NOT NULL,
    choice_selection_id uuid NOT NULL,
    booking_traveler_id uuid,
    offering_price_id uuid,
    occupancy_position character varying NOT NULL,
    traveler_type_id uuid,
    amount_minor_units bigint NOT NULL,
    currency character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT booking_price_lines_amount CHECK ((amount_minor_units >= 0)),
    CONSTRAINT booking_price_lines_currency CHECK (((currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT booking_price_lines_occupancy_position CHECK (((occupancy_position)::text = ANY (ARRAY[('any'::character varying)::text, ('single'::character varying)::text, ('guest_1'::character varying)::text, ('guest_2'::character varying)::text, ('guest_3'::character varying)::text, ('guest_4'::character varying)::text, ('guest_5'::character varying)::text, ('guest_6'::character varying)::text, ('guest_7'::character varying)::text, ('guest_8'::character varying)::text, ('guest_9'::character varying)::text])))
);


--
-- Name: booking_travelers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.booking_travelers (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_booking_id uuid NOT NULL,
    traveler_id uuid,
    placeholder_label character varying,
    traveler_type_id uuid,
    "position" integer NOT NULL,
    name_as_booked character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT booking_travelers_counters CHECK ((("position" >= 1) AND (lock_version >= 0))),
    CONSTRAINT booking_travelers_name_as_booked CHECK (((name_as_booked IS NULL) OR (char_length((name_as_booked)::text) <= 300))),
    CONSTRAINT booking_travelers_placeholder CHECK (((placeholder_label IS NULL) OR ((btrim((placeholder_label)::text) <> ''::text) AND (char_length((placeholder_label)::text) <= 40)))),
    CONSTRAINT booking_travelers_traveler_or_placeholder CHECK ((num_nonnulls(traveler_id, placeholder_label) = 1))
);


--
-- Name: capacity_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.capacity_events (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    inventory_group_id uuid NOT NULL,
    capacity_pool_id uuid,
    unit_shell_id uuid,
    event_type character varying NOT NULL,
    quantity bigint NOT NULL,
    effective_on date NOT NULL,
    effective_time_zone character varying NOT NULL,
    applies_at timestamp(6) with time zone NOT NULL,
    effective_sequence integer NOT NULL,
    recorded_at timestamp(6) with time zone NOT NULL,
    evidence_note text,
    corrects_event_id uuid,
    actor_id uuid NOT NULL,
    idempotency_key character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT capacity_events_correction_pair CHECK ((((event_type)::text = ANY (ARRAY[('corrected_up'::character varying)::text, ('corrected_down'::character varying)::text])) = (corrects_event_id IS NOT NULL))),
    CONSTRAINT capacity_events_effective_time_zone CHECK ((btrim((effective_time_zone)::text) <> ''::text)),
    CONSTRAINT capacity_events_evidence CHECK ((((event_type)::text = 'established'::text) OR ((evidence_note IS NOT NULL) AND (btrim(evidence_note) <> ''::text) AND (char_length(evidence_note) <= 500)))),
    CONSTRAINT capacity_events_quantity_positive CHECK ((quantity > 0)),
    CONSTRAINT capacity_events_sequence_positive CHECK ((effective_sequence > 0)),
    CONSTRAINT capacity_events_shell_quantity CHECK (((unit_shell_id IS NULL) OR (quantity = 1))),
    CONSTRAINT capacity_events_type CHECK (((event_type)::text = ANY (ARRAY[('established'::character varying)::text, ('increased'::character varying)::text, ('released'::character varying)::text, ('reinstated'::character varying)::text, ('withdrawn'::character varying)::text, ('corrected_up'::character varying)::text, ('corrected_down'::character varying)::text])))
);


--
-- Name: capacity_pools; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.capacity_pools (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    inventory_group_id uuid NOT NULL,
    availability_promise character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT capacity_pools_availability_promise CHECK (((availability_promise)::text = ANY (ARRAY[('firm_block'::character varying)::text, ('releasable_block'::character varying)::text, ('courtesy_option'::character varying)::text, ('on_request'::character varying)::text, ('rate_only'::character varying)::text])))
);


--
-- Name: capacity_projections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.capacity_projections (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    inventory_group_id uuid NOT NULL,
    current_supplier_capacity bigint DEFAULT 0 NOT NULL,
    last_event_id uuid,
    last_effective_on date,
    last_effective_sequence integer,
    last_recorded_at timestamp(6) with time zone,
    next_event_id uuid,
    next_applies_at timestamp(6) with time zone,
    rebuilt_at timestamp(6) with time zone NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT capacity_projections_current_nonnegative CHECK ((current_supplier_capacity >= 0)),
    CONSTRAINT capacity_projections_lock_version CHECK ((lock_version >= 0))
);


--
-- Name: capacity_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.capacity_rules (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    inventory_group_id uuid NOT NULL,
    traveler_type_id uuid NOT NULL,
    uses_capacity boolean DEFAULT false NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: charge_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.charge_lines (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_charge_id uuid NOT NULL,
    line_type character varying NOT NULL,
    choice_selection_id uuid,
    booking_traveler_id uuid,
    traveler_type_id uuid,
    occupancy_position character varying,
    description character varying NOT NULL,
    amount_minor_units bigint NOT NULL,
    currency character varying NOT NULL,
    creditor character varying DEFAULT 'agency'::character varying NOT NULL,
    expected_route character varying DEFAULT 'agency'::character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT charge_lines_creditor_and_route CHECK ((((creditor)::text = ANY (ARRAY[('agency'::character varying)::text, ('supplier'::character varying)::text])) AND ((expected_route)::text = ANY (ARRAY[('agency'::character varying)::text, ('supplier'::character varying)::text])))),
    CONSTRAINT charge_lines_currency CHECK (((currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT charge_lines_description CHECK (((btrim((description)::text) <> ''::text) AND (char_length((description)::text) <= 300))),
    CONSTRAINT charge_lines_type CHECK (((line_type)::text = ANY (ARRAY[('traveler_price'::character varying)::text, ('add_on'::character varying)::text])))
);


--
-- Name: choice_selections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.choice_selections (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_booking_id uuid NOT NULL,
    offering_option_id uuid NOT NULL,
    unit_number integer,
    removed_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT choice_selections_counters CHECK ((((unit_number IS NULL) OR (unit_number >= 1)) AND (lock_version >= 0)))
);


--
-- Name: client_bookings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_bookings (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_trip_id uuid NOT NULL,
    offering_id uuid NOT NULL,
    sequence integer NOT NULL,
    booking_reference character varying NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    owner_kind character varying DEFAULT 'agency'::character varying NOT NULL,
    created_by_id uuid NOT NULL,
    client_terms_version_id uuid,
    discarded_at timestamp(6) with time zone,
    confirmed_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    installment_basis character varying,
    owner_reseller_id uuid,
    seller_kind character varying DEFAULT 'agency'::character varying NOT NULL,
    seller_reseller_id uuid,
    CONSTRAINT client_bookings_confirmed_at CHECK ((((status)::text = ANY (ARRAY[('confirmed'::character varying)::text, ('cancelled'::character varying)::text])) = (confirmed_at IS NOT NULL))),
    CONSTRAINT client_bookings_counters CHECK (((sequence >= 1) AND (lock_version >= 0))),
    CONSTRAINT client_bookings_discarded_at CHECK ((((status)::text = 'discarded'::text) = (discarded_at IS NOT NULL))),
    CONSTRAINT client_bookings_owner_kind CHECK (((owner_kind)::text = ANY ((ARRAY['agency'::character varying, 'reseller'::character varying])::text[]))),
    CONSTRAINT client_bookings_owner_reseller CHECK ((((owner_kind)::text = 'reseller'::text) = (owner_reseller_id IS NOT NULL))),
    CONSTRAINT client_bookings_reference_format CHECK (((booking_reference)::text ~ '^T-[0-9]{5,}-[0-9]+$'::text)),
    CONSTRAINT client_bookings_seller_kind CHECK (((seller_kind)::text = ANY ((ARRAY['agency'::character varying, 'reseller'::character varying])::text[]))),
    CONSTRAINT client_bookings_seller_reseller CHECK ((((seller_kind)::text = 'reseller'::text) = (seller_reseller_id IS NOT NULL))),
    CONSTRAINT client_bookings_status CHECK (((status)::text = ANY (ARRAY[('draft'::character varying)::text, ('confirmed'::character varying)::text, ('discarded'::character varying)::text, ('cancelled'::character varying)::text])))
);


--
-- Name: client_cancellation_tiers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_cancellation_tiers (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_terms_version_id uuid NOT NULL,
    min_days_before_departure integer NOT NULL,
    charge_kind character varying NOT NULL,
    percentage numeric(7,4),
    amount_minor_units bigint,
    currency character varying,
    service_category character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    copied_from_agency_default boolean DEFAULT false NOT NULL,
    CONSTRAINT client_cancellation_tiers_charge CHECK (COALESCE(((((charge_kind)::text = 'percentage'::text) AND (percentage > (0)::numeric) AND (percentage <= (100)::numeric) AND (amount_minor_units IS NULL) AND (currency IS NULL) AND (service_category IS NULL)) OR (((charge_kind)::text = 'fixed_per_traveler'::text) AND (percentage IS NULL) AND (amount_minor_units >= 0) AND ((currency)::text ~ '^[A-Z]{3}$'::text) AND (service_category IS NULL)) OR (((charge_kind)::text = 'fixed_per_unit'::text) AND (percentage IS NULL) AND (amount_minor_units >= 0) AND ((currency)::text ~ '^[A-Z]{3}$'::text) AND ((service_category)::text = ANY (ARRAY[('hotel'::character varying)::text, ('all_inclusive_resort'::character varying)::text, ('cruise'::character varying)::text, ('air'::character varying)::text, ('rail'::character varying)::text, ('transportation'::character varying)::text, ('activity'::character varying)::text, ('meal'::character varying)::text, ('insurance'::character varying)::text])))), false)),
    CONSTRAINT client_cancellation_tiers_counters CHECK (((min_days_before_departure >= 0) AND (lock_version >= 0)))
);


--
-- Name: client_charges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_charges (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_booking_id uuid NOT NULL,
    client_terms_version_id uuid NOT NULL,
    booking_acceptance_id uuid NOT NULL,
    currency character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT client_charges_currency CHECK (((currency)::text ~ '^[A-Z]{3}$'::text))
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
-- Name: client_payment_applications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_payment_applications (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_payment_id uuid NOT NULL,
    installment_id uuid NOT NULL,
    amount_minor_units bigint NOT NULL,
    recorded_by_id uuid NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT client_payment_applications_amount CHECK ((amount_minor_units <> 0))
);


--
-- Name: client_payment_reversals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_payment_reversals (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_payment_id uuid NOT NULL,
    reason character varying NOT NULL,
    reversed_on date NOT NULL,
    recorded_by_id uuid NOT NULL,
    recorded_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT client_payment_reversals_reason CHECK (((btrim((reason)::text) <> ''::text) AND (char_length((reason)::text) <= 500)))
);


--
-- Name: client_payment_schedule_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_payment_schedule_lines (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_terms_version_id uuid NOT NULL,
    description character varying NOT NULL,
    basis character varying NOT NULL,
    service_category character varying,
    amount_minor_units bigint,
    percentage numeric(7,4),
    currency character varying NOT NULL,
    due_rule character varying NOT NULL,
    days_before_departure integer,
    due_on date,
    counts_as_acceptance boolean DEFAULT false NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT client_payment_schedule_lines_basis CHECK (COALESCE(((((basis)::text = ANY (ARRAY[('per_traveler'::character varying)::text, ('per_booking'::character varying)::text])) AND (amount_minor_units >= 0) AND (percentage IS NULL) AND (service_category IS NULL)) OR (((basis)::text = 'per_unit'::text) AND (amount_minor_units >= 0) AND (percentage IS NULL) AND ((service_category)::text = ANY (ARRAY[('hotel'::character varying)::text, ('all_inclusive_resort'::character varying)::text, ('cruise'::character varying)::text, ('air'::character varying)::text, ('rail'::character varying)::text, ('transportation'::character varying)::text, ('activity'::character varying)::text, ('meal'::character varying)::text, ('insurance'::character varying)::text]))) OR (((basis)::text = 'percentage'::text) AND (amount_minor_units IS NULL) AND (percentage > (0)::numeric) AND (percentage <= (100)::numeric) AND (service_category IS NULL)) OR (((basis)::text = 'balance'::text) AND (amount_minor_units IS NULL) AND (percentage IS NULL) AND (service_category IS NULL))), false)),
    CONSTRAINT client_payment_schedule_lines_counters CHECK ((("position" >= 0) AND (lock_version >= 0))),
    CONSTRAINT client_payment_schedule_lines_currency CHECK (((currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT client_payment_schedule_lines_description CHECK (((btrim((description)::text) <> ''::text) AND (char_length((description)::text) <= 120))),
    CONSTRAINT client_payment_schedule_lines_due_rule CHECK (COALESCE(((((due_rule)::text = 'at_confirmation'::text) AND (days_before_departure IS NULL) AND (due_on IS NULL)) OR (((due_rule)::text = 'days_before_departure'::text) AND (days_before_departure >= 0) AND (due_on IS NULL)) OR (((due_rule)::text = 'fixed_date'::text) AND (days_before_departure IS NULL) AND (due_on IS NOT NULL))), false))
);


--
-- Name: client_payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_payments (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_trip_id uuid NOT NULL,
    payment_reference character varying NOT NULL,
    payer_client_id uuid NOT NULL,
    paid_on date NOT NULL,
    amount_minor_units bigint NOT NULL,
    currency character varying NOT NULL,
    route character varying NOT NULL,
    supplier_id uuid,
    payment_method character varying NOT NULL,
    reference character varying,
    supplier_reference character varying,
    recorded_by_id uuid NOT NULL,
    recorded_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT client_payments_amount CHECK (((amount_minor_units > 0) AND ((currency)::text ~ '^[A-Z]{3}$'::text))),
    CONSTRAINT client_payments_method CHECK (((payment_method)::text = ANY ((ARRAY['check'::character varying, 'bank_transfer'::character varying, 'card'::character varying, 'cash'::character varying, 'other'::character varying])::text[]))),
    CONSTRAINT client_payments_reference CHECK (((reference IS NULL) OR ((btrim((reference)::text) <> ''::text) AND (char_length((reference)::text) <= 120)))),
    CONSTRAINT client_payments_reference_format CHECK (((payment_reference)::text ~ '^PAY-[0-9]{5,}$'::text)),
    CONSTRAINT client_payments_route CHECK (COALESCE(((((route)::text = 'agency'::text) AND (supplier_id IS NULL)) OR (((route)::text = 'supplier'::text) AND (supplier_id IS NOT NULL))), false)),
    CONSTRAINT client_payments_supplier_reference CHECK (((supplier_reference IS NULL) OR ((btrim((supplier_reference)::text) <> ''::text) AND (char_length((supplier_reference)::text) <= 120))))
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
-- Name: client_terms_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_terms_versions (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    version_number integer NOT NULL,
    agency_wording text,
    departure_wording text,
    overrides_cancellation_tiers boolean DEFAULT false NOT NULL,
    copied_from_departure_id uuid,
    locked_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT client_terms_versions_copied_from_other CHECK (((copied_from_departure_id IS NULL) OR (copied_from_departure_id <> departure_id))),
    CONSTRAINT client_terms_versions_counters CHECK (((version_number >= 1) AND (lock_version >= 0))),
    CONSTRAINT client_terms_versions_wording_length CHECK ((((agency_wording IS NULL) OR (char_length(agency_wording) <= 20000)) AND ((departure_wording IS NULL) OR (char_length(departure_wording) <= 20000))))
);


--
-- Name: client_trips; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_trips (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_id uuid NOT NULL,
    departure_id uuid,
    trip_reference character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT client_trips_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT client_trips_reference_format CHECK (((trip_reference)::text ~ '^T-[0-9]{5,}$'::text))
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
    created_by_id uuid,
    CONSTRAINT clients_exactly_one_source CHECK ((num_nonnulls(client_person_id, client_organization_id) = 1)),
    CONSTRAINT clients_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT clients_reference_format CHECK (((client_reference)::text ~ '^CL-[0-9]{6}$'::text)),
    CONSTRAINT clients_status CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('inactive'::character varying)::text])))
);


--
-- Name: cost_line_shells; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cost_line_shells (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    cost_line_id uuid NOT NULL,
    unit_shell_id uuid NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: cost_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cost_lines (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    scope character varying NOT NULL,
    inventory_group_id uuid,
    description character varying NOT NULL,
    basis character varying NOT NULL,
    rate_minor_units bigint,
    quantity integer,
    percentage numeric(7,4),
    base_cost_line_id uuid,
    amount_minor_units bigint NOT NULL,
    currency character varying NOT NULL,
    stage character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    client_booking_id uuid,
    CONSTRAINT cost_lines_amounts CHECK (((amount_minor_units >= 0) AND ((rate_minor_units IS NULL) OR (rate_minor_units >= 0)))),
    CONSTRAINT cost_lines_base_not_self CHECK (((base_cost_line_id IS NULL) OR (base_cost_line_id <> id))),
    CONSTRAINT cost_lines_basis CHECK (COALESCE(((((basis)::text = 'fixed'::text) AND (rate_minor_units IS NOT NULL) AND (quantity IS NULL) AND (percentage IS NULL) AND (base_cost_line_id IS NULL)) OR (((basis)::text = ANY (ARRAY[('per_unit'::character varying)::text, ('per_person'::character varying)::text, ('per_night'::character varying)::text])) AND (rate_minor_units IS NOT NULL) AND (quantity >= 1) AND (percentage IS NULL) AND (base_cost_line_id IS NULL)) OR (((basis)::text = 'percentage'::text) AND (rate_minor_units IS NULL) AND (quantity IS NULL) AND (percentage > (0)::numeric) AND (percentage <= (100)::numeric) AND (base_cost_line_id IS NOT NULL))), false)),
    CONSTRAINT cost_lines_booking_scope CHECK ((((scope)::text = 'client_booking'::text) = (client_booking_id IS NOT NULL))),
    CONSTRAINT cost_lines_currency CHECK (((currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT cost_lines_description CHECK (((btrim((description)::text) <> ''::text) AND (char_length((description)::text) <= 200))),
    CONSTRAINT cost_lines_group_scope CHECK ((((scope)::text = 'inventory_group'::text) = (inventory_group_id IS NOT NULL))),
    CONSTRAINT cost_lines_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT cost_lines_scope CHECK (((scope)::text = ANY (ARRAY[('arrangement'::character varying)::text, ('inventory_group'::character varying)::text, ('unit_shells'::character varying)::text, ('client_booking'::character varying)::text]))),
    CONSTRAINT cost_lines_stage CHECK (((stage)::text = ANY (ARRAY[('estimated'::character varying)::text, ('committed'::character varying)::text])))
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
    CONSTRAINT departure_decisions_decision CHECK (((decision)::text = ANY (ARRAY[('proceed'::character varying)::text, ('postpone'::character varying)::text, ('cancel'::character varying)::text]))),
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
    CONSTRAINT departures_completion_status CHECK (((completion_status)::text = ANY (ARRAY[('active'::character varying)::text, ('departed'::character varying)::text, ('cancelled'::character varying)::text, ('superseded'::character varying)::text]))),
    CONSTRAINT departures_date_order CHECK (((starts_on IS NULL) OR (starts_on <= ends_on))),
    CONSTRAINT departures_dates_paired CHECK (((starts_on IS NULL) = (ends_on IS NULL))),
    CONSTRAINT departures_departed_at_pair CHECK ((((completion_status)::text = 'departed'::text) = (departed_at IS NOT NULL))),
    CONSTRAINT departures_description CHECK (((description IS NULL) OR ((btrim((description)::text) <> ''::text) AND (char_length((description)::text) <= 2000)))),
    CONSTRAINT departures_hold_duration_positive CHECK (((hold_duration_days IS NULL) OR (hold_duration_days >= 1))),
    CONSTRAINT departures_installment_buffer_nonnegative CHECK (((installment_buffer_days IS NULL) OR (installment_buffer_days >= 0))),
    CONSTRAINT departures_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT departures_name CHECK (((name IS NOT NULL) AND (btrim((name)::text) <> ''::text) AND (char_length((name)::text) <= 160))),
    CONSTRAINT departures_operating_currency CHECK (((operating_currency IS NULL) OR ((operating_currency)::text ~ '^[A-Z]{3}$'::text))),
    CONSTRAINT departures_operating_decision CHECK (((operating_decision)::text = ANY (ARRAY[('undecided'::character varying)::text, ('proceed'::character varying)::text, ('postpone'::character varying)::text, ('cancel'::character varying)::text]))),
    CONSTRAINT departures_ready_to_sell_completeness CHECK ((((sales_status)::text = 'draft'::text) OR ((name IS NOT NULL) AND (btrim((name)::text) <> ''::text) AND (starts_on IS NOT NULL) AND (ends_on IS NOT NULL) AND (time_zone IS NOT NULL) AND (btrim((time_zone)::text) <> ''::text) AND (operating_currency IS NOT NULL)))),
    CONSTRAINT departures_reference_format CHECK (((departure_reference IS NULL) OR ((departure_reference)::text ~ '^DEP-[0-9]{4,}$'::text))),
    CONSTRAINT departures_sales_status CHECK (((sales_status)::text = ANY (ARRAY[('draft'::character varying)::text, ('ready_to_sell'::character varying)::text])))
);


--
-- Name: document_deliveries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_deliveries (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    document_version_id uuid NOT NULL,
    delivery_method character varying NOT NULL,
    recipient character varying NOT NULL,
    delivered_on date NOT NULL,
    recorded_by_id uuid NOT NULL,
    recorded_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT document_deliveries_method CHECK (((delivery_method)::text = ANY ((ARRAY['own_email'::character varying, 'printed'::character varying, 'in_person'::character varying])::text[]))),
    CONSTRAINT document_deliveries_recipient CHECK (((length(btrim((recipient)::text)) >= 1) AND (length(btrim((recipient)::text)) <= 200)))
);


--
-- Name: document_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_versions (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    document_type character varying NOT NULL,
    number character varying NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    client_booking_id uuid,
    receipt_id uuid,
    supersedes_id uuid,
    reissue_reason text,
    issued_at timestamp(6) with time zone NOT NULL,
    issued_by_id uuid NOT NULL,
    template_version character varying NOT NULL,
    renderer_version character varying NOT NULL,
    sha256 character varying NOT NULL,
    snapshot jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT document_versions_number_format CHECK (((number)::text ~ (
CASE document_type
    WHEN 'confirmation'::text THEN '^CNF-'::text
    WHEN 'invoice'::text THEN '^INV-'::text
    ELSE '^RCP-'::text
END || '[0-9]{5,}$'::text))),
    CONSTRAINT document_versions_reissue CHECK (((version_number >= 1) AND ((supersedes_id IS NULL) = (version_number = 1)) AND ((supersedes_id IS NULL) = (reissue_reason IS NULL)))),
    CONSTRAINT document_versions_sha256 CHECK (((sha256)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT document_versions_snapshot CHECK ((jsonb_typeof(snapshot) = 'object'::text)),
    CONSTRAINT document_versions_subject CHECK (((((document_type)::text = 'receipt'::text) = (receipt_id IS NOT NULL)) AND (((document_type)::text = 'receipt'::text) = (client_booking_id IS NULL)))),
    CONSTRAINT document_versions_type CHECK (((document_type)::text = ANY ((ARRAY['confirmation'::character varying, 'invoice'::character varying, 'receipt'::character varying])::text[])))
);


--
-- Name: expected_commissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.expected_commissions (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    client_booking_id uuid NOT NULL,
    choice_selection_id uuid NOT NULL,
    proposed_amount_minor_units bigint NOT NULL,
    amount_minor_units bigint NOT NULL,
    currency character varying NOT NULL,
    status character varying DEFAULT 'expected'::character varying NOT NULL,
    overridden_by_id uuid,
    overridden_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    confirmed_by_id uuid,
    confirmed_at timestamp(6) with time zone,
    CONSTRAINT expected_commissions_amounts CHECK (((proposed_amount_minor_units >= 0) AND (amount_minor_units >= 0) AND ((currency)::text ~ '^[A-Z]{3}$'::text))),
    CONSTRAINT expected_commissions_override CHECK ((((overridden_by_id IS NULL) = (overridden_at IS NULL)) AND (lock_version >= 0))),
    CONSTRAINT expected_commissions_status CHECK (COALESCE(((((status)::text = 'expected'::text) AND (confirmed_by_id IS NULL) AND (confirmed_at IS NULL)) OR (((status)::text = 'confirmed'::text) AND (confirmed_by_id IS NOT NULL) AND (confirmed_at IS NOT NULL))), false))
);


--
-- Name: installment_proposals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.installment_proposals (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_booking_id uuid NOT NULL,
    "position" integer NOT NULL,
    description character varying NOT NULL,
    amount_minor_units bigint NOT NULL,
    currency character varying NOT NULL,
    due_kind character varying NOT NULL,
    due_on date,
    adjusted boolean DEFAULT false NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT installment_proposals_amount CHECK (((amount_minor_units >= 0) AND ((currency)::text ~ '^[A-Z]{3}$'::text))),
    CONSTRAINT installment_proposals_description CHECK (((btrim((description)::text) <> ''::text) AND (char_length((description)::text) <= 120))),
    CONSTRAINT installment_proposals_due CHECK (COALESCE(((((due_kind)::text = 'at_confirmation'::text) AND (due_on IS NULL)) OR (((due_kind)::text = 'on_date'::text) AND (due_on IS NOT NULL))), false)),
    CONSTRAINT installment_proposals_position CHECK (("position" >= 1))
);


--
-- Name: installments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.installments (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_charge_id uuid NOT NULL,
    "position" integer NOT NULL,
    description character varying NOT NULL,
    amount_minor_units bigint NOT NULL,
    currency character varying NOT NULL,
    due_on date NOT NULL,
    route character varying DEFAULT 'agency'::character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT installments_amount CHECK (((amount_minor_units >= 0) AND ((currency)::text ~ '^[A-Z]{3}$'::text))),
    CONSTRAINT installments_description CHECK (((btrim((description)::text) <> ''::text) AND (char_length((description)::text) <= 300))),
    CONSTRAINT installments_position CHECK (("position" >= 1)),
    CONSTRAINT installments_route CHECK (((route)::text = ANY ((ARRAY['agency'::character varying, 'supplier'::character varying])::text[])))
);


--
-- Name: inventory_allocations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inventory_allocations (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    client_booking_id uuid NOT NULL,
    choice_selection_id uuid NOT NULL,
    inventory_group_id uuid NOT NULL,
    unit_shell_id uuid,
    quantity integer NOT NULL,
    state character varying DEFAULT 'held'::character varying NOT NULL,
    held_at timestamp(6) with time zone NOT NULL,
    hold_expires_at timestamp(6) with time zone,
    hold_extended_at timestamp(6) with time zone,
    reserved_at timestamp(6) with time zone,
    released_at timestamp(6) with time zone,
    replaces_allocation_id uuid,
    created_by_id uuid NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT inventory_allocations_quantity CHECK ((quantity >= 1)),
    CONSTRAINT inventory_allocations_replaces_other CHECK (((replaces_allocation_id IS NULL) OR (replaces_allocation_id <> id))),
    CONSTRAINT inventory_allocations_state CHECK (((state)::text = ANY (ARRAY[('held'::character varying)::text, ('reserved'::character varying)::text, ('released'::character varying)::text]))),
    CONSTRAINT inventory_allocations_state_timestamps CHECK (((((state)::text <> 'held'::text) OR ((hold_expires_at IS NOT NULL) AND (reserved_at IS NULL) AND (released_at IS NULL))) AND (((state)::text <> 'reserved'::text) OR ((reserved_at IS NOT NULL) AND (released_at IS NULL))) AND (((state)::text <> 'released'::text) OR (released_at IS NOT NULL))))
);


--
-- Name: inventory_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inventory_groups (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    label character varying NOT NULL,
    service_category character varying NOT NULL,
    representation character varying NOT NULL,
    availability_promise character varying NOT NULL,
    quantity integer,
    positions_per_unit integer,
    starts_on date,
    starts_at_time time without time zone,
    ends_on date,
    ends_at_time time without time zone,
    time_zone character varying,
    "position" integer DEFAULT 0 NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    required_adults_per_unit integer,
    CONSTRAINT inventory_groups_availability_promise CHECK (((availability_promise)::text = ANY (ARRAY[('firm_block'::character varying)::text, ('releasable_block'::character varying)::text, ('courtesy_option'::character varying)::text, ('on_request'::character varying)::text, ('rate_only'::character varying)::text]))),
    CONSTRAINT inventory_groups_counters CHECK ((("position" >= 0) AND (lock_version >= 0))),
    CONSTRAINT inventory_groups_dates CHECK ((((starts_on IS NULL) = (ends_on IS NULL)) AND ((starts_on IS NULL) OR (starts_on <= ends_on)))),
    CONSTRAINT inventory_groups_end_time_needs_date CHECK (((ends_at_time IS NULL) OR (ends_on IS NOT NULL))),
    CONSTRAINT inventory_groups_label CHECK (((btrim((label)::text) <> ''::text) AND (char_length((label)::text) <= 120))),
    CONSTRAINT inventory_groups_positions CHECK (((positions_per_unit IS NULL) OR ((positions_per_unit >= 1) AND ((representation)::text = 'unit_shells'::text)))),
    CONSTRAINT inventory_groups_quantity_only_when_numeric CHECK (((quantity IS NULL) OR ((quantity >= 1) AND ((representation)::text <> 'none'::text) AND ((availability_promise)::text <> ALL (ARRAY[('on_request'::character varying)::text, ('rate_only'::character varying)::text]))))),
    CONSTRAINT inventory_groups_representation CHECK (((representation)::text = ANY (ARRAY[('unit_shells'::character varying)::text, ('capacity_pool'::character varying)::text, ('none'::character varying)::text]))),
    CONSTRAINT inventory_groups_required_adults CHECK (((required_adults_per_unit IS NULL) OR ((required_adults_per_unit >= 1) AND ((positions_per_unit IS NULL) OR (required_adults_per_unit <= positions_per_unit))))),
    CONSTRAINT inventory_groups_service_category CHECK (((service_category)::text = ANY (ARRAY[('hotel'::character varying)::text, ('all_inclusive_resort'::character varying)::text, ('cruise'::character varying)::text, ('air'::character varying)::text, ('rail'::character varying)::text, ('transportation'::character varying)::text, ('activity'::character varying)::text, ('meal'::character varying)::text, ('insurance'::character varying)::text]))),
    CONSTRAINT inventory_groups_start_time_needs_date CHECK (((starts_at_time IS NULL) OR (starts_on IS NOT NULL)))
);


--
-- Name: offering_choices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offering_choices (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    offering_id uuid NOT NULL,
    name character varying NOT NULL,
    role character varying NOT NULL,
    scope character varying NOT NULL,
    pattern character varying NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT offering_choices_counters CHECK ((("position" >= 0) AND (lock_version >= 0))),
    CONSTRAINT offering_choices_multiple_only_add_ons CHECK ((((pattern)::text <> 'optional_multiple'::text) OR ((role)::text = 'add_on'::text))),
    CONSTRAINT offering_choices_name CHECK (((btrim((name)::text) <> ''::text) AND (char_length((name)::text) <= 120))),
    CONSTRAINT offering_choices_pattern CHECK (((pattern)::text = ANY (ARRAY[('required_single'::character varying)::text, ('optional_single'::character varying)::text, ('optional_multiple'::character varying)::text]))),
    CONSTRAINT offering_choices_role CHECK (((role)::text = ANY (ARRAY[('included'::character varying)::text, ('add_on'::character varying)::text]))),
    CONSTRAINT offering_choices_scope CHECK (((scope)::text = ANY (ARRAY[('per_traveler'::character varying)::text, ('per_unit'::character varying)::text, ('per_trip'::character varying)::text])))
);


--
-- Name: offering_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offering_options (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    offering_choice_id uuid NOT NULL,
    inventory_group_id uuid NOT NULL,
    label character varying NOT NULL,
    description text,
    "position" integer DEFAULT 0 NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT offering_options_counters CHECK ((("position" >= 0) AND (lock_version >= 0))),
    CONSTRAINT offering_options_label CHECK (((btrim((label)::text) <> ''::text) AND (char_length((label)::text) <= 120)))
);


--
-- Name: offering_prices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offering_prices (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    offering_option_id uuid NOT NULL,
    occupancy_position character varying NOT NULL,
    traveler_type_id uuid,
    amount_minor_units bigint NOT NULL,
    currency character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT offering_prices_amount CHECK ((amount_minor_units >= 0)),
    CONSTRAINT offering_prices_currency CHECK (((currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT offering_prices_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT offering_prices_occupancy_position CHECK (((occupancy_position)::text = ANY (ARRAY[('any'::character varying)::text, ('single'::character varying)::text, ('guest_1'::character varying)::text, ('guest_2'::character varying)::text, ('guest_3'::character varying)::text, ('guest_4'::character varying)::text, ('guest_5'::character varying)::text, ('guest_6'::character varying)::text, ('guest_7'::character varying)::text, ('guest_8'::character varying)::text, ('guest_9'::character varying)::text])))
);


--
-- Name: offering_publications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offering_publications (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    offering_id uuid NOT NULL,
    reseller_id uuid NOT NULL,
    published_at timestamp(6) with time zone NOT NULL,
    published_by_id uuid NOT NULL,
    withdrawn_at timestamp(6) with time zone,
    withdrawn_by_id uuid,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT offering_publications_withdrawn_after_published CHECK (((withdrawn_at IS NULL) OR (withdrawn_at >= published_at))),
    CONSTRAINT offering_publications_withdrawn_pair CHECK (((withdrawn_at IS NULL) = (withdrawn_by_id IS NULL)))
);


--
-- Name: offerings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offerings (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    name character varying NOT NULL,
    description text,
    currency character varying NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT offerings_counters CHECK ((("position" >= 0) AND (lock_version >= 0))),
    CONSTRAINT offerings_currency CHECK (((currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT offerings_name CHECK (((btrim((name)::text) <> ''::text) AND (char_length((name)::text) <= 120)))
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
-- Name: receipts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.receipts (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    receipt_number character varying NOT NULL,
    client_payment_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    payer_name character varying NOT NULL,
    amount_minor_units bigint NOT NULL,
    currency character varying NOT NULL,
    paid_on date NOT NULL,
    payment_method character varying NOT NULL,
    reference character varying,
    applied jsonb DEFAULT '[]'::jsonb NOT NULL,
    issued_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT receipts_amount CHECK (((amount_minor_units > 0) AND ((currency)::text ~ '^[A-Z]{3}$'::text))),
    CONSTRAINT receipts_applied CHECK ((jsonb_typeof(applied) = 'array'::text)),
    CONSTRAINT receipts_number_format CHECK (((receipt_number)::text ~ '^RCP-[0-9]{5,}$'::text))
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
    CONSTRAINT reference_sequences_namespace CHECK (((namespace)::text = ANY (ARRAY[('client'::character varying)::text, ('supplier'::character varying)::text, ('departure'::character varying)::text, ('trip'::character varying)::text, ('client_payment'::character varying)::text, ('arrangement'::character varying)::text, ('supplier_payment'::character varying)::text, ('confirmation'::character varying)::text, ('invoice'::character varying)::text, ('receipt'::character varying)::text]))),
    CONSTRAINT reference_sequences_next_value CHECK (((next_value >= 1) AND (((namespace)::text <> ALL (ARRAY[('client'::character varying)::text, ('supplier'::character varying)::text])) OR (next_value <= 1000000))))
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
    CONSTRAINT resellers_status_valid CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('booking_paused'::character varying)::text, ('suspended'::character varying)::text, ('ended'::character varying)::text])))
);


--
-- Name: schedule_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schedule_lines (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    cost_line_id uuid,
    supplier_deadline_id uuid,
    inventory_group_id uuid,
    description character varying NOT NULL,
    amount_kind character varying NOT NULL,
    amount_minor_units bigint,
    rate_minor_units bigint,
    percentage numeric(7,4),
    currency character varying NOT NULL,
    due_rule character varying NOT NULL,
    due_on date,
    trigger_type character varying,
    days_after integer,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT schedule_lines_amount_kind CHECK (COALESCE(((((amount_kind)::text = 'fixed'::text) AND (amount_minor_units >= 0) AND (rate_minor_units IS NULL) AND (percentage IS NULL)) OR (((amount_kind)::text = 'percentage_of_cost_line'::text) AND (cost_line_id IS NOT NULL) AND (percentage > (0)::numeric) AND (percentage <= (100)::numeric) AND (amount_minor_units IS NULL) AND (rate_minor_units IS NULL)) OR (((amount_kind)::text = ANY ((ARRAY['per_unit_count'::character varying, 'per_shell'::character varying])::text[])) AND (rate_minor_units >= 0) AND (amount_minor_units IS NULL) AND (percentage IS NULL)) OR (((amount_kind)::text = 'balance'::text) AND (amount_minor_units IS NULL) AND (rate_minor_units IS NULL) AND (percentage IS NULL) AND (cost_line_id IS NULL))), false)),
    CONSTRAINT schedule_lines_currency CHECK (((currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT schedule_lines_description CHECK (((btrim((description)::text) <> ''::text) AND (char_length((description)::text) <= 200))),
    CONSTRAINT schedule_lines_due_rule CHECK (COALESCE(((((due_rule)::text = 'fixed_date'::text) AND (due_on IS NOT NULL) AND (trigger_type IS NULL) AND (days_after IS NULL)) OR (((due_rule)::text = 'event'::text) AND (due_on IS NULL) AND (trigger_type IS NOT NULL) AND (days_after IS NULL)) OR (((due_rule)::text = 'event_plus_days'::text) AND (due_on IS NULL) AND (trigger_type IS NOT NULL) AND (days_after >= 1)) OR (((due_rule)::text = 'earlier_of'::text) AND (due_on IS NOT NULL) AND (trigger_type IS NOT NULL) AND (days_after IS NULL))), false)),
    CONSTRAINT schedule_lines_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT schedule_lines_trigger_type CHECK (((trigger_type IS NULL) OR ((trigger_type)::text = ANY (ARRAY[('arrangement_confirmed'::character varying)::text, ('names_submitted'::character varying)::text, ('client_booking_confirmed'::character varying)::text, ('rooming_list_submitted'::character varying)::text, ('final_count_submitted'::character varying)::text, ('tickets_issued'::character varying)::text, ('supplier_invoice_received'::character varying)::text, ('service_date'::character varying)::text, ('other'::character varying)::text]))))
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: selection_occupants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.selection_occupants (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    choice_selection_id uuid NOT NULL,
    booking_traveler_id uuid NOT NULL,
    "position" integer,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT selection_occupants_position CHECK ((("position" IS NULL) OR ("position" >= 1)))
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
-- Name: supplier_arrangements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_arrangements (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_id uuid NOT NULL,
    payee_account_id uuid,
    arrangement_reference character varying NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    currency character varying NOT NULL,
    group_reference character varying,
    reservation_scope character varying DEFAULT 'arrangement'::character varying NOT NULL,
    obligation_shape character varying,
    default_availability_promise character varying DEFAULT 'firm_block'::character varying NOT NULL,
    covered_services text,
    terms text,
    confirmed_on date,
    confirmation_note text,
    confirmed_at timestamp(6) with time zone,
    cancelled_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    rate_pattern character varying,
    rate_non_commissionable_fees_minor_units bigint,
    rate_taxes_minor_units bigint,
    rate_commission_method character varying,
    rate_commission_rate numeric(6,3),
    rate_commission_base character varying,
    rate_commission_minor_units bigint,
    CONSTRAINT supplier_arrangements_cancelled_at_pair CHECK ((((status)::text = 'cancelled'::text) = (cancelled_at IS NOT NULL))),
    CONSTRAINT supplier_arrangements_confirmed_complete CHECK ((((status)::text = ANY (ARRAY[('draft'::character varying)::text, ('cancelled'::character varying)::text])) OR ((group_reference IS NOT NULL) AND (payee_account_id IS NOT NULL) AND (confirmed_on IS NOT NULL) AND (confirmed_at IS NOT NULL)))),
    CONSTRAINT supplier_arrangements_currency CHECK (((currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT supplier_arrangements_default_promise CHECK (((default_availability_promise)::text = ANY (ARRAY[('firm_block'::character varying)::text, ('releasable_block'::character varying)::text, ('courtesy_option'::character varying)::text, ('on_request'::character varying)::text, ('rate_only'::character varying)::text]))),
    CONSTRAINT supplier_arrangements_group_reference CHECK (((group_reference IS NULL) OR ((btrim((group_reference)::text) <> ''::text) AND (char_length((group_reference)::text) <= 80)))),
    CONSTRAINT supplier_arrangements_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_arrangements_obligation_shape CHECK (((obligation_shape IS NULL) OR ((obligation_shape)::text = ANY (ARRAY[('per_unit_used'::character varying)::text, ('committed_quantity'::character varying)::text, ('fixed_resource_charge'::character varying)::text, ('minimum_pickup'::character varying)::text, ('mixed'::character varying)::text])))),
    CONSTRAINT supplier_arrangements_rate_amounts CHECK (((COALESCE(rate_non_commissionable_fees_minor_units, (0)::bigint) >= 0) AND (COALESCE(rate_taxes_minor_units, (0)::bigint) >= 0) AND (COALESCE(rate_commission_minor_units, (0)::bigint) >= 0))),
    CONSTRAINT supplier_arrangements_rate_commission CHECK (COALESCE((((rate_commission_method IS NULL) AND (rate_commission_rate IS NULL) AND (rate_commission_base IS NULL) AND (rate_commission_minor_units IS NULL)) OR (((rate_commission_method)::text = 'percent'::text) AND (rate_commission_rate >= (0)::numeric) AND (rate_commission_rate <= (100)::numeric) AND ((rate_commission_base)::text = ANY (ARRAY[('base_fare'::character varying)::text, ('base_fare_less_discount'::character varying)::text])) AND (rate_commission_minor_units IS NULL)) OR (((rate_commission_method)::text = 'amount'::text) AND (rate_commission_minor_units IS NOT NULL) AND (rate_commission_rate IS NULL) AND (rate_commission_base IS NULL))), false)),
    CONSTRAINT supplier_arrangements_rate_pattern CHECK (((rate_pattern IS NULL) OR ((rate_pattern)::text = ANY (ARRAY[('cruise_bands'::character varying)::text, ('per_guest'::character varying)::text, ('per_room'::character varying)::text, ('custom'::character varying)::text])))),
    CONSTRAINT supplier_arrangements_reference_format CHECK (((arrangement_reference)::text ~ '^ARR-[0-9]{4,}$'::text)),
    CONSTRAINT supplier_arrangements_reservation_scope CHECK (((reservation_scope)::text = ANY (ARRAY[('arrangement'::character varying)::text, ('per_unit'::character varying)::text, ('none'::character varying)::text]))),
    CONSTRAINT supplier_arrangements_status CHECK (((status)::text = ANY (ARRAY[('draft'::character varying)::text, ('confirmed'::character varying)::text, ('closed'::character varying)::text, ('cancelled'::character varying)::text])))
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
-- Name: supplier_deadlines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_deadlines (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    inventory_group_id uuid,
    deadline_type character varying NOT NULL,
    actionable boolean NOT NULL,
    description character varying NOT NULL,
    due_on date NOT NULL,
    due_at_time time without time zone,
    time_zone character varying NOT NULL,
    resolved_at timestamp(6) with time zone NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT supplier_deadlines_description CHECK (((btrim((description)::text) <> ''::text) AND (char_length((description)::text) <= 200))),
    CONSTRAINT supplier_deadlines_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_deadlines_time_zone CHECK ((btrim((time_zone)::text) <> ''::text)),
    CONSTRAINT supplier_deadlines_type CHECK (((deadline_type)::text = ANY (ARRAY[('option_release'::character varying)::text, ('deposit_payment'::character varying)::text, ('names_submission'::character varying)::text, ('rooming_list'::character varying)::text, ('ticketing'::character varying)::text, ('final_count'::character varying)::text, ('cancellation_tier_cutoff'::character varying)::text, ('other'::character varying)::text])))
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
-- Name: supplier_payment_applications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_payment_applications (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_payment_id uuid NOT NULL,
    amount_due_id uuid NOT NULL,
    amount_minor_units bigint NOT NULL,
    recorded_by_id uuid NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT supplier_payment_applications_amount CHECK ((amount_minor_units <> 0))
);


--
-- Name: supplier_payment_reversals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_payment_reversals (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_payment_id uuid NOT NULL,
    reason character varying NOT NULL,
    reversed_on date NOT NULL,
    recorded_by_id uuid NOT NULL,
    recorded_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT supplier_payment_reversals_reason CHECK (((btrim((reason)::text) <> ''::text) AND (char_length((reason)::text) <= 500)))
);


--
-- Name: supplier_payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_payments (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    supplier_id uuid NOT NULL,
    payee_account_id uuid,
    payment_reference character varying NOT NULL,
    paid_on date NOT NULL,
    amount_minor_units bigint NOT NULL,
    currency character varying NOT NULL,
    payment_method character varying NOT NULL,
    bank_reference character varying,
    invoice_reference character varying,
    recorded_by_id uuid NOT NULL,
    recorded_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT supplier_payments_amount CHECK (((amount_minor_units > 0) AND ((currency)::text ~ '^[A-Z]{3}$'::text))),
    CONSTRAINT supplier_payments_bank_reference CHECK (((bank_reference IS NULL) OR ((btrim((bank_reference)::text) <> ''::text) AND (char_length((bank_reference)::text) <= 120)))),
    CONSTRAINT supplier_payments_invoice_reference CHECK (((invoice_reference IS NULL) OR ((btrim((invoice_reference)::text) <> ''::text) AND (char_length((invoice_reference)::text) <= 120)))),
    CONSTRAINT supplier_payments_method CHECK (((payment_method)::text = ANY ((ARRAY['bank_transfer'::character varying, 'card'::character varying, 'check'::character varying, 'cash'::character varying, 'other'::character varying])::text[]))),
    CONSTRAINT supplier_payments_reference_format CHECK (((payment_reference)::text ~ '^SPY-[0-9]{4,}$'::text))
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
-- Name: supplier_rate_bands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_rate_bands (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    label character varying NOT NULL,
    positions character varying[] NOT NULL,
    traveler_type_id uuid,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT supplier_rate_bands_label CHECK (((btrim((label)::text) <> ''::text) AND (char_length((label)::text) <= 60))),
    CONSTRAINT supplier_rate_bands_position CHECK (("position" >= 0)),
    CONSTRAINT supplier_rate_bands_positions CHECK (((cardinality(positions) >= 1) AND (positions <@ ARRAY['single'::character varying, 'guest_1'::character varying, 'guest_2'::character varying, 'guest_3'::character varying, 'guest_4'::character varying, 'guest_5'::character varying, 'guest_6'::character varying, 'guest_7'::character varying, 'guest_8'::character varying, 'guest_9'::character varying])))
);


--
-- Name: supplier_rate_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_rate_lines (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    inventory_group_id uuid NOT NULL,
    traveler_type_id uuid,
    occupancy_position character varying NOT NULL,
    currency character varying NOT NULL,
    base_fare_minor_units bigint NOT NULL,
    non_commissionable_fees_minor_units bigint DEFAULT 0 CONSTRAINT supplier_rate_lines_non_commissionable_fees_minor_unit_not_null NOT NULL,
    taxes_minor_units bigint DEFAULT 0 NOT NULL,
    discount_minor_units bigint DEFAULT 0 NOT NULL,
    commission_rate numeric(6,3),
    commission_minor_units bigint,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    commission_base character varying DEFAULT 'base_fare'::character varying NOT NULL,
    supplier_rate_band_id uuid,
    overridden_fields character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    CONSTRAINT supplier_rate_lines_amounts_non_negative CHECK (((base_fare_minor_units >= 0) AND (non_commissionable_fees_minor_units >= 0) AND (taxes_minor_units >= 0) AND (discount_minor_units >= 0) AND ((commission_minor_units IS NULL) OR (commission_minor_units >= 0)))),
    CONSTRAINT supplier_rate_lines_commission_base CHECK (((commission_base)::text = ANY (ARRAY[('base_fare'::character varying)::text, ('base_fare_less_discount'::character varying)::text]))),
    CONSTRAINT supplier_rate_lines_commission_rate CHECK (((commission_rate IS NULL) OR ((commission_rate >= (0)::numeric) AND (commission_rate <= (100)::numeric)))),
    CONSTRAINT supplier_rate_lines_commission_rate_or_amount CHECK (((commission_rate IS NULL) OR (commission_minor_units IS NULL))),
    CONSTRAINT supplier_rate_lines_currency CHECK (((currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT supplier_rate_lines_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_rate_lines_occupancy_position CHECK ((((occupancy_position)::text = 'single'::text) OR ((occupancy_position)::text ~ '^guest_[1-9]$'::text))),
    CONSTRAINT supplier_rate_lines_overridden_fields CHECK ((overridden_fields <@ ARRAY['non_commissionable_fees'::character varying, 'taxes'::character varying, 'commission'::character varying]))
);


--
-- Name: supplier_reservation_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_reservation_events (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_reservation_id uuid NOT NULL,
    event_type character varying NOT NULL,
    occurred_on date NOT NULL,
    recorded_by_id uuid NOT NULL,
    recorded_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT supplier_reservation_events_type CHECK (((event_type)::text = ANY (ARRAY[('requested'::character varying)::text, ('confirmed'::character varying)::text, ('declined'::character varying)::text, ('cancelled'::character varying)::text])))
);


--
-- Name: supplier_reservation_units; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_reservation_units (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_reservation_id uuid NOT NULL,
    choice_selection_id uuid NOT NULL,
    open boolean DEFAULT true NOT NULL,
    created_at timestamp(6) with time zone NOT NULL
);


--
-- Name: supplier_reservations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_reservations (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    client_booking_id uuid NOT NULL,
    status character varying DEFAULT 'requested'::character varying NOT NULL,
    supplier_reference character varying,
    responded_on date,
    response_note text,
    requested_by_id uuid NOT NULL,
    requested_at timestamp(6) with time zone NOT NULL,
    responded_by_id uuid,
    responded_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT supplier_reservations_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT supplier_reservations_note CHECK (((response_note IS NULL) OR ((btrim(response_note) <> ''::text) AND (char_length(response_note) <= 2000)))),
    CONSTRAINT supplier_reservations_reference CHECK (((supplier_reference IS NULL) OR ((btrim((supplier_reference)::text) <> ''::text) AND (char_length((supplier_reference)::text) <= 120)))),
    CONSTRAINT supplier_reservations_response CHECK (COALESCE(((((status)::text = 'requested'::text) AND (responded_on IS NULL) AND (responded_by_id IS NULL) AND (responded_at IS NULL)) OR (((status)::text = 'confirmed'::text) AND (supplier_reference IS NOT NULL) AND (responded_on IS NOT NULL) AND (responded_by_id IS NOT NULL) AND (responded_at IS NOT NULL)) OR ((status)::text = ANY (ARRAY[('declined'::character varying)::text, ('cancelled'::character varying)::text]))), false)),
    CONSTRAINT supplier_reservations_status CHECK (((status)::text = ANY (ARRAY[('requested'::character varying)::text, ('confirmed'::character varying)::text, ('declined'::character varying)::text, ('cancelled'::character varying)::text])))
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
-- Name: tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tasks (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    departure_id uuid NOT NULL,
    source character varying NOT NULL,
    supplier_deadline_id uuid,
    action character varying NOT NULL,
    due_at timestamp(6) with time zone NOT NULL,
    due_on date NOT NULL,
    due_at_time time without time zone,
    due_time_zone character varying NOT NULL,
    owner_id uuid NOT NULL,
    status character varying DEFAULT 'open'::character varying NOT NULL,
    completion_note text,
    completed_at timestamp(6) with time zone,
    waiver_reason text,
    waived_at timestamp(6) with time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    schedule_line_id uuid,
    amount_due_id uuid,
    CONSTRAINT tasks_action CHECK (((btrim((action)::text) <> ''::text) AND (char_length((action)::text) <= 250))),
    CONSTRAINT tasks_completed_with_note CHECK (((((status)::text = 'completed'::text) = (completed_at IS NOT NULL)) AND (((status)::text <> 'completed'::text) OR (btrim(COALESCE(completion_note, ''::text)) <> ''::text)))),
    CONSTRAINT tasks_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT tasks_source CHECK (((source)::text = ANY (ARRAY[('supplier_deadline'::character varying)::text, ('schedule_line'::character varying)::text, ('amount_due'::character varying)::text, ('manual'::character varying)::text]))),
    CONSTRAINT tasks_source_record CHECK (((((source)::text = 'supplier_deadline'::text) = (supplier_deadline_id IS NOT NULL)) AND (((source)::text = 'schedule_line'::text) = (schedule_line_id IS NOT NULL)) AND (((source)::text = 'amount_due'::text) = (amount_due_id IS NOT NULL)))),
    CONSTRAINT tasks_status CHECK (((status)::text = ANY (ARRAY[('open'::character varying)::text, ('in_progress'::character varying)::text, ('completed'::character varying)::text, ('waived'::character varying)::text]))),
    CONSTRAINT tasks_waived_with_reason CHECK (((((status)::text = 'waived'::text) = (waived_at IS NOT NULL)) AND (((status)::text <> 'waived'::text) OR (btrim(COALESCE(waiver_reason, ''::text)) <> ''::text))))
);


--
-- Name: traveler_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.traveler_links (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    traveler_id uuid NOT NULL,
    client_id uuid NOT NULL,
    relationship character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT traveler_links_relationship CHECK (((relationship)::text = ANY (ARRAY[('self'::character varying)::text, ('family_member'::character varying)::text, ('employee_or_member'::character varying)::text, ('other'::character varying)::text])))
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
    counts_as_adult boolean DEFAULT false NOT NULL,
    CONSTRAINT traveler_types_lock_version_nonnegative CHECK ((lock_version >= 0)),
    CONSTRAINT traveler_types_name CHECK (((btrim((name)::text) <> ''::text) AND (char_length((name)::text) <= 60))),
    CONSTRAINT traveler_types_position_nonnegative CHECK (("position" >= 0)),
    CONSTRAINT traveler_types_status_valid CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('inactive'::character varying)::text])))
);


--
-- Name: travelers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.travelers (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    given_names character varying,
    middle_name character varying,
    surname character varying,
    suffix character varying,
    preferred_name character varying,
    date_of_birth date,
    gender character varying,
    email_address character varying,
    phone character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    created_by_id uuid,
    CONSTRAINT travelers_contacts CHECK ((((email_address IS NULL) OR (((email_address)::text = lower(btrim((email_address)::text))) AND ((email_address)::text ~~ '%_@_%'::text) AND (char_length((email_address)::text) <= 254))) AND ((phone IS NULL) OR ((btrim((phone)::text) <> ''::text) AND (char_length((phone)::text) <= 40))))),
    CONSTRAINT travelers_date_of_birth CHECK (((date_of_birth IS NULL) OR (date_of_birth >= '1900-01-01'::date))),
    CONSTRAINT travelers_gender CHECK (((gender IS NULL) OR ((gender)::text = ANY (ARRAY[('female'::character varying)::text, ('male'::character varying)::text, ('unspecified'::character varying)::text])))),
    CONSTRAINT travelers_lock_version CHECK ((lock_version >= 0)),
    CONSTRAINT travelers_name_lengths CHECK ((((given_names IS NULL) OR ((btrim((given_names)::text) <> ''::text) AND (char_length((given_names)::text) <= 80))) AND ((middle_name IS NULL) OR ((btrim((middle_name)::text) <> ''::text) AND (char_length((middle_name)::text) <= 80))) AND ((surname IS NULL) OR ((btrim((surname)::text) <> ''::text) AND (char_length((surname)::text) <= 80))) AND ((suffix IS NULL) OR ((btrim((suffix)::text) <> ''::text) AND (char_length((suffix)::text) <= 20))) AND ((preferred_name IS NULL) OR ((btrim((preferred_name)::text) <> ''::text) AND (char_length((preferred_name)::text) <= 80))))),
    CONSTRAINT travelers_some_name CHECK ((num_nonnulls(given_names, surname, preferred_name) >= 1))
);


--
-- Name: trigger_event_shells; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trigger_event_shells (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    trigger_event_id uuid NOT NULL,
    unit_shell_id uuid NOT NULL,
    created_at timestamp(6) with time zone NOT NULL
);


--
-- Name: trigger_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trigger_events (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    supplier_arrangement_id uuid NOT NULL,
    event_type character varying NOT NULL,
    occurred_on date NOT NULL,
    count integer,
    reference character varying,
    recorded_by_id uuid,
    recorded_by_identifier character varying,
    recorded_at timestamp(6) with time zone NOT NULL,
    client_booking_id uuid,
    CONSTRAINT trigger_events_count CHECK (((count IS NULL) OR (count >= 0))),
    CONSTRAINT trigger_events_recorded_by CHECK (((recorded_by_id IS NULL) <> (recorded_by_identifier IS NULL))),
    CONSTRAINT trigger_events_reference CHECK (((reference IS NULL) OR ((btrim((reference)::text) <> ''::text) AND (char_length((reference)::text) <= 120)))),
    CONSTRAINT trigger_events_type CHECK (((event_type)::text = ANY (ARRAY[('arrangement_confirmed'::character varying)::text, ('names_submitted'::character varying)::text, ('client_booking_confirmed'::character varying)::text, ('rooming_list_submitted'::character varying)::text, ('final_count_submitted'::character varying)::text, ('tickets_issued'::character varying)::text, ('supplier_invoice_received'::character varying)::text, ('service_date'::character varying)::text, ('other'::character varying)::text])))
);


--
-- Name: unit_shells; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.unit_shells (
    id uuid DEFAULT uuidv7() NOT NULL,
    agency_id uuid NOT NULL,
    inventory_group_id uuid NOT NULL,
    label character varying NOT NULL,
    positions integer NOT NULL,
    supplier_assignment character varying,
    "position" integer NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT unit_shells_assignment CHECK (((supplier_assignment IS NULL) OR ((btrim((supplier_assignment)::text) <> ''::text) AND (char_length((supplier_assignment)::text) <= 40)))),
    CONSTRAINT unit_shells_counts CHECK (((positions >= 1) AND ("position" >= 1))),
    CONSTRAINT unit_shells_label CHECK (((btrim((label)::text) <> ''::text) AND (char_length((label)::text) <= 40)))
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
    CONSTRAINT user_permissions_permission_valid CHECK (((permission)::text = ANY (ARRAY[('departure_management'::character varying)::text, ('supplier_arrangements'::character varying)::text, ('financial_records'::character varying)::text, ('passport_access'::character varying)::text, ('reseller_relationships'::character varying)::text]))),
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
-- Name: agency_cancellation_tiers agency_cancellation_tiers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agency_cancellation_tiers
    ADD CONSTRAINT agency_cancellation_tiers_pkey PRIMARY KEY (id);


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
-- Name: amounts_due amounts_due_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.amounts_due
    ADD CONSTRAINT amounts_due_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: arrangement_documents arrangement_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arrangement_documents
    ADD CONSTRAINT arrangement_documents_pkey PRIMARY KEY (id);


--
-- Name: audit_events audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_pkey PRIMARY KEY (id);


--
-- Name: booking_acceptances booking_acceptances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_acceptances
    ADD CONSTRAINT booking_acceptances_pkey PRIMARY KEY (id);


--
-- Name: booking_price_lines booking_price_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_price_lines
    ADD CONSTRAINT booking_price_lines_pkey PRIMARY KEY (id);


--
-- Name: booking_travelers booking_travelers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_travelers
    ADD CONSTRAINT booking_travelers_pkey PRIMARY KEY (id);


--
-- Name: capacity_events capacity_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_events
    ADD CONSTRAINT capacity_events_pkey PRIMARY KEY (id);


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
-- Name: capacity_rules capacity_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_rules
    ADD CONSTRAINT capacity_rules_pkey PRIMARY KEY (id);


--
-- Name: charge_lines charge_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge_lines
    ADD CONSTRAINT charge_lines_pkey PRIMARY KEY (id);


--
-- Name: choice_selections choice_selections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.choice_selections
    ADD CONSTRAINT choice_selections_pkey PRIMARY KEY (id);


--
-- Name: client_bookings client_bookings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_bookings
    ADD CONSTRAINT client_bookings_pkey PRIMARY KEY (id);


--
-- Name: client_cancellation_tiers client_cancellation_tiers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_cancellation_tiers
    ADD CONSTRAINT client_cancellation_tiers_pkey PRIMARY KEY (id);


--
-- Name: client_charges client_charges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_charges
    ADD CONSTRAINT client_charges_pkey PRIMARY KEY (id);


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
-- Name: client_payment_applications client_payment_applications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_payment_applications
    ADD CONSTRAINT client_payment_applications_pkey PRIMARY KEY (id);


--
-- Name: client_payment_reversals client_payment_reversals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_payment_reversals
    ADD CONSTRAINT client_payment_reversals_pkey PRIMARY KEY (id);


--
-- Name: client_payment_schedule_lines client_payment_schedule_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_payment_schedule_lines
    ADD CONSTRAINT client_payment_schedule_lines_pkey PRIMARY KEY (id);


--
-- Name: client_payments client_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_payments
    ADD CONSTRAINT client_payments_pkey PRIMARY KEY (id);


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
-- Name: client_terms_versions client_terms_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_terms_versions
    ADD CONSTRAINT client_terms_versions_pkey PRIMARY KEY (id);


--
-- Name: client_trips client_trips_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_trips
    ADD CONSTRAINT client_trips_pkey PRIMARY KEY (id);


--
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id);


--
-- Name: cost_line_shells cost_line_shells_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_line_shells
    ADD CONSTRAINT cost_line_shells_pkey PRIMARY KEY (id);


--
-- Name: cost_lines cost_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_lines
    ADD CONSTRAINT cost_lines_pkey PRIMARY KEY (id);


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
-- Name: document_deliveries document_deliveries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_deliveries
    ADD CONSTRAINT document_deliveries_pkey PRIMARY KEY (id);


--
-- Name: document_versions document_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_versions
    ADD CONSTRAINT document_versions_pkey PRIMARY KEY (id);


--
-- Name: expected_commissions expected_commissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expected_commissions
    ADD CONSTRAINT expected_commissions_pkey PRIMARY KEY (id);


--
-- Name: installment_proposals installment_proposals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.installment_proposals
    ADD CONSTRAINT installment_proposals_pkey PRIMARY KEY (id);


--
-- Name: installments installments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.installments
    ADD CONSTRAINT installments_pkey PRIMARY KEY (id);


--
-- Name: inventory_allocations inventory_allocations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_allocations
    ADD CONSTRAINT inventory_allocations_pkey PRIMARY KEY (id);


--
-- Name: inventory_groups inventory_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_groups
    ADD CONSTRAINT inventory_groups_pkey PRIMARY KEY (id);


--
-- Name: offering_choices offering_choices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offering_choices
    ADD CONSTRAINT offering_choices_pkey PRIMARY KEY (id);


--
-- Name: offering_options offering_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offering_options
    ADD CONSTRAINT offering_options_pkey PRIMARY KEY (id);


--
-- Name: offering_prices offering_prices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offering_prices
    ADD CONSTRAINT offering_prices_pkey PRIMARY KEY (id);


--
-- Name: offering_publications offering_publications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offering_publications
    ADD CONSTRAINT offering_publications_pkey PRIMARY KEY (id);


--
-- Name: offerings offerings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offerings
    ADD CONSTRAINT offerings_pkey PRIMARY KEY (id);


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
-- Name: receipts receipts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receipts
    ADD CONSTRAINT receipts_pkey PRIMARY KEY (id);


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
-- Name: schedule_lines schedule_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedule_lines
    ADD CONSTRAINT schedule_lines_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: selection_occupants selection_occupants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.selection_occupants
    ADD CONSTRAINT selection_occupants_pkey PRIMARY KEY (id);


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
-- Name: supplier_deadlines supplier_deadlines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadlines
    ADD CONSTRAINT supplier_deadlines_pkey PRIMARY KEY (id);


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
-- Name: supplier_payment_applications supplier_payment_applications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payment_applications
    ADD CONSTRAINT supplier_payment_applications_pkey PRIMARY KEY (id);


--
-- Name: supplier_payment_reversals supplier_payment_reversals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payment_reversals
    ADD CONSTRAINT supplier_payment_reversals_pkey PRIMARY KEY (id);


--
-- Name: supplier_payments supplier_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payments
    ADD CONSTRAINT supplier_payments_pkey PRIMARY KEY (id);


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
-- Name: supplier_rate_bands supplier_rate_bands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_rate_bands
    ADD CONSTRAINT supplier_rate_bands_pkey PRIMARY KEY (id);


--
-- Name: supplier_rate_lines supplier_rate_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_rate_lines
    ADD CONSTRAINT supplier_rate_lines_pkey PRIMARY KEY (id);


--
-- Name: supplier_reservation_events supplier_reservation_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_events
    ADD CONSTRAINT supplier_reservation_events_pkey PRIMARY KEY (id);


--
-- Name: supplier_reservation_units supplier_reservation_units_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_units
    ADD CONSTRAINT supplier_reservation_units_pkey PRIMARY KEY (id);


--
-- Name: supplier_reservations supplier_reservations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservations
    ADD CONSTRAINT supplier_reservations_pkey PRIMARY KEY (id);


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
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: traveler_links traveler_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traveler_links
    ADD CONSTRAINT traveler_links_pkey PRIMARY KEY (id);


--
-- Name: traveler_types traveler_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traveler_types
    ADD CONSTRAINT traveler_types_pkey PRIMARY KEY (id);


--
-- Name: travelers travelers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.travelers
    ADD CONSTRAINT travelers_pkey PRIMARY KEY (id);


--
-- Name: trigger_event_shells trigger_event_shells_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trigger_event_shells
    ADD CONSTRAINT trigger_event_shells_pkey PRIMARY KEY (id);


--
-- Name: trigger_events trigger_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trigger_events
    ADD CONSTRAINT trigger_events_pkey PRIMARY KEY (id);


--
-- Name: unit_shells unit_shells_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit_shells
    ADD CONSTRAINT unit_shells_pkey PRIMARY KEY (id);


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
-- Name: index_agency_cancellation_tiers_one_per_day; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agency_cancellation_tiers_one_per_day ON public.agency_cancellation_tiers USING btree (agency_id, min_days_before_departure);


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
-- Name: index_amounts_due_on_agency_and_due_on; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_amounts_due_on_agency_and_due_on ON public.amounts_due USING btree (agency_id, due_on);


--
-- Name: index_amounts_due_on_arrangement; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_amounts_due_on_arrangement ON public.amounts_due USING btree (supplier_arrangement_id);


--
-- Name: index_amounts_due_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_amounts_due_on_id_and_agency_id ON public.amounts_due USING btree (id, agency_id);


--
-- Name: index_amounts_due_one_per_shell_per_schedule_line; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_amounts_due_one_per_shell_per_schedule_line ON public.amounts_due USING btree (schedule_line_id, unit_shell_id) NULLS NOT DISTINCT WHERE (schedule_line_id IS NOT NULL);


--
-- Name: index_arrangement_documents_on_supplier_arrangement_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_arrangement_documents_on_supplier_arrangement_id ON public.arrangement_documents USING btree (supplier_arrangement_id);


--
-- Name: index_audit_events_on_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_agency_id ON public.audit_events USING btree (agency_id);


--
-- Name: index_audit_events_on_agency_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_agency_id_and_created_at ON public.audit_events USING btree (agency_id, created_at);


--
-- Name: index_booking_acceptances_on_booking_and_recorded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_booking_acceptances_on_booking_and_recorded_at ON public.booking_acceptances USING btree (client_booking_id, recorded_at);


--
-- Name: index_booking_acceptances_on_client_payment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_booking_acceptances_on_client_payment ON public.booking_acceptances USING btree (client_payment_id);


--
-- Name: index_booking_acceptances_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_booking_acceptances_on_id_and_agency_id ON public.booking_acceptances USING btree (id, agency_id);


--
-- Name: index_booking_price_lines_on_booking; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_booking_price_lines_on_booking ON public.booking_price_lines USING btree (client_booking_id);


--
-- Name: index_booking_price_lines_on_offering_price; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_booking_price_lines_on_offering_price ON public.booking_price_lines USING btree (offering_price_id);


--
-- Name: index_booking_price_lines_one_per_selection_and_traveler; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_booking_price_lines_one_per_selection_and_traveler ON public.booking_price_lines USING btree (choice_selection_id, booking_traveler_id) NULLS NOT DISTINCT;


--
-- Name: index_booking_travelers_on_booking_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_booking_travelers_on_booking_and_position ON public.booking_travelers USING btree (client_booking_id, "position");


--
-- Name: index_booking_travelers_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_booking_travelers_on_id_and_agency_id ON public.booking_travelers USING btree (id, agency_id);


--
-- Name: index_booking_travelers_on_traveler; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_booking_travelers_on_traveler ON public.booking_travelers USING btree (traveler_id);


--
-- Name: index_booking_travelers_one_per_traveler; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_booking_travelers_one_per_traveler ON public.booking_travelers USING btree (client_booking_id, traveler_id) WHERE (traveler_id IS NOT NULL);


--
-- Name: index_capacity_events_on_agency_and_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_events_on_agency_and_idempotency_key ON public.capacity_events USING btree (agency_id, idempotency_key);


--
-- Name: index_capacity_events_on_group_timeline; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_capacity_events_on_group_timeline ON public.capacity_events USING btree (inventory_group_id, effective_on, effective_sequence);


--
-- Name: index_capacity_events_on_unit_shell; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_capacity_events_on_unit_shell ON public.capacity_events USING btree (unit_shell_id) WHERE (unit_shell_id IS NOT NULL);


--
-- Name: index_capacity_pools_on_group; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_pools_on_group ON public.capacity_pools USING btree (inventory_group_id);


--
-- Name: index_capacity_pools_on_id_and_group; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_pools_on_id_and_group ON public.capacity_pools USING btree (id, inventory_group_id);


--
-- Name: index_capacity_projections_on_group; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_projections_on_group ON public.capacity_projections USING btree (inventory_group_id);


--
-- Name: index_capacity_rules_on_group_and_traveler_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capacity_rules_on_group_and_traveler_type ON public.capacity_rules USING btree (inventory_group_id, traveler_type_id);


--
-- Name: index_charge_lines_on_charge; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charge_lines_on_charge ON public.charge_lines USING btree (client_charge_id);


--
-- Name: index_choice_selections_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_choice_selections_on_id_and_agency_id ON public.choice_selections USING btree (id, agency_id);


--
-- Name: index_choice_selections_on_option; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_choice_selections_on_option ON public.choice_selections USING btree (offering_option_id);


--
-- Name: index_choice_selections_one_per_option_and_unit; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_choice_selections_one_per_option_and_unit ON public.choice_selections USING btree (client_booking_id, offering_option_id, unit_number) NULLS NOT DISTINCT WHERE (removed_at IS NULL);


--
-- Name: index_client_bookings_on_agency_and_reference; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_bookings_on_agency_and_reference ON public.client_bookings USING btree (agency_id, booking_reference);


--
-- Name: index_client_bookings_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_bookings_on_id_and_agency_id ON public.client_bookings USING btree (id, agency_id);


--
-- Name: index_client_bookings_on_offering; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_bookings_on_offering ON public.client_bookings USING btree (offering_id);


--
-- Name: index_client_bookings_on_owner_reseller; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_bookings_on_owner_reseller ON public.client_bookings USING btree (owner_reseller_id) WHERE (owner_reseller_id IS NOT NULL);


--
-- Name: index_client_bookings_on_trip_and_sequence; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_bookings_on_trip_and_sequence ON public.client_bookings USING btree (client_trip_id, sequence);


--
-- Name: index_client_cancellation_tiers_one_per_day; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_cancellation_tiers_one_per_day ON public.client_cancellation_tiers USING btree (client_terms_version_id, min_days_before_departure);


--
-- Name: index_client_charges_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_charges_on_id_and_agency_id ON public.client_charges USING btree (id, agency_id);


--
-- Name: index_client_charges_one_per_booking; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_charges_one_per_booking ON public.client_charges USING btree (client_booking_id);


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
-- Name: index_client_payment_applications_on_installment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_payment_applications_on_installment ON public.client_payment_applications USING btree (installment_id);


--
-- Name: index_client_payment_applications_on_payment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_payment_applications_on_payment ON public.client_payment_applications USING btree (client_payment_id);


--
-- Name: index_client_payment_reversals_one_per_payment; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_payment_reversals_one_per_payment ON public.client_payment_reversals USING btree (client_payment_id);


--
-- Name: index_client_payment_schedule_lines_on_version_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_payment_schedule_lines_on_version_and_position ON public.client_payment_schedule_lines USING btree (client_terms_version_id, "position");


--
-- Name: index_client_payment_schedule_lines_one_acceptance; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_payment_schedule_lines_one_acceptance ON public.client_payment_schedule_lines USING btree (client_terms_version_id) WHERE counts_as_acceptance;


--
-- Name: index_client_payment_schedule_lines_one_balance; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_payment_schedule_lines_one_balance ON public.client_payment_schedule_lines USING btree (client_terms_version_id) WHERE ((basis)::text = 'balance'::text);


--
-- Name: index_client_payments_on_agency_and_reference; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_payments_on_agency_and_reference ON public.client_payments USING btree (agency_id, payment_reference);


--
-- Name: index_client_payments_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_payments_on_id_and_agency_id ON public.client_payments USING btree (id, agency_id);


--
-- Name: index_client_payments_on_trip; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_payments_on_trip ON public.client_payments USING btree (client_trip_id, paid_on);


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
-- Name: index_client_terms_versions_on_departure_and_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_terms_versions_on_departure_and_number ON public.client_terms_versions USING btree (departure_id, version_number);


--
-- Name: index_client_terms_versions_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_terms_versions_on_id_and_agency_id ON public.client_terms_versions USING btree (id, agency_id);


--
-- Name: index_client_trips_on_agency_and_reference; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_trips_on_agency_and_reference ON public.client_trips USING btree (agency_id, trip_reference);


--
-- Name: index_client_trips_on_client; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_trips_on_client ON public.client_trips USING btree (client_id);


--
-- Name: index_client_trips_on_departure; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_trips_on_departure ON public.client_trips USING btree (departure_id);


--
-- Name: index_client_trips_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_trips_on_id_and_agency_id ON public.client_trips USING btree (id, agency_id);


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
-- Name: index_cost_line_shells_on_line_and_shell; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cost_line_shells_on_line_and_shell ON public.cost_line_shells USING btree (cost_line_id, unit_shell_id);


--
-- Name: index_cost_line_shells_on_shell; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cost_line_shells_on_shell ON public.cost_line_shells USING btree (unit_shell_id);


--
-- Name: index_cost_lines_on_arrangement; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cost_lines_on_arrangement ON public.cost_lines USING btree (supplier_arrangement_id);


--
-- Name: index_cost_lines_on_client_booking; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cost_lines_on_client_booking ON public.cost_lines USING btree (client_booking_id);


--
-- Name: index_cost_lines_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cost_lines_on_id_and_agency_id ON public.cost_lines USING btree (id, agency_id);


--
-- Name: index_cost_lines_on_id_and_arrangement; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cost_lines_on_id_and_arrangement ON public.cost_lines USING btree (id, supplier_arrangement_id);


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
-- Name: index_document_deliveries_on_version; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_document_deliveries_on_version ON public.document_deliveries USING btree (document_version_id);


--
-- Name: index_document_versions_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_document_versions_on_id_and_agency_id ON public.document_versions USING btree (id, agency_id);


--
-- Name: index_document_versions_on_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_document_versions_on_number ON public.document_versions USING btree (agency_id, document_type, number, version_number);


--
-- Name: index_document_versions_one_per_booking; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_document_versions_one_per_booking ON public.document_versions USING btree (client_booking_id, document_type) WHERE ((supersedes_id IS NULL) AND (client_booking_id IS NOT NULL));


--
-- Name: index_document_versions_one_per_receipt; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_document_versions_one_per_receipt ON public.document_versions USING btree (receipt_id) WHERE ((supersedes_id IS NULL) AND (receipt_id IS NOT NULL));


--
-- Name: index_expected_commissions_on_arrangement; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_expected_commissions_on_arrangement ON public.expected_commissions USING btree (supplier_arrangement_id);


--
-- Name: index_expected_commissions_on_booking; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_expected_commissions_on_booking ON public.expected_commissions USING btree (client_booking_id);


--
-- Name: index_expected_commissions_one_per_service; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_expected_commissions_one_per_service ON public.expected_commissions USING btree (choice_selection_id);


--
-- Name: index_installment_proposals_on_booking_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_installment_proposals_on_booking_and_position ON public.installment_proposals USING btree (client_booking_id, "position");


--
-- Name: index_installments_on_charge_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_installments_on_charge_and_position ON public.installments USING btree (client_charge_id, "position");


--
-- Name: index_installments_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_installments_on_id_and_agency_id ON public.installments USING btree (id, agency_id);


--
-- Name: index_inventory_allocations_on_booking_and_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inventory_allocations_on_booking_and_state ON public.inventory_allocations USING btree (client_booking_id, state);


--
-- Name: index_inventory_allocations_on_group_and_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inventory_allocations_on_group_and_state ON public.inventory_allocations USING btree (inventory_group_id, state);


--
-- Name: index_inventory_allocations_on_replaced; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inventory_allocations_on_replaced ON public.inventory_allocations USING btree (replaces_allocation_id);


--
-- Name: index_inventory_allocations_on_selection; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inventory_allocations_on_selection ON public.inventory_allocations USING btree (choice_selection_id);


--
-- Name: index_inventory_allocations_on_shell_and_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inventory_allocations_on_shell_and_state ON public.inventory_allocations USING btree (unit_shell_id, state);


--
-- Name: index_inventory_groups_on_arrangement_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inventory_groups_on_arrangement_and_position ON public.inventory_groups USING btree (supplier_arrangement_id, "position");


--
-- Name: index_inventory_groups_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_inventory_groups_on_id_and_agency_id ON public.inventory_groups USING btree (id, agency_id);


--
-- Name: index_inventory_groups_on_id_and_arrangement; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_inventory_groups_on_id_and_arrangement ON public.inventory_groups USING btree (id, supplier_arrangement_id);


--
-- Name: index_offering_choices_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_offering_choices_on_id_and_agency_id ON public.offering_choices USING btree (id, agency_id);


--
-- Name: index_offering_choices_on_offering_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_offering_choices_on_offering_and_position ON public.offering_choices USING btree (offering_id, "position");


--
-- Name: index_offering_options_on_group; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_offering_options_on_group ON public.offering_options USING btree (inventory_group_id);


--
-- Name: index_offering_options_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_offering_options_on_id_and_agency_id ON public.offering_options USING btree (id, agency_id);


--
-- Name: index_offering_options_one_per_group_in_choice; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_offering_options_one_per_group_in_choice ON public.offering_options USING btree (offering_choice_id, inventory_group_id);


--
-- Name: index_offering_prices_one_per_option_position_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_offering_prices_one_per_option_position_type ON public.offering_prices USING btree (offering_option_id, occupancy_position, traveler_type_id) NULLS NOT DISTINCT;


--
-- Name: index_offering_publications_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_offering_publications_on_id_and_agency_id ON public.offering_publications USING btree (id, agency_id);


--
-- Name: index_offering_publications_on_reseller; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_offering_publications_on_reseller ON public.offering_publications USING btree (reseller_id, withdrawn_at);


--
-- Name: index_offering_publications_one_open_per_channel; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_offering_publications_one_open_per_channel ON public.offering_publications USING btree (offering_id, reseller_id) WHERE (withdrawn_at IS NULL);


--
-- Name: index_offerings_on_departure_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_offerings_on_departure_and_name ON public.offerings USING btree (departure_id, name);


--
-- Name: index_offerings_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_offerings_on_id_and_agency_id ON public.offerings USING btree (id, agency_id);


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
-- Name: index_receipts_on_agency_and_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_receipts_on_agency_and_number ON public.receipts USING btree (agency_id, receipt_number);


--
-- Name: index_receipts_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_receipts_on_id_and_agency_id ON public.receipts USING btree (id, agency_id);


--
-- Name: index_receipts_one_per_payment; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_receipts_one_per_payment ON public.receipts USING btree (client_payment_id);


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
-- Name: index_schedule_lines_on_arrangement; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schedule_lines_on_arrangement ON public.schedule_lines USING btree (supplier_arrangement_id);


--
-- Name: index_schedule_lines_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_schedule_lines_on_id_and_agency_id ON public.schedule_lines USING btree (id, agency_id);


--
-- Name: index_schedule_lines_on_id_and_arrangement; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_schedule_lines_on_id_and_arrangement ON public.schedule_lines USING btree (id, supplier_arrangement_id);


--
-- Name: index_selection_occupants_on_traveler; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_selection_occupants_on_traveler ON public.selection_occupants USING btree (booking_traveler_id);


--
-- Name: index_selection_occupants_one_per_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_selection_occupants_one_per_position ON public.selection_occupants USING btree (choice_selection_id, "position") WHERE ("position" IS NOT NULL);


--
-- Name: index_selection_occupants_one_per_traveler; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_selection_occupants_one_per_traveler ON public.selection_occupants USING btree (choice_selection_id, booking_traveler_id);


--
-- Name: index_sessions_on_agency_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_agency_user_id ON public.sessions USING btree (agency_user_id);


--
-- Name: index_sessions_on_office_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_office_id ON public.sessions USING btree (office_id);


--
-- Name: index_supplier_arrangements_on_agency_and_reference; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_arrangements_on_agency_and_reference ON public.supplier_arrangements USING btree (agency_id, arrangement_reference);


--
-- Name: index_supplier_arrangements_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_arrangements_on_id_and_agency_id ON public.supplier_arrangements USING btree (id, agency_id);


--
-- Name: index_supplier_arrangements_on_id_and_currency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_arrangements_on_id_and_currency ON public.supplier_arrangements USING btree (id, currency);


--
-- Name: index_supplier_arrangements_on_id_and_departure_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_arrangements_on_id_and_departure_id ON public.supplier_arrangements USING btree (id, departure_id);


--
-- Name: index_supplier_arrangements_one_live_per_departure_supplier; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_arrangements_one_live_per_departure_supplier ON public.supplier_arrangements USING btree (departure_id, supplier_id) WHERE ((status)::text <> 'cancelled'::text);


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
-- Name: index_supplier_deadlines_on_arrangement_and_resolved_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_deadlines_on_arrangement_and_resolved_at ON public.supplier_deadlines USING btree (supplier_arrangement_id, resolved_at);


--
-- Name: index_supplier_deadlines_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_deadlines_on_id_and_agency_id ON public.supplier_deadlines USING btree (id, agency_id);


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
-- Name: index_supplier_payment_applications_on_amount_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_payment_applications_on_amount_due ON public.supplier_payment_applications USING btree (amount_due_id);


--
-- Name: index_supplier_payment_applications_on_payment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_payment_applications_on_payment ON public.supplier_payment_applications USING btree (supplier_payment_id);


--
-- Name: index_supplier_payment_reversals_one_per_payment; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_payment_reversals_one_per_payment ON public.supplier_payment_reversals USING btree (supplier_payment_id);


--
-- Name: index_supplier_payments_on_agency_and_reference; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_payments_on_agency_and_reference ON public.supplier_payments USING btree (agency_id, payment_reference);


--
-- Name: index_supplier_payments_on_departure_and_supplier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_payments_on_departure_and_supplier ON public.supplier_payments USING btree (departure_id, supplier_id, paid_on);


--
-- Name: index_supplier_payments_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_payments_on_id_and_agency_id ON public.supplier_payments USING btree (id, agency_id);


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
-- Name: index_supplier_rate_bands_on_arrangement_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_rate_bands_on_arrangement_and_position ON public.supplier_rate_bands USING btree (supplier_arrangement_id, "position");


--
-- Name: index_supplier_rate_bands_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_rate_bands_on_id_and_agency_id ON public.supplier_rate_bands USING btree (id, agency_id);


--
-- Name: index_supplier_rate_lines_on_arrangement; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_rate_lines_on_arrangement ON public.supplier_rate_lines USING btree (supplier_arrangement_id);


--
-- Name: index_supplier_rate_lines_on_band; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_rate_lines_on_band ON public.supplier_rate_lines USING btree (supplier_rate_band_id);


--
-- Name: index_supplier_rate_lines_one_per_group_position_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_rate_lines_one_per_group_position_type ON public.supplier_rate_lines USING btree (inventory_group_id, occupancy_position, traveler_type_id) NULLS NOT DISTINCT;


--
-- Name: index_supplier_reservation_events_on_reservation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_reservation_events_on_reservation ON public.supplier_reservation_events USING btree (supplier_reservation_id, recorded_at);


--
-- Name: index_supplier_reservation_units_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_reservation_units_on_id_and_agency_id ON public.supplier_reservation_units USING btree (id, agency_id);


--
-- Name: index_supplier_reservation_units_once_per_reservation; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_reservation_units_once_per_reservation ON public.supplier_reservation_units USING btree (supplier_reservation_id, choice_selection_id);


--
-- Name: index_supplier_reservation_units_one_open_per_selection; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_reservation_units_one_open_per_selection ON public.supplier_reservation_units USING btree (choice_selection_id) WHERE open;


--
-- Name: index_supplier_reservations_on_arrangement; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_reservations_on_arrangement ON public.supplier_reservations USING btree (supplier_arrangement_id, requested_at);


--
-- Name: index_supplier_reservations_on_booking; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_supplier_reservations_on_booking ON public.supplier_reservations USING btree (client_booking_id, requested_at);


--
-- Name: index_supplier_reservations_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_supplier_reservations_on_id_and_agency_id ON public.supplier_reservations USING btree (id, agency_id);


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
-- Name: index_tasks_on_departure_and_due_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_departure_and_due_at ON public.tasks USING btree (departure_id, due_at);


--
-- Name: index_tasks_on_owner_status_and_due_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_owner_status_and_due_at ON public.tasks USING btree (owner_id, status, due_at);


--
-- Name: index_tasks_one_per_amount_due; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tasks_one_per_amount_due ON public.tasks USING btree (amount_due_id);


--
-- Name: index_tasks_one_per_schedule_line; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tasks_one_per_schedule_line ON public.tasks USING btree (schedule_line_id);


--
-- Name: index_tasks_one_per_supplier_deadline; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tasks_one_per_supplier_deadline ON public.tasks USING btree (supplier_deadline_id);


--
-- Name: index_traveler_links_on_traveler; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_links_on_traveler ON public.traveler_links USING btree (traveler_id);


--
-- Name: index_traveler_links_one_per_client_and_traveler; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_traveler_links_one_per_client_and_traveler ON public.traveler_links USING btree (client_id, traveler_id);


--
-- Name: index_traveler_links_one_self_per_client; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_traveler_links_one_self_per_client ON public.traveler_links USING btree (client_id) WHERE ((relationship)::text = 'self'::text);


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
-- Name: index_travelers_on_agency_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_travelers_on_agency_and_name ON public.travelers USING btree (agency_id, surname, given_names);


--
-- Name: index_travelers_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_travelers_on_id_and_agency_id ON public.travelers USING btree (id, agency_id);


--
-- Name: index_trigger_event_shells_on_shell; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_trigger_event_shells_on_shell ON public.trigger_event_shells USING btree (unit_shell_id);


--
-- Name: index_trigger_event_shells_one_per_shell; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_trigger_event_shells_one_per_shell ON public.trigger_event_shells USING btree (trigger_event_id, unit_shell_id);


--
-- Name: index_trigger_events_on_arrangement_type_and_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_trigger_events_on_arrangement_type_and_date ON public.trigger_events USING btree (supplier_arrangement_id, event_type, occurred_on);


--
-- Name: index_trigger_events_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_trigger_events_on_id_and_agency_id ON public.trigger_events USING btree (id, agency_id);


--
-- Name: index_unit_shells_on_group_and_label; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_unit_shells_on_group_and_label ON public.unit_shells USING btree (inventory_group_id, label);


--
-- Name: index_unit_shells_on_id_and_agency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_unit_shells_on_id_and_agency_id ON public.unit_shells USING btree (id, agency_id);


--
-- Name: index_unit_shells_on_id_and_group; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_unit_shells_on_id_and_group ON public.unit_shells USING btree (id, inventory_group_id);


--
-- Name: index_user_permissions_on_agency_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_permissions_on_agency_user_id ON public.user_permissions USING btree (agency_user_id);


--
-- Name: index_user_permissions_on_agency_user_permission; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_permissions_on_agency_user_permission ON public.user_permissions USING btree (agency_id, agency_user_id, permission);


--
-- Name: active_storage_attachments active_storage_attachments_keep_documents; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER active_storage_attachments_keep_documents BEFORE DELETE OR UPDATE ON public.active_storage_attachments FOR EACH ROW EXECUTE FUNCTION public.reject_document_attachment_change();


--
-- Name: agencies agencies_reject_workspace_code_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER agencies_reject_workspace_code_change BEFORE UPDATE ON public.agencies FOR EACH ROW EXECUTE FUNCTION public.reject_agency_workspace_code_change();


--
-- Name: agency_users agency_users_reject_agency_id_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER agency_users_reject_agency_id_change BEFORE UPDATE ON public.agency_users FOR EACH ROW EXECUTE FUNCTION public.reject_agency_user_agency_change();


--
-- Name: amounts_due amounts_due_reject_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER amounts_due_reject_mutation BEFORE DELETE OR UPDATE ON public.amounts_due FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_money_mutation();


--
-- Name: audit_events audit_events_reject_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_events_reject_update BEFORE DELETE OR UPDATE ON public.audit_events FOR EACH ROW EXECUTE FUNCTION public.reject_audit_event_mutation();


--
-- Name: booking_acceptances booking_acceptances_reject_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER booking_acceptances_reject_mutation BEFORE DELETE OR UPDATE ON public.booking_acceptances FOR EACH ROW EXECUTE FUNCTION public.reject_booking_acceptance_mutation();


--
-- Name: booking_price_lines booking_price_lines_reject_confirmed_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER booking_price_lines_reject_confirmed_change BEFORE INSERT OR DELETE OR UPDATE ON public.booking_price_lines FOR EACH ROW EXECUTE FUNCTION public.reject_confirmed_booking_contents_change();


--
-- Name: capacity_events capacity_events_reject_invalid_zone; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_events_reject_invalid_zone BEFORE INSERT ON public.capacity_events FOR EACH ROW EXECUTE FUNCTION public.reject_invalid_capacity_event_zone();


--
-- Name: capacity_events capacity_events_reject_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_events_reject_mutation BEFORE DELETE OR UPDATE ON public.capacity_events FOR EACH ROW EXECUTE FUNCTION public.reject_capacity_event_mutation();


--
-- Name: capacity_events capacity_events_reject_nonnumeric; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_events_reject_nonnumeric BEFORE INSERT ON public.capacity_events FOR EACH ROW EXECUTE FUNCTION public.reject_nonnumeric_capacity_record();


--
-- Name: capacity_pools capacity_pools_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_pools_reject_owner_change BEFORE UPDATE ON public.capacity_pools FOR EACH ROW EXECUTE FUNCTION public.reject_capacity_owner_change();


--
-- Name: capacity_projections capacity_projections_reject_nonnumeric; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_projections_reject_nonnumeric BEFORE INSERT ON public.capacity_projections FOR EACH ROW EXECUTE FUNCTION public.reject_nonnumeric_capacity_record();


--
-- Name: capacity_projections capacity_projections_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER capacity_projections_reject_owner_change BEFORE UPDATE ON public.capacity_projections FOR EACH ROW EXECUTE FUNCTION public.reject_capacity_owner_change();


--
-- Name: charge_lines charge_lines_reject_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER charge_lines_reject_mutation BEFORE DELETE OR UPDATE ON public.charge_lines FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_money_mutation();


--
-- Name: choice_selections choice_selections_reject_other_offering; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER choice_selections_reject_other_offering BEFORE INSERT OR UPDATE ON public.choice_selections FOR EACH ROW EXECUTE FUNCTION public.reject_choice_selection_other_offering();


--
-- Name: client_bookings client_bookings_reject_identity_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_bookings_reject_identity_change BEFORE UPDATE ON public.client_bookings FOR EACH ROW EXECUTE FUNCTION public.reject_client_booking_identity_change();


--
-- Name: client_bookings client_bookings_reject_other_departure; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_bookings_reject_other_departure BEFORE INSERT ON public.client_bookings FOR EACH ROW EXECUTE FUNCTION public.reject_client_booking_other_departure();


--
-- Name: client_cancellation_tiers client_cancellation_tiers_reject_locked_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_cancellation_tiers_reject_locked_change BEFORE INSERT OR DELETE OR UPDATE ON public.client_cancellation_tiers FOR EACH ROW EXECUTE FUNCTION public.reject_locked_client_terms_change();


--
-- Name: client_charges client_charges_reject_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_charges_reject_mutation BEFORE DELETE OR UPDATE ON public.client_charges FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_money_mutation();


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
-- Name: client_payment_applications client_payment_applications_reject_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_payment_applications_reject_mutation BEFORE DELETE OR UPDATE ON public.client_payment_applications FOR EACH ROW EXECUTE FUNCTION public.reject_client_money_mutation();


--
-- Name: client_payment_reversals client_payment_reversals_reject_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_payment_reversals_reject_mutation BEFORE DELETE OR UPDATE ON public.client_payment_reversals FOR EACH ROW EXECUTE FUNCTION public.reject_client_money_mutation();


--
-- Name: client_payment_schedule_lines client_payment_schedule_lines_reject_locked_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_payment_schedule_lines_reject_locked_change BEFORE INSERT OR DELETE OR UPDATE ON public.client_payment_schedule_lines FOR EACH ROW EXECUTE FUNCTION public.reject_locked_client_terms_change();


--
-- Name: client_payments client_payments_reject_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_payments_reject_mutation BEFORE DELETE OR UPDATE ON public.client_payments FOR EACH ROW EXECUTE FUNCTION public.reject_client_money_mutation();


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
-- Name: client_terms_versions client_terms_versions_reject_locked_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_terms_versions_reject_locked_change BEFORE DELETE OR UPDATE ON public.client_terms_versions FOR EACH ROW EXECUTE FUNCTION public.reject_locked_client_terms_change();


--
-- Name: client_trips client_trips_reject_identity_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER client_trips_reject_identity_change BEFORE UPDATE ON public.client_trips FOR EACH ROW EXECUTE FUNCTION public.reject_client_trip_identity_change();


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
-- Name: document_deliveries document_deliveries_reject_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER document_deliveries_reject_mutation BEFORE DELETE OR UPDATE ON public.document_deliveries FOR EACH ROW EXECUTE FUNCTION public.reject_document_delivery_mutation();


--
-- Name: document_versions document_versions_reject_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER document_versions_reject_mutation BEFORE DELETE OR UPDATE ON public.document_versions FOR EACH ROW EXECUTE FUNCTION public.reject_document_version_mutation();


--
-- Name: installments installments_reject_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER installments_reject_mutation BEFORE DELETE OR UPDATE ON public.installments FOR EACH ROW EXECUTE FUNCTION public.reject_client_money_mutation();


--
-- Name: inventory_allocations inventory_allocations_check; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER inventory_allocations_check BEFORE INSERT OR DELETE OR UPDATE ON public.inventory_allocations FOR EACH ROW EXECUTE FUNCTION public.check_inventory_allocation();


--
-- Name: offering_options offering_options_reject_other_departure; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER offering_options_reject_other_departure BEFORE INSERT OR UPDATE ON public.offering_options FOR EACH ROW EXECUTE FUNCTION public.reject_offering_option_other_departure();


--
-- Name: offering_publications offering_publications_reject_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER offering_publications_reject_mutation BEFORE DELETE OR UPDATE ON public.offering_publications FOR EACH ROW EXECUTE FUNCTION public.reject_offering_publication_mutation();


--
-- Name: offices offices_reject_identity_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER offices_reject_identity_change BEFORE UPDATE ON public.offices FOR EACH ROW EXECUTE FUNCTION public.reject_office_identity_change();


--
-- Name: receipts receipts_reject_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER receipts_reject_mutation BEFORE DELETE OR UPDATE ON public.receipts FOR EACH ROW EXECUTE FUNCTION public.reject_client_money_mutation();


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
-- Name: supplier_payment_applications supplier_payment_applications_reject_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_payment_applications_reject_mutation BEFORE DELETE OR UPDATE ON public.supplier_payment_applications FOR EACH ROW EXECUTE FUNCTION public.reject_client_money_mutation();


--
-- Name: supplier_payment_reversals supplier_payment_reversals_reject_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_payment_reversals_reject_mutation BEFORE DELETE OR UPDATE ON public.supplier_payment_reversals FOR EACH ROW EXECUTE FUNCTION public.reject_client_money_mutation();


--
-- Name: supplier_payments supplier_payments_reject_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_payments_reject_mutation BEFORE DELETE OR UPDATE ON public.supplier_payments FOR EACH ROW EXECUTE FUNCTION public.reject_client_money_mutation();


--
-- Name: supplier_phone_numbers supplier_phone_numbers_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_phone_numbers_reject_owner_change BEFORE UPDATE ON public.supplier_phone_numbers FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_contact_owner_change();


--
-- Name: supplier_postal_addresses supplier_postal_addresses_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_postal_addresses_reject_owner_change BEFORE UPDATE ON public.supplier_postal_addresses FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_contact_owner_change();


--
-- Name: supplier_rate_bands supplier_rate_bands_reject_frozen_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_rate_bands_reject_frozen_change BEFORE INSERT OR DELETE OR UPDATE ON public.supplier_rate_bands FOR EACH ROW EXECUTE FUNCTION public.reject_frozen_supplier_rate_band_change();


--
-- Name: supplier_rate_lines supplier_rate_lines_reject_frozen_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_rate_lines_reject_frozen_change BEFORE INSERT OR DELETE OR UPDATE ON public.supplier_rate_lines FOR EACH ROW EXECUTE FUNCTION public.reject_frozen_supplier_rate_line_change();


--
-- Name: supplier_reservation_events supplier_reservation_events_reject_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_reservation_events_reject_mutation BEFORE DELETE OR UPDATE ON public.supplier_reservation_events FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_reservation_event_mutation();


--
-- Name: supplier_websites supplier_websites_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER supplier_websites_reject_owner_change BEFORE UPDATE ON public.supplier_websites FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_contact_owner_change();


--
-- Name: suppliers suppliers_reject_identity_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER suppliers_reject_identity_change BEFORE UPDATE ON public.suppliers FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_identity_change();


--
-- Name: traveler_links traveler_links_reject_self_organization; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER traveler_links_reject_self_organization BEFORE INSERT OR UPDATE ON public.traveler_links FOR EACH ROW EXECUTE FUNCTION public.reject_self_link_to_organization();


--
-- Name: travelers travelers_reject_agency_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER travelers_reject_agency_change BEFORE UPDATE ON public.travelers FOR EACH ROW EXECUTE FUNCTION public.reject_directory_agency_change();


--
-- Name: trigger_event_shells trigger_event_shells_reject_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_event_shells_reject_mutation BEFORE DELETE OR UPDATE ON public.trigger_event_shells FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_money_mutation();


--
-- Name: trigger_events trigger_events_reject_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_events_reject_mutation BEFORE DELETE OR UPDATE ON public.trigger_events FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_money_mutation();


--
-- Name: unit_shells unit_shells_reject_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER unit_shells_reject_owner_change BEFORE UPDATE ON public.unit_shells FOR EACH ROW EXECUTE FUNCTION public.reject_capacity_owner_change();


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
-- Name: agency_cancellation_tiers fk_agency_cancellation_tiers_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agency_cancellation_tiers
    ADD CONSTRAINT fk_agency_cancellation_tiers_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: agency_users fk_agency_users_reseller_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agency_users
    ADD CONSTRAINT fk_agency_users_reseller_same_agency FOREIGN KEY (reseller_id, agency_id) REFERENCES public.resellers(id, agency_id);


--
-- Name: amounts_due fk_amounts_due_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.amounts_due
    ADD CONSTRAINT fk_amounts_due_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: amounts_due fk_amounts_due_arrangement_currency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.amounts_due
    ADD CONSTRAINT fk_amounts_due_arrangement_currency FOREIGN KEY (supplier_arrangement_id, currency) REFERENCES public.supplier_arrangements(id, currency);


--
-- Name: amounts_due fk_amounts_due_arrangement_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.amounts_due
    ADD CONSTRAINT fk_amounts_due_arrangement_same_agency FOREIGN KEY (supplier_arrangement_id, agency_id) REFERENCES public.supplier_arrangements(id, agency_id);


--
-- Name: amounts_due fk_amounts_due_event_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.amounts_due
    ADD CONSTRAINT fk_amounts_due_event_same_agency FOREIGN KEY (trigger_event_id, agency_id) REFERENCES public.trigger_events(id, agency_id);


--
-- Name: amounts_due fk_amounts_due_poster_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.amounts_due
    ADD CONSTRAINT fk_amounts_due_poster_same_agency FOREIGN KEY (posted_by_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: amounts_due fk_amounts_due_schedule_line_of_arrangement; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.amounts_due
    ADD CONSTRAINT fk_amounts_due_schedule_line_of_arrangement FOREIGN KEY (schedule_line_id, supplier_arrangement_id) REFERENCES public.schedule_lines(id, supplier_arrangement_id);


--
-- Name: amounts_due fk_amounts_due_shell_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.amounts_due
    ADD CONSTRAINT fk_amounts_due_shell_same_agency FOREIGN KEY (unit_shell_id, agency_id) REFERENCES public.unit_shells(id, agency_id);


--
-- Name: arrangement_documents fk_arrangement_documents_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arrangement_documents
    ADD CONSTRAINT fk_arrangement_documents_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: arrangement_documents fk_arrangement_documents_arrangement_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arrangement_documents
    ADD CONSTRAINT fk_arrangement_documents_arrangement_same_agency FOREIGN KEY (supplier_arrangement_id, agency_id) REFERENCES public.supplier_arrangements(id, agency_id);


--
-- Name: arrangement_documents fk_arrangement_documents_uploader_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arrangement_documents
    ADD CONSTRAINT fk_arrangement_documents_uploader_same_agency FOREIGN KEY (uploaded_by_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: booking_acceptances fk_booking_acceptances_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_acceptances
    ADD CONSTRAINT fk_booking_acceptances_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: booking_acceptances fk_booking_acceptances_booking_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_acceptances
    ADD CONSTRAINT fk_booking_acceptances_booking_same_agency FOREIGN KEY (client_booking_id, agency_id) REFERENCES public.client_bookings(id, agency_id);


--
-- Name: booking_acceptances fk_booking_acceptances_payment_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_acceptances
    ADD CONSTRAINT fk_booking_acceptances_payment_same_agency FOREIGN KEY (client_payment_id, agency_id) REFERENCES public.client_payments(id, agency_id);


--
-- Name: booking_acceptances fk_booking_acceptances_recorder_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_acceptances
    ADD CONSTRAINT fk_booking_acceptances_recorder_same_agency FOREIGN KEY (recorded_by_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: booking_acceptances fk_booking_acceptances_terms_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_acceptances
    ADD CONSTRAINT fk_booking_acceptances_terms_same_agency FOREIGN KEY (client_terms_version_id, agency_id) REFERENCES public.client_terms_versions(id, agency_id);


--
-- Name: booking_price_lines fk_booking_price_lines_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_price_lines
    ADD CONSTRAINT fk_booking_price_lines_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: booking_price_lines fk_booking_price_lines_booking_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_price_lines
    ADD CONSTRAINT fk_booking_price_lines_booking_same_agency FOREIGN KEY (client_booking_id, agency_id) REFERENCES public.client_bookings(id, agency_id);


--
-- Name: booking_price_lines fk_booking_price_lines_offering_price; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_price_lines
    ADD CONSTRAINT fk_booking_price_lines_offering_price FOREIGN KEY (offering_price_id) REFERENCES public.offering_prices(id) ON DELETE SET NULL;


--
-- Name: booking_price_lines fk_booking_price_lines_selection_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_price_lines
    ADD CONSTRAINT fk_booking_price_lines_selection_same_agency FOREIGN KEY (choice_selection_id, agency_id) REFERENCES public.choice_selections(id, agency_id);


--
-- Name: booking_price_lines fk_booking_price_lines_traveler_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_price_lines
    ADD CONSTRAINT fk_booking_price_lines_traveler_same_agency FOREIGN KEY (booking_traveler_id, agency_id) REFERENCES public.booking_travelers(id, agency_id);


--
-- Name: booking_price_lines fk_booking_price_lines_type_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_price_lines
    ADD CONSTRAINT fk_booking_price_lines_type_same_agency FOREIGN KEY (traveler_type_id, agency_id) REFERENCES public.traveler_types(id, agency_id);


--
-- Name: booking_travelers fk_booking_travelers_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_travelers
    ADD CONSTRAINT fk_booking_travelers_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: booking_travelers fk_booking_travelers_booking_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_travelers
    ADD CONSTRAINT fk_booking_travelers_booking_same_agency FOREIGN KEY (client_booking_id, agency_id) REFERENCES public.client_bookings(id, agency_id);


--
-- Name: booking_travelers fk_booking_travelers_traveler_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_travelers
    ADD CONSTRAINT fk_booking_travelers_traveler_same_agency FOREIGN KEY (traveler_id, agency_id) REFERENCES public.travelers(id, agency_id);


--
-- Name: booking_travelers fk_booking_travelers_type_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_travelers
    ADD CONSTRAINT fk_booking_travelers_type_same_agency FOREIGN KEY (traveler_type_id, agency_id) REFERENCES public.traveler_types(id, agency_id);


--
-- Name: capacity_events fk_capacity_events_actor_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_events
    ADD CONSTRAINT fk_capacity_events_actor_same_agency FOREIGN KEY (actor_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: capacity_events fk_capacity_events_arrangement_same_departure; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_events
    ADD CONSTRAINT fk_capacity_events_arrangement_same_departure FOREIGN KEY (supplier_arrangement_id, departure_id) REFERENCES public.supplier_arrangements(id, departure_id);


--
-- Name: capacity_events fk_capacity_events_corrects; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_events
    ADD CONSTRAINT fk_capacity_events_corrects FOREIGN KEY (corrects_event_id) REFERENCES public.capacity_events(id);


--
-- Name: capacity_events fk_capacity_events_departure_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_events
    ADD CONSTRAINT fk_capacity_events_departure_same_agency FOREIGN KEY (departure_id, agency_id) REFERENCES public.departures(id, agency_id);


--
-- Name: capacity_events fk_capacity_events_group_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_events
    ADD CONSTRAINT fk_capacity_events_group_same_agency FOREIGN KEY (inventory_group_id, agency_id) REFERENCES public.inventory_groups(id, agency_id);


--
-- Name: capacity_events fk_capacity_events_pool_of_group; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_events
    ADD CONSTRAINT fk_capacity_events_pool_of_group FOREIGN KEY (capacity_pool_id, inventory_group_id) REFERENCES public.capacity_pools(id, inventory_group_id);


--
-- Name: capacity_events fk_capacity_events_shell_of_group; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_events
    ADD CONSTRAINT fk_capacity_events_shell_of_group FOREIGN KEY (unit_shell_id, inventory_group_id) REFERENCES public.unit_shells(id, inventory_group_id);


--
-- Name: capacity_pools fk_capacity_pools_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pools
    ADD CONSTRAINT fk_capacity_pools_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: capacity_pools fk_capacity_pools_group_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_pools
    ADD CONSTRAINT fk_capacity_pools_group_same_agency FOREIGN KEY (inventory_group_id, agency_id) REFERENCES public.inventory_groups(id, agency_id);


--
-- Name: capacity_projections fk_capacity_projections_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_projections
    ADD CONSTRAINT fk_capacity_projections_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: capacity_projections fk_capacity_projections_group_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_projections
    ADD CONSTRAINT fk_capacity_projections_group_same_agency FOREIGN KEY (inventory_group_id, agency_id) REFERENCES public.inventory_groups(id, agency_id);


--
-- Name: capacity_projections fk_capacity_projections_last_event; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_projections
    ADD CONSTRAINT fk_capacity_projections_last_event FOREIGN KEY (last_event_id) REFERENCES public.capacity_events(id);


--
-- Name: capacity_projections fk_capacity_projections_next_event; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_projections
    ADD CONSTRAINT fk_capacity_projections_next_event FOREIGN KEY (next_event_id) REFERENCES public.capacity_events(id);


--
-- Name: capacity_rules fk_capacity_rules_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_rules
    ADD CONSTRAINT fk_capacity_rules_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: capacity_rules fk_capacity_rules_group_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_rules
    ADD CONSTRAINT fk_capacity_rules_group_same_agency FOREIGN KEY (inventory_group_id, agency_id) REFERENCES public.inventory_groups(id, agency_id);


--
-- Name: capacity_rules fk_capacity_rules_traveler_type_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capacity_rules
    ADD CONSTRAINT fk_capacity_rules_traveler_type_same_agency FOREIGN KEY (traveler_type_id, agency_id) REFERENCES public.traveler_types(id, agency_id);


--
-- Name: charge_lines fk_charge_lines_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge_lines
    ADD CONSTRAINT fk_charge_lines_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: charge_lines fk_charge_lines_charge_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge_lines
    ADD CONSTRAINT fk_charge_lines_charge_same_agency FOREIGN KEY (client_charge_id, agency_id) REFERENCES public.client_charges(id, agency_id);


--
-- Name: charge_lines fk_charge_lines_selection_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge_lines
    ADD CONSTRAINT fk_charge_lines_selection_same_agency FOREIGN KEY (choice_selection_id, agency_id) REFERENCES public.choice_selections(id, agency_id);


--
-- Name: charge_lines fk_charge_lines_traveler_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge_lines
    ADD CONSTRAINT fk_charge_lines_traveler_same_agency FOREIGN KEY (booking_traveler_id, agency_id) REFERENCES public.booking_travelers(id, agency_id);


--
-- Name: charge_lines fk_charge_lines_type_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge_lines
    ADD CONSTRAINT fk_charge_lines_type_same_agency FOREIGN KEY (traveler_type_id, agency_id) REFERENCES public.traveler_types(id, agency_id);


--
-- Name: choice_selections fk_choice_selections_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.choice_selections
    ADD CONSTRAINT fk_choice_selections_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: choice_selections fk_choice_selections_booking_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.choice_selections
    ADD CONSTRAINT fk_choice_selections_booking_same_agency FOREIGN KEY (client_booking_id, agency_id) REFERENCES public.client_bookings(id, agency_id);


--
-- Name: choice_selections fk_choice_selections_option_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.choice_selections
    ADD CONSTRAINT fk_choice_selections_option_same_agency FOREIGN KEY (offering_option_id, agency_id) REFERENCES public.offering_options(id, agency_id);


--
-- Name: client_bookings fk_client_bookings_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_bookings
    ADD CONSTRAINT fk_client_bookings_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: client_bookings fk_client_bookings_creator_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_bookings
    ADD CONSTRAINT fk_client_bookings_creator_same_agency FOREIGN KEY (created_by_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: client_bookings fk_client_bookings_offering_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_bookings
    ADD CONSTRAINT fk_client_bookings_offering_same_agency FOREIGN KEY (offering_id, agency_id) REFERENCES public.offerings(id, agency_id);


--
-- Name: client_bookings fk_client_bookings_owner_reseller_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_bookings
    ADD CONSTRAINT fk_client_bookings_owner_reseller_same_agency FOREIGN KEY (owner_reseller_id, agency_id) REFERENCES public.resellers(id, agency_id);


--
-- Name: client_bookings fk_client_bookings_seller_reseller_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_bookings
    ADD CONSTRAINT fk_client_bookings_seller_reseller_same_agency FOREIGN KEY (seller_reseller_id, agency_id) REFERENCES public.resellers(id, agency_id);


--
-- Name: client_bookings fk_client_bookings_terms_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_bookings
    ADD CONSTRAINT fk_client_bookings_terms_same_agency FOREIGN KEY (client_terms_version_id, agency_id) REFERENCES public.client_terms_versions(id, agency_id);


--
-- Name: client_bookings fk_client_bookings_trip_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_bookings
    ADD CONSTRAINT fk_client_bookings_trip_same_agency FOREIGN KEY (client_trip_id, agency_id) REFERENCES public.client_trips(id, agency_id);


--
-- Name: client_cancellation_tiers fk_client_cancellation_tiers_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_cancellation_tiers
    ADD CONSTRAINT fk_client_cancellation_tiers_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: client_cancellation_tiers fk_client_cancellation_tiers_version_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_cancellation_tiers
    ADD CONSTRAINT fk_client_cancellation_tiers_version_same_agency FOREIGN KEY (client_terms_version_id, agency_id) REFERENCES public.client_terms_versions(id, agency_id);


--
-- Name: client_charges fk_client_charges_acceptance_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_charges
    ADD CONSTRAINT fk_client_charges_acceptance_same_agency FOREIGN KEY (booking_acceptance_id, agency_id) REFERENCES public.booking_acceptances(id, agency_id);


--
-- Name: client_charges fk_client_charges_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_charges
    ADD CONSTRAINT fk_client_charges_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: client_charges fk_client_charges_booking_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_charges
    ADD CONSTRAINT fk_client_charges_booking_same_agency FOREIGN KEY (client_booking_id, agency_id) REFERENCES public.client_bookings(id, agency_id);


--
-- Name: client_charges fk_client_charges_terms_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_charges
    ADD CONSTRAINT fk_client_charges_terms_same_agency FOREIGN KEY (client_terms_version_id, agency_id) REFERENCES public.client_terms_versions(id, agency_id);


--
-- Name: client_payment_applications fk_client_payment_applications_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_payment_applications
    ADD CONSTRAINT fk_client_payment_applications_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: client_payment_applications fk_client_payment_applications_installment_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_payment_applications
    ADD CONSTRAINT fk_client_payment_applications_installment_same_agency FOREIGN KEY (installment_id, agency_id) REFERENCES public.installments(id, agency_id);


--
-- Name: client_payment_applications fk_client_payment_applications_payment_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_payment_applications
    ADD CONSTRAINT fk_client_payment_applications_payment_same_agency FOREIGN KEY (client_payment_id, agency_id) REFERENCES public.client_payments(id, agency_id);


--
-- Name: client_payment_applications fk_client_payment_applications_recorder_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_payment_applications
    ADD CONSTRAINT fk_client_payment_applications_recorder_same_agency FOREIGN KEY (recorded_by_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: client_payment_reversals fk_client_payment_reversals_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_payment_reversals
    ADD CONSTRAINT fk_client_payment_reversals_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: client_payment_reversals fk_client_payment_reversals_payment_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_payment_reversals
    ADD CONSTRAINT fk_client_payment_reversals_payment_same_agency FOREIGN KEY (client_payment_id, agency_id) REFERENCES public.client_payments(id, agency_id);


--
-- Name: client_payment_reversals fk_client_payment_reversals_recorder_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_payment_reversals
    ADD CONSTRAINT fk_client_payment_reversals_recorder_same_agency FOREIGN KEY (recorded_by_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: client_payment_schedule_lines fk_client_payment_schedule_lines_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_payment_schedule_lines
    ADD CONSTRAINT fk_client_payment_schedule_lines_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: client_payment_schedule_lines fk_client_payment_schedule_lines_version_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_payment_schedule_lines
    ADD CONSTRAINT fk_client_payment_schedule_lines_version_same_agency FOREIGN KEY (client_terms_version_id, agency_id) REFERENCES public.client_terms_versions(id, agency_id);


--
-- Name: client_payments fk_client_payments_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_payments
    ADD CONSTRAINT fk_client_payments_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: client_payments fk_client_payments_payer_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_payments
    ADD CONSTRAINT fk_client_payments_payer_same_agency FOREIGN KEY (payer_client_id, agency_id) REFERENCES public.clients(id, agency_id);


--
-- Name: client_payments fk_client_payments_recorder_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_payments
    ADD CONSTRAINT fk_client_payments_recorder_same_agency FOREIGN KEY (recorded_by_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: client_payments fk_client_payments_supplier_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_payments
    ADD CONSTRAINT fk_client_payments_supplier_same_agency FOREIGN KEY (supplier_id, agency_id) REFERENCES public.suppliers(id, agency_id);


--
-- Name: client_payments fk_client_payments_trip_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_payments
    ADD CONSTRAINT fk_client_payments_trip_same_agency FOREIGN KEY (client_trip_id, agency_id) REFERENCES public.client_trips(id, agency_id);


--
-- Name: client_terms_versions fk_client_terms_versions_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_terms_versions
    ADD CONSTRAINT fk_client_terms_versions_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: client_terms_versions fk_client_terms_versions_copied_from_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_terms_versions
    ADD CONSTRAINT fk_client_terms_versions_copied_from_same_agency FOREIGN KEY (copied_from_departure_id, agency_id) REFERENCES public.departures(id, agency_id);


--
-- Name: client_terms_versions fk_client_terms_versions_departure_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_terms_versions
    ADD CONSTRAINT fk_client_terms_versions_departure_same_agency FOREIGN KEY (departure_id, agency_id) REFERENCES public.departures(id, agency_id);


--
-- Name: client_trips fk_client_trips_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_trips
    ADD CONSTRAINT fk_client_trips_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: client_trips fk_client_trips_client_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_trips
    ADD CONSTRAINT fk_client_trips_client_same_agency FOREIGN KEY (client_id, agency_id) REFERENCES public.clients(id, agency_id);


--
-- Name: client_trips fk_client_trips_departure_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_trips
    ADD CONSTRAINT fk_client_trips_departure_same_agency FOREIGN KEY (departure_id, agency_id) REFERENCES public.departures(id, agency_id);


--
-- Name: clients fk_clients_creator_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT fk_clients_creator_same_agency FOREIGN KEY (created_by_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: cost_line_shells fk_cost_line_shells_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_line_shells
    ADD CONSTRAINT fk_cost_line_shells_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: cost_line_shells fk_cost_line_shells_line_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_line_shells
    ADD CONSTRAINT fk_cost_line_shells_line_same_agency FOREIGN KEY (cost_line_id, agency_id) REFERENCES public.cost_lines(id, agency_id);


--
-- Name: cost_line_shells fk_cost_line_shells_shell_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_line_shells
    ADD CONSTRAINT fk_cost_line_shells_shell_same_agency FOREIGN KEY (unit_shell_id, agency_id) REFERENCES public.unit_shells(id, agency_id);


--
-- Name: cost_lines fk_cost_lines_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_lines
    ADD CONSTRAINT fk_cost_lines_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: cost_lines fk_cost_lines_arrangement_currency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_lines
    ADD CONSTRAINT fk_cost_lines_arrangement_currency FOREIGN KEY (supplier_arrangement_id, currency) REFERENCES public.supplier_arrangements(id, currency);


--
-- Name: cost_lines fk_cost_lines_arrangement_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_lines
    ADD CONSTRAINT fk_cost_lines_arrangement_same_agency FOREIGN KEY (supplier_arrangement_id, agency_id) REFERENCES public.supplier_arrangements(id, agency_id);


--
-- Name: cost_lines fk_cost_lines_base_of_arrangement; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_lines
    ADD CONSTRAINT fk_cost_lines_base_of_arrangement FOREIGN KEY (base_cost_line_id, supplier_arrangement_id) REFERENCES public.cost_lines(id, supplier_arrangement_id);


--
-- Name: cost_lines fk_cost_lines_booking_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_lines
    ADD CONSTRAINT fk_cost_lines_booking_same_agency FOREIGN KEY (client_booking_id, agency_id) REFERENCES public.client_bookings(id, agency_id);


--
-- Name: cost_lines fk_cost_lines_group_of_arrangement; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_lines
    ADD CONSTRAINT fk_cost_lines_group_of_arrangement FOREIGN KEY (inventory_group_id, supplier_arrangement_id) REFERENCES public.inventory_groups(id, supplier_arrangement_id);


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
-- Name: document_deliveries fk_document_deliveries_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_deliveries
    ADD CONSTRAINT fk_document_deliveries_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: document_deliveries fk_document_deliveries_recorder_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_deliveries
    ADD CONSTRAINT fk_document_deliveries_recorder_same_agency FOREIGN KEY (recorded_by_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: document_deliveries fk_document_deliveries_version_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_deliveries
    ADD CONSTRAINT fk_document_deliveries_version_same_agency FOREIGN KEY (document_version_id, agency_id) REFERENCES public.document_versions(id, agency_id);


--
-- Name: document_versions fk_document_versions_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_versions
    ADD CONSTRAINT fk_document_versions_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: document_versions fk_document_versions_booking_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_versions
    ADD CONSTRAINT fk_document_versions_booking_same_agency FOREIGN KEY (client_booking_id, agency_id) REFERENCES public.client_bookings(id, agency_id);


--
-- Name: document_versions fk_document_versions_issuer_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_versions
    ADD CONSTRAINT fk_document_versions_issuer_same_agency FOREIGN KEY (issued_by_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: document_versions fk_document_versions_receipt_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_versions
    ADD CONSTRAINT fk_document_versions_receipt_same_agency FOREIGN KEY (receipt_id, agency_id) REFERENCES public.receipts(id, agency_id);


--
-- Name: document_versions fk_document_versions_supersedes_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_versions
    ADD CONSTRAINT fk_document_versions_supersedes_same_agency FOREIGN KEY (supersedes_id, agency_id) REFERENCES public.document_versions(id, agency_id);


--
-- Name: expected_commissions fk_expected_commissions_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expected_commissions
    ADD CONSTRAINT fk_expected_commissions_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: expected_commissions fk_expected_commissions_arrangement_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expected_commissions
    ADD CONSTRAINT fk_expected_commissions_arrangement_same_agency FOREIGN KEY (supplier_arrangement_id, agency_id) REFERENCES public.supplier_arrangements(id, agency_id);


--
-- Name: expected_commissions fk_expected_commissions_booking_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expected_commissions
    ADD CONSTRAINT fk_expected_commissions_booking_same_agency FOREIGN KEY (client_booking_id, agency_id) REFERENCES public.client_bookings(id, agency_id);


--
-- Name: expected_commissions fk_expected_commissions_confirmer_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expected_commissions
    ADD CONSTRAINT fk_expected_commissions_confirmer_same_agency FOREIGN KEY (confirmed_by_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: expected_commissions fk_expected_commissions_overrider_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expected_commissions
    ADD CONSTRAINT fk_expected_commissions_overrider_same_agency FOREIGN KEY (overridden_by_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: expected_commissions fk_expected_commissions_selection_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expected_commissions
    ADD CONSTRAINT fk_expected_commissions_selection_same_agency FOREIGN KEY (choice_selection_id, agency_id) REFERENCES public.choice_selections(id, agency_id);


--
-- Name: installment_proposals fk_installment_proposals_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.installment_proposals
    ADD CONSTRAINT fk_installment_proposals_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: installment_proposals fk_installment_proposals_booking_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.installment_proposals
    ADD CONSTRAINT fk_installment_proposals_booking_same_agency FOREIGN KEY (client_booking_id, agency_id) REFERENCES public.client_bookings(id, agency_id);


--
-- Name: installments fk_installments_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.installments
    ADD CONSTRAINT fk_installments_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: installments fk_installments_charge_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.installments
    ADD CONSTRAINT fk_installments_charge_same_agency FOREIGN KEY (client_charge_id, agency_id) REFERENCES public.client_charges(id, agency_id);


--
-- Name: inventory_allocations fk_inventory_allocations_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_allocations
    ADD CONSTRAINT fk_inventory_allocations_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: inventory_allocations fk_inventory_allocations_booking_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_allocations
    ADD CONSTRAINT fk_inventory_allocations_booking_same_agency FOREIGN KEY (client_booking_id, agency_id) REFERENCES public.client_bookings(id, agency_id);


--
-- Name: inventory_allocations fk_inventory_allocations_creator_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_allocations
    ADD CONSTRAINT fk_inventory_allocations_creator_same_agency FOREIGN KEY (created_by_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: inventory_allocations fk_inventory_allocations_group_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_allocations
    ADD CONSTRAINT fk_inventory_allocations_group_same_agency FOREIGN KEY (inventory_group_id, agency_id) REFERENCES public.inventory_groups(id, agency_id);


--
-- Name: inventory_allocations fk_inventory_allocations_replaces; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_allocations
    ADD CONSTRAINT fk_inventory_allocations_replaces FOREIGN KEY (replaces_allocation_id) REFERENCES public.inventory_allocations(id);


--
-- Name: inventory_allocations fk_inventory_allocations_selection_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_allocations
    ADD CONSTRAINT fk_inventory_allocations_selection_same_agency FOREIGN KEY (choice_selection_id, agency_id) REFERENCES public.choice_selections(id, agency_id);


--
-- Name: inventory_allocations fk_inventory_allocations_shell_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_allocations
    ADD CONSTRAINT fk_inventory_allocations_shell_same_agency FOREIGN KEY (unit_shell_id, agency_id) REFERENCES public.unit_shells(id, agency_id);


--
-- Name: inventory_groups fk_inventory_groups_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_groups
    ADD CONSTRAINT fk_inventory_groups_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: inventory_groups fk_inventory_groups_arrangement_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_groups
    ADD CONSTRAINT fk_inventory_groups_arrangement_same_agency FOREIGN KEY (supplier_arrangement_id, agency_id) REFERENCES public.supplier_arrangements(id, agency_id);


--
-- Name: offering_choices fk_offering_choices_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offering_choices
    ADD CONSTRAINT fk_offering_choices_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: offering_choices fk_offering_choices_offering_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offering_choices
    ADD CONSTRAINT fk_offering_choices_offering_same_agency FOREIGN KEY (offering_id, agency_id) REFERENCES public.offerings(id, agency_id);


--
-- Name: offering_options fk_offering_options_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offering_options
    ADD CONSTRAINT fk_offering_options_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: offering_options fk_offering_options_choice_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offering_options
    ADD CONSTRAINT fk_offering_options_choice_same_agency FOREIGN KEY (offering_choice_id, agency_id) REFERENCES public.offering_choices(id, agency_id);


--
-- Name: offering_options fk_offering_options_group_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offering_options
    ADD CONSTRAINT fk_offering_options_group_same_agency FOREIGN KEY (inventory_group_id, agency_id) REFERENCES public.inventory_groups(id, agency_id);


--
-- Name: offering_prices fk_offering_prices_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offering_prices
    ADD CONSTRAINT fk_offering_prices_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: offering_prices fk_offering_prices_option_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offering_prices
    ADD CONSTRAINT fk_offering_prices_option_same_agency FOREIGN KEY (offering_option_id, agency_id) REFERENCES public.offering_options(id, agency_id);


--
-- Name: offering_prices fk_offering_prices_traveler_type_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offering_prices
    ADD CONSTRAINT fk_offering_prices_traveler_type_same_agency FOREIGN KEY (traveler_type_id, agency_id) REFERENCES public.traveler_types(id, agency_id);


--
-- Name: offering_publications fk_offering_publications_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offering_publications
    ADD CONSTRAINT fk_offering_publications_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: offering_publications fk_offering_publications_offering_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offering_publications
    ADD CONSTRAINT fk_offering_publications_offering_same_agency FOREIGN KEY (offering_id, agency_id) REFERENCES public.offerings(id, agency_id);


--
-- Name: offering_publications fk_offering_publications_publisher_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offering_publications
    ADD CONSTRAINT fk_offering_publications_publisher_same_agency FOREIGN KEY (published_by_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: offering_publications fk_offering_publications_reseller_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offering_publications
    ADD CONSTRAINT fk_offering_publications_reseller_same_agency FOREIGN KEY (reseller_id, agency_id) REFERENCES public.resellers(id, agency_id);


--
-- Name: offering_publications fk_offering_publications_withdrawer_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offering_publications
    ADD CONSTRAINT fk_offering_publications_withdrawer_same_agency FOREIGN KEY (withdrawn_by_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: offerings fk_offerings_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offerings
    ADD CONSTRAINT fk_offerings_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: offerings fk_offerings_departure_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offerings
    ADD CONSTRAINT fk_offerings_departure_same_agency FOREIGN KEY (departure_id, agency_id) REFERENCES public.departures(id, agency_id);


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
-- Name: receipts fk_receipts_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receipts
    ADD CONSTRAINT fk_receipts_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: receipts fk_receipts_departure_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receipts
    ADD CONSTRAINT fk_receipts_departure_same_agency FOREIGN KEY (departure_id, agency_id) REFERENCES public.departures(id, agency_id);


--
-- Name: receipts fk_receipts_payment_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receipts
    ADD CONSTRAINT fk_receipts_payment_same_agency FOREIGN KEY (client_payment_id, agency_id) REFERENCES public.client_payments(id, agency_id);


--
-- Name: resellers fk_resellers_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resellers
    ADD CONSTRAINT fk_resellers_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: schedule_lines fk_schedule_lines_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedule_lines
    ADD CONSTRAINT fk_schedule_lines_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: schedule_lines fk_schedule_lines_arrangement_currency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedule_lines
    ADD CONSTRAINT fk_schedule_lines_arrangement_currency FOREIGN KEY (supplier_arrangement_id, currency) REFERENCES public.supplier_arrangements(id, currency);


--
-- Name: schedule_lines fk_schedule_lines_arrangement_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedule_lines
    ADD CONSTRAINT fk_schedule_lines_arrangement_same_agency FOREIGN KEY (supplier_arrangement_id, agency_id) REFERENCES public.supplier_arrangements(id, agency_id);


--
-- Name: schedule_lines fk_schedule_lines_cost_line_of_arrangement; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedule_lines
    ADD CONSTRAINT fk_schedule_lines_cost_line_of_arrangement FOREIGN KEY (cost_line_id, supplier_arrangement_id) REFERENCES public.cost_lines(id, supplier_arrangement_id);


--
-- Name: schedule_lines fk_schedule_lines_deadline_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedule_lines
    ADD CONSTRAINT fk_schedule_lines_deadline_same_agency FOREIGN KEY (supplier_deadline_id, agency_id) REFERENCES public.supplier_deadlines(id, agency_id);


--
-- Name: schedule_lines fk_schedule_lines_group_of_arrangement; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedule_lines
    ADD CONSTRAINT fk_schedule_lines_group_of_arrangement FOREIGN KEY (inventory_group_id, supplier_arrangement_id) REFERENCES public.inventory_groups(id, supplier_arrangement_id);


--
-- Name: selection_occupants fk_selection_occupants_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.selection_occupants
    ADD CONSTRAINT fk_selection_occupants_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: selection_occupants fk_selection_occupants_selection_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.selection_occupants
    ADD CONSTRAINT fk_selection_occupants_selection_same_agency FOREIGN KEY (choice_selection_id, agency_id) REFERENCES public.choice_selections(id, agency_id);


--
-- Name: selection_occupants fk_selection_occupants_traveler_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.selection_occupants
    ADD CONSTRAINT fk_selection_occupants_traveler_same_agency FOREIGN KEY (booking_traveler_id, agency_id) REFERENCES public.booking_travelers(id, agency_id);


--
-- Name: supplier_arrangements fk_supplier_arrangements_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangements
    ADD CONSTRAINT fk_supplier_arrangements_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_arrangements fk_supplier_arrangements_departure_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangements
    ADD CONSTRAINT fk_supplier_arrangements_departure_same_agency FOREIGN KEY (departure_id, agency_id) REFERENCES public.departures(id, agency_id);


--
-- Name: supplier_arrangements fk_supplier_arrangements_payee_of_supplier; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangements
    ADD CONSTRAINT fk_supplier_arrangements_payee_of_supplier FOREIGN KEY (payee_account_id, supplier_id) REFERENCES public.payee_accounts(id, supplier_id);


--
-- Name: supplier_arrangements fk_supplier_arrangements_supplier_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_arrangements
    ADD CONSTRAINT fk_supplier_arrangements_supplier_same_agency FOREIGN KEY (supplier_id, agency_id) REFERENCES public.suppliers(id, agency_id);


--
-- Name: supplier_deadlines fk_supplier_deadlines_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadlines
    ADD CONSTRAINT fk_supplier_deadlines_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_deadlines fk_supplier_deadlines_arrangement_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadlines
    ADD CONSTRAINT fk_supplier_deadlines_arrangement_same_agency FOREIGN KEY (supplier_arrangement_id, agency_id) REFERENCES public.supplier_arrangements(id, agency_id);


--
-- Name: supplier_deadlines fk_supplier_deadlines_group_of_arrangement; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_deadlines
    ADD CONSTRAINT fk_supplier_deadlines_group_of_arrangement FOREIGN KEY (inventory_group_id, supplier_arrangement_id) REFERENCES public.inventory_groups(id, supplier_arrangement_id);


--
-- Name: supplier_payment_applications fk_supplier_payment_applications_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payment_applications
    ADD CONSTRAINT fk_supplier_payment_applications_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_payment_applications fk_supplier_payment_applications_amount_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payment_applications
    ADD CONSTRAINT fk_supplier_payment_applications_amount_same_agency FOREIGN KEY (amount_due_id, agency_id) REFERENCES public.amounts_due(id, agency_id);


--
-- Name: supplier_payment_applications fk_supplier_payment_applications_payment_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payment_applications
    ADD CONSTRAINT fk_supplier_payment_applications_payment_same_agency FOREIGN KEY (supplier_payment_id, agency_id) REFERENCES public.supplier_payments(id, agency_id);


--
-- Name: supplier_payment_applications fk_supplier_payment_applications_recorder_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payment_applications
    ADD CONSTRAINT fk_supplier_payment_applications_recorder_same_agency FOREIGN KEY (recorded_by_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: supplier_payment_reversals fk_supplier_payment_reversals_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payment_reversals
    ADD CONSTRAINT fk_supplier_payment_reversals_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_payment_reversals fk_supplier_payment_reversals_payment_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payment_reversals
    ADD CONSTRAINT fk_supplier_payment_reversals_payment_same_agency FOREIGN KEY (supplier_payment_id, agency_id) REFERENCES public.supplier_payments(id, agency_id);


--
-- Name: supplier_payment_reversals fk_supplier_payment_reversals_recorder_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payment_reversals
    ADD CONSTRAINT fk_supplier_payment_reversals_recorder_same_agency FOREIGN KEY (recorded_by_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: supplier_payments fk_supplier_payments_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payments
    ADD CONSTRAINT fk_supplier_payments_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_payments fk_supplier_payments_departure_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payments
    ADD CONSTRAINT fk_supplier_payments_departure_same_agency FOREIGN KEY (departure_id, agency_id) REFERENCES public.departures(id, agency_id);


--
-- Name: supplier_payments fk_supplier_payments_payee_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payments
    ADD CONSTRAINT fk_supplier_payments_payee_same_agency FOREIGN KEY (payee_account_id, agency_id) REFERENCES public.payee_accounts(id, agency_id);


--
-- Name: supplier_payments fk_supplier_payments_recorder_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payments
    ADD CONSTRAINT fk_supplier_payments_recorder_same_agency FOREIGN KEY (recorded_by_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: supplier_payments fk_supplier_payments_supplier_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_payments
    ADD CONSTRAINT fk_supplier_payments_supplier_same_agency FOREIGN KEY (supplier_id, agency_id) REFERENCES public.suppliers(id, agency_id);


--
-- Name: supplier_rate_bands fk_supplier_rate_bands_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_rate_bands
    ADD CONSTRAINT fk_supplier_rate_bands_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_rate_bands fk_supplier_rate_bands_arrangement_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_rate_bands
    ADD CONSTRAINT fk_supplier_rate_bands_arrangement_same_agency FOREIGN KEY (supplier_arrangement_id, agency_id) REFERENCES public.supplier_arrangements(id, agency_id);


--
-- Name: supplier_rate_bands fk_supplier_rate_bands_type_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_rate_bands
    ADD CONSTRAINT fk_supplier_rate_bands_type_same_agency FOREIGN KEY (traveler_type_id, agency_id) REFERENCES public.traveler_types(id, agency_id);


--
-- Name: supplier_rate_lines fk_supplier_rate_lines_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_rate_lines
    ADD CONSTRAINT fk_supplier_rate_lines_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_rate_lines fk_supplier_rate_lines_arrangement_currency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_rate_lines
    ADD CONSTRAINT fk_supplier_rate_lines_arrangement_currency FOREIGN KEY (supplier_arrangement_id, currency) REFERENCES public.supplier_arrangements(id, currency);


--
-- Name: supplier_rate_lines fk_supplier_rate_lines_arrangement_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_rate_lines
    ADD CONSTRAINT fk_supplier_rate_lines_arrangement_same_agency FOREIGN KEY (supplier_arrangement_id, agency_id) REFERENCES public.supplier_arrangements(id, agency_id);


--
-- Name: supplier_rate_lines fk_supplier_rate_lines_band_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_rate_lines
    ADD CONSTRAINT fk_supplier_rate_lines_band_same_agency FOREIGN KEY (supplier_rate_band_id, agency_id) REFERENCES public.supplier_rate_bands(id, agency_id);


--
-- Name: supplier_rate_lines fk_supplier_rate_lines_group_of_arrangement; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_rate_lines
    ADD CONSTRAINT fk_supplier_rate_lines_group_of_arrangement FOREIGN KEY (inventory_group_id, supplier_arrangement_id) REFERENCES public.inventory_groups(id, supplier_arrangement_id);


--
-- Name: supplier_rate_lines fk_supplier_rate_lines_traveler_type_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_rate_lines
    ADD CONSTRAINT fk_supplier_rate_lines_traveler_type_same_agency FOREIGN KEY (traveler_type_id, agency_id) REFERENCES public.traveler_types(id, agency_id);


--
-- Name: supplier_reservation_events fk_supplier_reservation_events_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_events
    ADD CONSTRAINT fk_supplier_reservation_events_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_reservation_events fk_supplier_reservation_events_recorder_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_events
    ADD CONSTRAINT fk_supplier_reservation_events_recorder_same_agency FOREIGN KEY (recorded_by_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: supplier_reservation_events fk_supplier_reservation_events_reservation_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_events
    ADD CONSTRAINT fk_supplier_reservation_events_reservation_same_agency FOREIGN KEY (supplier_reservation_id, agency_id) REFERENCES public.supplier_reservations(id, agency_id);


--
-- Name: supplier_reservation_units fk_supplier_reservation_units_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_units
    ADD CONSTRAINT fk_supplier_reservation_units_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_reservation_units fk_supplier_reservation_units_reservation_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_units
    ADD CONSTRAINT fk_supplier_reservation_units_reservation_same_agency FOREIGN KEY (supplier_reservation_id, agency_id) REFERENCES public.supplier_reservations(id, agency_id);


--
-- Name: supplier_reservation_units fk_supplier_reservation_units_selection_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservation_units
    ADD CONSTRAINT fk_supplier_reservation_units_selection_same_agency FOREIGN KEY (choice_selection_id, agency_id) REFERENCES public.choice_selections(id, agency_id);


--
-- Name: supplier_reservations fk_supplier_reservations_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservations
    ADD CONSTRAINT fk_supplier_reservations_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: supplier_reservations fk_supplier_reservations_arrangement_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservations
    ADD CONSTRAINT fk_supplier_reservations_arrangement_same_agency FOREIGN KEY (supplier_arrangement_id, agency_id) REFERENCES public.supplier_arrangements(id, agency_id);


--
-- Name: supplier_reservations fk_supplier_reservations_booking_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservations
    ADD CONSTRAINT fk_supplier_reservations_booking_same_agency FOREIGN KEY (client_booking_id, agency_id) REFERENCES public.client_bookings(id, agency_id);


--
-- Name: supplier_reservations fk_supplier_reservations_requester_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservations
    ADD CONSTRAINT fk_supplier_reservations_requester_same_agency FOREIGN KEY (requested_by_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: supplier_reservations fk_supplier_reservations_responder_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_reservations
    ADD CONSTRAINT fk_supplier_reservations_responder_same_agency FOREIGN KEY (responded_by_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: tasks fk_tasks_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT fk_tasks_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: tasks fk_tasks_amount_due_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT fk_tasks_amount_due_same_agency FOREIGN KEY (amount_due_id, agency_id) REFERENCES public.amounts_due(id, agency_id);


--
-- Name: tasks fk_tasks_departure_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT fk_tasks_departure_same_agency FOREIGN KEY (departure_id, agency_id) REFERENCES public.departures(id, agency_id);


--
-- Name: tasks fk_tasks_owner_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT fk_tasks_owner_same_agency FOREIGN KEY (owner_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: tasks fk_tasks_schedule_line_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT fk_tasks_schedule_line_same_agency FOREIGN KEY (schedule_line_id, agency_id) REFERENCES public.schedule_lines(id, agency_id);


--
-- Name: tasks fk_tasks_supplier_deadline_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT fk_tasks_supplier_deadline_same_agency FOREIGN KEY (supplier_deadline_id, agency_id) REFERENCES public.supplier_deadlines(id, agency_id);


--
-- Name: traveler_links fk_traveler_links_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traveler_links
    ADD CONSTRAINT fk_traveler_links_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: traveler_links fk_traveler_links_client_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traveler_links
    ADD CONSTRAINT fk_traveler_links_client_same_agency FOREIGN KEY (client_id, agency_id) REFERENCES public.clients(id, agency_id);


--
-- Name: traveler_links fk_traveler_links_traveler_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traveler_links
    ADD CONSTRAINT fk_traveler_links_traveler_same_agency FOREIGN KEY (traveler_id, agency_id) REFERENCES public.travelers(id, agency_id);


--
-- Name: travelers fk_travelers_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.travelers
    ADD CONSTRAINT fk_travelers_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: travelers fk_travelers_creator_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.travelers
    ADD CONSTRAINT fk_travelers_creator_same_agency FOREIGN KEY (created_by_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: trigger_event_shells fk_trigger_event_shells_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trigger_event_shells
    ADD CONSTRAINT fk_trigger_event_shells_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: trigger_event_shells fk_trigger_event_shells_event_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trigger_event_shells
    ADD CONSTRAINT fk_trigger_event_shells_event_same_agency FOREIGN KEY (trigger_event_id, agency_id) REFERENCES public.trigger_events(id, agency_id);


--
-- Name: trigger_event_shells fk_trigger_event_shells_shell_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trigger_event_shells
    ADD CONSTRAINT fk_trigger_event_shells_shell_same_agency FOREIGN KEY (unit_shell_id, agency_id) REFERENCES public.unit_shells(id, agency_id);


--
-- Name: trigger_events fk_trigger_events_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trigger_events
    ADD CONSTRAINT fk_trigger_events_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: trigger_events fk_trigger_events_arrangement_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trigger_events
    ADD CONSTRAINT fk_trigger_events_arrangement_same_agency FOREIGN KEY (supplier_arrangement_id, agency_id) REFERENCES public.supplier_arrangements(id, agency_id);


--
-- Name: trigger_events fk_trigger_events_booking_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trigger_events
    ADD CONSTRAINT fk_trigger_events_booking_same_agency FOREIGN KEY (client_booking_id, agency_id) REFERENCES public.client_bookings(id, agency_id);


--
-- Name: trigger_events fk_trigger_events_recorder_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trigger_events
    ADD CONSTRAINT fk_trigger_events_recorder_same_agency FOREIGN KEY (recorded_by_id, agency_id) REFERENCES public.agency_users(id, agency_id);


--
-- Name: unit_shells fk_unit_shells_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit_shells
    ADD CONSTRAINT fk_unit_shells_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id);


--
-- Name: unit_shells fk_unit_shells_group_same_agency; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit_shells
    ADD CONSTRAINT fk_unit_shells_group_same_agency FOREIGN KEY (inventory_group_id, agency_id) REFERENCES public.inventory_groups(id, agency_id);


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
('20261110110000'),
('20261110100000'),
('20261109100000'),
('20261108120000'),
('20261108100000'),
('20261107160000'),
('20261107150000'),
('20261107140000'),
('20261107130000'),
('20261107120000'),
('20261107110000'),
('20261107100000'),
('20261106210000'),
('20261106200000'),
('20261106110000'),
('20261106100000'),
('20261105220000'),
('20261105210000'),
('20261105200000'),
('20261105190000'),
('20261105180000'),
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

