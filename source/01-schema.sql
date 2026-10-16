--
-- PostgreSQL database dump
--

\restrict T7fbs8RPxDmOK6ll8EcnVmolsMM0QUBC22Cjo8WGajGzo5GU6p7EeYF7aAK7HOX

-- Dumped from database version 17.11 (Debian 17.11-0+deb13u1)
-- Dumped by pg_dump version 17.11 (Debian 17.11-0+deb13u1)

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
-- Name: buyer; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA buyer;


--
-- Name: commercial; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA commercial;


--
-- Name: document; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA document;


--
-- Name: enviro; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA enviro;


--
-- Name: financial; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA financial;


--
-- Name: fleet; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA fleet;


--
-- Name: hse; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA hse;


--
-- Name: notification; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA notification;


--
-- Name: operational; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA operational;


--
-- Name: param; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA param;


--
-- Name: partner; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA partner;


--
-- Name: site; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA site;


--
-- Name: survey; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA survey;


--
-- Name: telemetry; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA telemetry;


--
-- Name: voyage; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA voyage;


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: fn_deposit_balance_sync(); Type: FUNCTION; Schema: buyer; Owner: -
--

CREATE FUNCTION buyer.fn_deposit_balance_sync() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_deposit bigint;
BEGIN
    v_deposit := CASE WHEN TG_OP = 'DELETE' THEN OLD.deposit_id ELSE NEW.deposit_id END;

    UPDATE buyer.deposit d
       SET balance = COALESCE((
               SELECT SUM(CASE tipe WHEN 'TOP_UP' THEN amount ELSE -amount END)
                 FROM buyer.deposit_transaction dt
                WHERE dt.deposit_id = v_deposit), 0)
     WHERE d.deposit_id = v_deposit;

    -- kasus tepi: UPDATE memindahkan transaksi ke deposit lain → deposit lama
    -- juga harus dihitung ulang
    IF TG_OP = 'UPDATE' AND OLD.deposit_id IS DISTINCT FROM NEW.deposit_id THEN
        UPDATE buyer.deposit d
           SET balance = COALESCE((
                   SELECT SUM(CASE tipe WHEN 'TOP_UP' THEN amount ELSE -amount END)
                     FROM buyer.deposit_transaction dt
                    WHERE dt.deposit_id = OLD.deposit_id), 0)
         WHERE d.deposit_id = OLD.deposit_id;
    END IF;

    RETURN COALESCE(NEW, OLD);
END $$;


--
-- Name: fn_po_delivered_sync(); Type: FUNCTION; Schema: commercial; Owner: -
--

CREATE FUNCTION commercial.fn_po_delivered_sync() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_po bigint;
BEGIN
    -- temukan PO dari rantai trip → SI → DO
    SELECT d.po_id INTO v_po
      FROM operational.trip t
      JOIN operational.shipment_instruction si ON si.si_num = t.si_num
      JOIN commercial.delivery_order d         ON d.do_id  = si.do_id
     WHERE t.trip_id = NEW.trip_id;

    IF v_po IS NOT NULL THEN
        UPDATE commercial.purchase_order po
           SET delivered_m3 = COALESCE((
                   SELECT SUM(b.volume_m3)
                     FROM commercial.bap b
                     JOIN operational.trip t2                 ON t2.trip_id = b.trip_id
                     JOIN operational.shipment_instruction si2 ON si2.si_num = t2.si_num
                     JOIN commercial.delivery_order d2         ON d2.do_id   = si2.do_id
                    WHERE d2.po_id = v_po
                      AND b.status IN ('SIGNED','CORRECTED')), 0)
         WHERE po.po_id = v_po;
    END IF;

    RETURN NEW;
END $$;


--
-- Name: f_ikal(numeric, numeric, numeric, numeric, numeric); Type: FUNCTION; Schema: enviro; Owner: -
--

CREATE FUNCTION enviro.f_ikal(p_tss numeric, p_do numeric, p_ml numeric, p_amm numeric, p_po4 numeric) RETURNS numeric
    LANGUAGE sql IMMUTABLE
    AS $$
WITH q AS (
    SELECT
      round(CASE
        WHEN p_tss <= 20  THEN -0.035*p_tss*p_tss + 0.55*p_tss + 93
        WHEN p_tss <= 100 THEN 0.0008*p_tss*p_tss - 1.0217*p_tss + 107.83
        ELSE 10 END, 2) AS qtss,
      round(CASE
        WHEN p_do <= 3  THEN 1.6336*p_do*p_do*p_do - 5.3439*p_do*p_do + 12.996*p_do - 4e-12
        WHEN p_do <= 7  THEN -0.0028*p_do*p_do*p_do*p_do + 0.0611*p_do*p_do*p_do
                            - 2.5294*p_do*p_do + 37.097*p_do - 54.951
        WHEN p_do <= 10 THEN -1.5596*p_do*p_do*p_do + 38.895*p_do*p_do - 331.35*p_do + 1043.6
        WHEN p_do <= 11 THEN -20*p_do + 260
        WHEN p_do <= 15 THEN 40
        ELSE 0 END, 2) AS qdo,
      round(CASE
        WHEN p_ml <= 2  THEN 3.5*p_ml*p_ml - 47.5*p_ml + 100
        WHEN p_ml <= 4  THEN 2.5*p_ml*p_ml - 19.5*p_ml + 48
        WHEN p_ml <= 8  THEN 10
        WHEN p_ml <= 14 THEN -0.0333*p_ml*p_ml*p_ml + 0.9*p_ml*p_ml - 9.0667*p_ml + 42
        ELSE 0 END, 2) AS qml,
      round(CASE
        WHEN p_amm <= 0.4 THEN -2619*p_amm*p_amm*p_amm*p_amm + 238.1*p_amm*p_amm*p_amm
                             + 611.9*p_amm*p_amm - 200.95*p_amm + 100
        WHEN p_amm <= 1   THEN 4488.3*p_amm*p_amm*p_amm*p_amm*p_amm
                             - 17735*p_amm*p_amm*p_amm*p_amm + 27529*p_amm*p_amm*p_amm
                             - 20734*p_amm*p_amm + 7373.7*p_amm - 920.17
        ELSE 1 END, 2) AS qamm,
      round(CASE
        WHEN p_po4 <= 0.001 THEN -10000*p_po4 + 100
        WHEN p_po4 <= 0.015 THEN -598.36*p_po4 + 89.923
        WHEN p_po4 <= 0.05  THEN -1329.9*p_po4 + 99.995
        WHEN p_po4 <= 0.07  THEN -330.36*p_po4 + 51.726
        WHEN p_po4 <= 0.1   THEN -2678.6*p_po4*p_po4 + 89.286*p_po4 + 35.714
        WHEN p_po4 <= 1     THEN 2.7778*p_po4*p_po4 - 14.167*p_po4 + 16.389
        ELSE 2 END, 2) AS qpo4
)
SELECT round(round(qtss*0.223837849269234, 2) + round(qdo*0.196387027260743, 2)
           + round(qml*0.205162776063457, 2) + round(qamm*0.192041900850097, 2)
           + round(qpo4*0.182570446556469, 2), 2)
FROM q;
$$;


--
-- Name: f_ikal_kategori(numeric); Type: FUNCTION; Schema: enviro; Owner: -
--

CREATE FUNCTION enviro.f_ikal_kategori(x numeric) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
SELECT CASE WHEN x >= 90 THEN 'SANGAT BAIK'
            WHEN x >= 70 THEN 'BAIK'
            WHEN x >= 50 THEN 'SEDANG'
            WHEN x >= 25 THEN 'KURANG'
            ELSE 'SANGAT KURANG' END;
$$;


--
-- Name: fn_distance_m(public.geography, public.geography); Type: FUNCTION; Schema: telemetry; Owner: -
--

CREATE FUNCTION telemetry.fn_distance_m(g1 public.geography, g2 public.geography) RETURNS double precision
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $$
    SELECT ST_Distance(g1, g2)
$$;


--
-- Name: fn_distance_m(public.geometry, public.geometry); Type: FUNCTION; Schema: telemetry; Owner: -
--

CREATE FUNCTION telemetry.fn_distance_m(g1 public.geometry, g2 public.geometry) RETURNS double precision
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $$
    SELECT ST_Distance(
        (CASE WHEN ST_SRID(g1) = 0    THEN ST_SetSRID(g1, 4326)
              WHEN ST_SRID(g1) = 4326 THEN g1
              ELSE ST_Transform(g1, 4326) END)::geography,
        (CASE WHEN ST_SRID(g2) = 0    THEN ST_SetSRID(g2, 4326)
              WHEN ST_SRID(g2) = 4326 THEN g2
              ELSE ST_Transform(g2, 4326) END)::geography)
$$;


--
-- Name: fn_append_only_guard(); Type: FUNCTION; Schema: voyage; Owner: -
--

CREATE FUNCTION voyage.fn_append_only_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION
        'voyage.voyage bersifat APPEND-ONLY (patch B-12): % tidak diizinkan — koreksi lewat baris data baru',
        TG_OP;
END $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: deposit; Type: TABLE; Schema: buyer; Owner: -
--

CREATE TABLE buyer.deposit (
    deposit_id bigint NOT NULL,
    sales_contract_id bigint NOT NULL,
    currency_code character(3) NOT NULL,
    balance numeric(18,2) DEFAULT 0 NOT NULL,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: deposit_deposit_id_seq; Type: SEQUENCE; Schema: buyer; Owner: -
--

CREATE SEQUENCE buyer.deposit_deposit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: deposit_deposit_id_seq; Type: SEQUENCE OWNED BY; Schema: buyer; Owner: -
--

ALTER SEQUENCE buyer.deposit_deposit_id_seq OWNED BY buyer.deposit.deposit_id;


--
-- Name: deposit_transaction; Type: TABLE; Schema: buyer; Owner: -
--

CREATE TABLE buyer.deposit_transaction (
    dep_trans_id bigint NOT NULL,
    deposit_id bigint NOT NULL,
    tipe character varying(15) NOT NULL,
    amount numeric(18,2) NOT NULL,
    trip_id bigint,
    bap_id bigint,
    tx_date date NOT NULL,
    ref_doc character varying(100),
    created_by character varying(30),
    ledger_entry_id bigint,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_dt_amount_pos CHECK ((amount > (0)::numeric)),
    CONSTRAINT deposit_transaction_tipe_check CHECK (((tipe)::text = ANY ((ARRAY['TOP_UP'::character varying, 'DEDUCTION'::character varying, 'ADJUSTMENT'::character varying, 'REFUND'::character varying])::text[])))
);


--
-- Name: TABLE deposit_transaction; Type: COMMENT; Schema: buyer; Owner: -
--

COMMENT ON TABLE buyer.deposit_transaction IS 'TOP_UP/DEDUCTION/ADJUSTMENT/REFUND; DEDUCTION otomatis saat BAP sah: amount = min(saldo, tagihan); selisih → AR (FR-01-03)';


--
-- Name: deposit_transaction_dep_trans_id_seq; Type: SEQUENCE; Schema: buyer; Owner: -
--

CREATE SEQUENCE buyer.deposit_transaction_dep_trans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: deposit_transaction_dep_trans_id_seq; Type: SEQUENCE OWNED BY; Schema: buyer; Owner: -
--

ALTER SEQUENCE buyer.deposit_transaction_dep_trans_id_seq OWNED BY buyer.deposit_transaction.dep_trans_id;


--
-- Name: info; Type: TABLE; Schema: buyer; Owner: -
--

CREATE TABLE buyer.info (
    buyer_code character varying(30) NOT NULL,
    buyer_name character varying(150) NOT NULL,
    pic_name character varying(150),
    email character varying(150),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ledger_hist; Type: TABLE; Schema: buyer; Owner: -
--

CREATE TABLE buyer.ledger_hist (
    id bigint NOT NULL,
    buyer_code character varying(30) NOT NULL,
    entry_date date NOT NULL,
    ref_type character varying(50),
    ref_doc character varying(100),
    debit numeric(18,2) DEFAULT 0,
    credit numeric(18,2) DEFAULT 0,
    running_balance numeric(18,2)
);


--
-- Name: ledger_hist_id_seq; Type: SEQUENCE; Schema: buyer; Owner: -
--

CREATE SEQUENCE buyer.ledger_hist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ledger_hist_id_seq; Type: SEQUENCE OWNED BY; Schema: buyer; Owner: -
--

ALTER SEQUENCE buyer.ledger_hist_id_seq OWNED BY buyer.ledger_hist.id;


--
-- Name: site; Type: TABLE; Schema: buyer; Owner: -
--

CREATE TABLE buyer.site (
    buyer_site_id bigint NOT NULL,
    buyer_code character varying(30) NOT NULL,
    site_code character varying(30),
    note text
);


--
-- Name: site_buyer_site_id_seq; Type: SEQUENCE; Schema: buyer; Owner: -
--

CREATE SEQUENCE buyer.site_buyer_site_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: site_buyer_site_id_seq; Type: SEQUENCE OWNED BY; Schema: buyer; Owner: -
--

ALTER SEQUENCE buyer.site_buyer_site_id_seq OWNED BY buyer.site.buyer_site_id;


--
-- Name: bap; Type: TABLE; Schema: commercial; Owner: -
--

CREATE TABLE commercial.bap (
    bap_id bigint NOT NULL,
    bap_no character varying(50) NOT NULL,
    trip_id bigint NOT NULL,
    volume_m3 numeric(14,3) NOT NULL,
    status character varying(20) NOT NULL,
    signed_vessel_by character varying(150),
    signed_vessel_at timestamp with time zone,
    signed_customer_by character varying(150),
    signed_customer_at timestamp with time zone,
    signed_surveyor_by character varying(150),
    signed_surveyor_at timestamp with time zone,
    issued_at timestamp with time zone,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    signed_vessel_img text,
    signed_customer_img text,
    signed_surveyor_img text,
    CONSTRAINT bap_status_check CHECK (((status)::text = ANY ((ARRAY['DRAFT'::character varying, 'SIGNED'::character varying, 'DISPUTED'::character varying, 'CORRECTED'::character varying])::text[]))),
    CONSTRAINT chk_bap_volume_pos CHECK ((volume_m3 > (0)::numeric))
);


--
-- Name: TABLE bap; Type: COMMENT; Schema: commercial; Owner: -
--

COMMENT ON TABLE commercial.bap IS 'Sumber kebenaran volume; TTD 3 pihak (FR-05-08); koreksi hanya via bap_correction bernomor (R10)';


--
-- Name: COLUMN bap.signed_vessel_img; Type: COMMENT; Schema: commercial; Owner: -
--

COMMENT ON COLUMN commercial.bap.signed_vessel_img IS 'Tanda tangan Kapal/Nakhoda — PNG data-URL (base64) dari pad';


--
-- Name: COLUMN bap.signed_customer_img; Type: COMMENT; Schema: commercial; Owner: -
--

COMMENT ON COLUMN commercial.bap.signed_customer_img IS 'Tanda tangan Customer — PNG data-URL (base64) dari pad';


--
-- Name: COLUMN bap.signed_surveyor_img; Type: COMMENT; Schema: commercial; Owner: -
--

COMMENT ON COLUMN commercial.bap.signed_surveyor_img IS 'Tanda tangan Surveyor — PNG data-URL (base64) dari pad';


--
-- Name: bap_bap_id_seq; Type: SEQUENCE; Schema: commercial; Owner: -
--

CREATE SEQUENCE commercial.bap_bap_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bap_bap_id_seq; Type: SEQUENCE OWNED BY; Schema: commercial; Owner: -
--

ALTER SEQUENCE commercial.bap_bap_id_seq OWNED BY commercial.bap.bap_id;


--
-- Name: bap_correction; Type: TABLE; Schema: commercial; Owner: -
--

CREATE TABLE commercial.bap_correction (
    bap_correction_id bigint NOT NULL,
    correction_no character varying(50) NOT NULL,
    bap_id bigint NOT NULL,
    delta_volume_m3 numeric(14,3) NOT NULL,
    reason text NOT NULL,
    approved_by character varying(30),
    approved_at timestamp with time zone,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: bap_correction_bap_correction_id_seq; Type: SEQUENCE; Schema: commercial; Owner: -
--

CREATE SEQUENCE commercial.bap_correction_bap_correction_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bap_correction_bap_correction_id_seq; Type: SEQUENCE OWNED BY; Schema: commercial; Owner: -
--

ALTER SEQUENCE commercial.bap_correction_bap_correction_id_seq OWNED BY commercial.bap_correction.bap_correction_id;


--
-- Name: bap_objection; Type: TABLE; Schema: commercial; Owner: -
--

CREATE TABLE commercial.bap_objection (
    bap_objection_id bigint NOT NULL,
    bap_id bigint NOT NULL,
    raised_by character varying(150),
    raised_at timestamp with time zone DEFAULT now(),
    content text,
    resolution text,
    resolved_at timestamp with time zone,
    status character varying(20) DEFAULT 'OPEN'::character varying NOT NULL,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_objection_status CHECK (((status)::text = ANY ((ARRAY['OPEN'::character varying, 'RESOLVED'::character varying, 'REJECTED'::character varying])::text[])))
);


--
-- Name: bap_objection_bap_objection_id_seq; Type: SEQUENCE; Schema: commercial; Owner: -
--

CREATE SEQUENCE commercial.bap_objection_bap_objection_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bap_objection_bap_objection_id_seq; Type: SEQUENCE OWNED BY; Schema: commercial; Owner: -
--

ALTER SEQUENCE commercial.bap_objection_bap_objection_id_seq OWNED BY commercial.bap_objection.bap_objection_id;


--
-- Name: delivery_order; Type: TABLE; Schema: commercial; Owner: -
--

CREATE TABLE commercial.delivery_order (
    do_id bigint NOT NULL,
    do_no character varying(50) NOT NULL,
    po_id bigint,
    vessel_name character varying(100),
    volume_m3 numeric(14,3),
    do_date date,
    status character varying(20) DEFAULT 'ISSUED'::character varying,
    fleet_code character varying(30)
);


--
-- Name: delivery_order_do_id_seq; Type: SEQUENCE; Schema: commercial; Owner: -
--

CREATE SEQUENCE commercial.delivery_order_do_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: delivery_order_do_id_seq; Type: SEQUENCE OWNED BY; Schema: commercial; Owner: -
--

ALTER SEQUENCE commercial.delivery_order_do_id_seq OWNED BY commercial.delivery_order.do_id;


--
-- Name: purchase_order; Type: TABLE; Schema: commercial; Owner: -
--

CREATE TABLE commercial.purchase_order (
    po_id bigint NOT NULL,
    po_no character varying(50) NOT NULL,
    buyer_code character varying(30),
    contract_number character varying(50),
    volume_m3 numeric(14,3),
    delivered_m3 numeric(14,3) DEFAULT 0,
    po_date date,
    status character varying(20) DEFAULT 'OPEN'::character varying,
    sales_contract_id bigint
);


--
-- Name: purchase_order_po_id_seq; Type: SEQUENCE; Schema: commercial; Owner: -
--

CREATE SEQUENCE commercial.purchase_order_po_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: purchase_order_po_id_seq; Type: SEQUENCE OWNED BY; Schema: commercial; Owner: -
--

ALTER SEQUENCE commercial.purchase_order_po_id_seq OWNED BY commercial.purchase_order.po_id;


--
-- Name: qa_sample; Type: TABLE; Schema: commercial; Owner: -
--

CREATE TABLE commercial.qa_sample (
    qa_sample_id uuid DEFAULT gen_random_uuid() NOT NULL,
    trip_id bigint NOT NULL,
    tipe character varying(10) NOT NULL,
    sampled_at timestamp with time zone NOT NULL,
    sampled_by character varying(150),
    sales_contract_id bigint,
    results jsonb,
    verdict character varying(10) DEFAULT 'PENDING'::character varying,
    claim_status character varying(20),
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_qa_claim_status CHECK (((claim_status IS NULL) OR ((claim_status)::text = ANY ((ARRAY['NONE'::character varying, 'FILED'::character varying, 'APPROVED'::character varying, 'REJECTED'::character varying])::text[])))),
    CONSTRAINT qa_sample_tipe_check CHECK (((tipe)::text = ANY ((ARRAY['MUAT'::character varying, 'BONGKAR'::character varying])::text[]))),
    CONSTRAINT qa_sample_verdict_check CHECK (((verdict)::text = ANY ((ARRAY['PASS'::character varying, 'FAIL'::character varying, 'PENDING'::character varying])::text[])))
);


--
-- Name: sales_contract; Type: TABLE; Schema: commercial; Owner: -
--

CREATE TABLE commercial.sales_contract (
    sales_contract_id bigint NOT NULL,
    contract_no character varying(50) NOT NULL,
    buyer_code character varying(30) NOT NULL,
    site_code character varying(30),
    date_start date NOT NULL,
    date_end date,
    volume_min_m3 numeric(14,3),
    volume_max_m3 numeric(14,3),
    price_per_m3 numeric(18,4) NOT NULL,
    currency_code character(3) NOT NULL,
    sand_spec_id bigint,
    payment_mode character varying(20) NOT NULL,
    free_time_hours integer,
    standby_rate_per_hour numeric(18,2),
    status character varying(30) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT sales_contract_payment_mode_check CHECK (((payment_mode)::text = ANY ((ARRAY['DEPOSIT'::character varying, 'PELUNASAN'::character varying])::text[])))
);


--
-- Name: sales_contract_sales_contract_id_seq; Type: SEQUENCE; Schema: commercial; Owner: -
--

CREATE SEQUENCE commercial.sales_contract_sales_contract_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sales_contract_sales_contract_id_seq; Type: SEQUENCE OWNED BY; Schema: commercial; Owner: -
--

ALTER SEQUENCE commercial.sales_contract_sales_contract_id_seq OWNED BY commercial.sales_contract.sales_contract_id;


--
-- Name: sand_spec; Type: TABLE; Schema: commercial; Owner: -
--

CREATE TABLE commercial.sand_spec (
    sand_spec_id bigint NOT NULL,
    name character varying(150) NOT NULL,
    params jsonb NOT NULL,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: sand_spec_sand_spec_id_seq; Type: SEQUENCE; Schema: commercial; Owner: -
--

CREATE SEQUENCE commercial.sand_spec_sand_spec_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sand_spec_sand_spec_id_seq; Type: SEQUENCE OWNED BY; Schema: commercial; Owner: -
--

ALTER SEQUENCE commercial.sand_spec_sand_spec_id_seq OWNED BY commercial.sand_spec.sand_spec_id;


--
-- Name: standby_claim; Type: TABLE; Schema: commercial; Owner: -
--

CREATE TABLE commercial.standby_claim (
    standby_claim_id bigint NOT NULL,
    trip_id bigint NOT NULL,
    free_time_minutes integer NOT NULL,
    standby_minutes integer NOT NULL,
    billable_minutes integer NOT NULL,
    rate numeric(18,2) NOT NULL,
    amount numeric(18,2) NOT NULL,
    status character varying(20) NOT NULL,
    disposed_by character varying(30),
    disposed_at timestamp with time zone,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_standby_nonneg CHECK (((free_time_minutes >= 0) AND (standby_minutes >= 0) AND (billable_minutes >= 0) AND (rate > (0)::numeric) AND (amount >= (0)::numeric))),
    CONSTRAINT standby_claim_status_check CHECK (((status)::text = ANY ((ARRAY['COMPUTED'::character varying, 'DISPOSED_TAGIH'::character varying, 'DISPOSED_HANGUS'::character varying])::text[])))
);


--
-- Name: standby_claim_standby_claim_id_seq; Type: SEQUENCE; Schema: commercial; Owner: -
--

CREATE SEQUENCE commercial.standby_claim_standby_claim_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: standby_claim_standby_claim_id_seq; Type: SEQUENCE OWNED BY; Schema: commercial; Owner: -
--

ALTER SEQUENCE commercial.standby_claim_standby_claim_id_seq OWNED BY commercial.standby_claim.standby_claim_id;


--
-- Name: document; Type: TABLE; Schema: document; Owner: -
--

CREATE TABLE document.document (
    document_id bigint NOT NULL,
    doc_key character varying(100),
    doc_type character varying(30),
    title character varying(200),
    entity_type character varying(50),
    entity_id bigint,
    file_ref character varying(300),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: document_document_id_seq; Type: SEQUENCE; Schema: document; Owner: -
--

CREATE SEQUENCE document.document_document_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: document_document_id_seq; Type: SEQUENCE OWNED BY; Schema: document; Owner: -
--

ALTER SEQUENCE document.document_document_id_seq OWNED BY document.document.document_id;


--
-- Name: document_link; Type: TABLE; Schema: document; Owner: -
--

CREATE TABLE document.document_link (
    document_id bigint NOT NULL,
    entity_type character varying(50) NOT NULL,
    entity_id bigint NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ews_event; Type: TABLE; Schema: enviro; Owner: -
--

CREATE TABLE enviro.ews_event (
    ews_event_id bigint NOT NULL,
    station_code character varying(30),
    parameter_code character varying(30),
    level character varying(10) NOT NULL,
    trigger_rule character varying(15) NOT NULL,
    value_snapshot jsonb,
    notified jsonb,
    playbook_ref character varying(50),
    playbook_executed text,
    outcome text,
    closed_at timestamp with time zone,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ews_event_level_check CHECK (((level)::text = ANY ((ARRAY['WARNING'::character varying, 'EXCEEDED'::character varying])::text[]))),
    CONSTRAINT ews_event_trigger_rule_check CHECK (((trigger_rule)::text = ANY ((ARRAY['THRESHOLD'::character varying, 'TREND'::character varying, 'COMPOSITE'::character varying, 'TIDE_WINDOW'::character varying])::text[])))
);


--
-- Name: TABLE ews_event; Type: COMMENT; Schema: enviro; Owner: -
--

COMMENT ON TABLE enviro.ews_event IS 'EWS 3-tier (R21/R22) — dibangkitkan dari reading_detail & hasil lab (batch, fase 1)';


--
-- Name: ews_event_ews_event_id_seq; Type: SEQUENCE; Schema: enviro; Owner: -
--

CREATE SEQUENCE enviro.ews_event_ews_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ews_event_ews_event_id_seq; Type: SEQUENCE OWNED BY; Schema: enviro; Owner: -
--

ALTER SEQUENCE enviro.ews_event_ews_event_id_seq OWNED BY enviro.ews_event.ews_event_id;


--
-- Name: mon_parameter; Type: TABLE; Schema: enviro; Owner: -
--

CREATE TABLE enviro.mon_parameter (
    parameter_code character varying(30) NOT NULL,
    name character varying(100) NOT NULL,
    unit character varying(20) NOT NULL,
    parameter_group character varying(15) NOT NULL,
    is_core boolean DEFAULT false NOT NULL,
    standard_value numeric(18,6),
    standard_source character varying(100) DEFAULT 'ASEAN MWQC'::character varying,
    warning_threshold_pct numeric(5,2) DEFAULT 90 NOT NULL,
    tenant_id uuid,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT mon_parameter_parameter_group_check CHECK (((parameter_group)::text = ANY ((ARRAY['AIR'::character varying, 'HIDRO'::character varying, 'SEDIMEN'::character varying, 'BIOTA'::character varying, 'SOSIAL'::character varying])::text[])))
);


--
-- Name: TABLE mon_parameter; Type: COMMENT; Schema: enviro; Owner: -
--

COMMENT ON TABLE enviro.mon_parameter IS 'Master parameter + baku mutu + ambang 90% (warning_threshold_pct, konfigurabel per parameter)';


--
-- Name: mon_report; Type: TABLE; Schema: enviro; Owner: -
--

CREATE TABLE enviro.mon_report (
    mon_report_id bigint NOT NULL,
    period character varying(10) NOT NULL,
    report_type character varying(20) DEFAULT 'RKL_RPL'::character varying NOT NULL,
    draft_generated_at timestamp with time zone,
    reviewed_by character varying(30),
    submitted_at timestamp with time zone,
    doc_ref bigint,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: mon_report_mon_report_id_seq; Type: SEQUENCE; Schema: enviro; Owner: -
--

CREATE SEQUENCE enviro.mon_report_mon_report_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mon_report_mon_report_id_seq; Type: SEQUENCE OWNED BY; Schema: enviro; Owner: -
--

ALTER SEQUENCE enviro.mon_report_mon_report_id_seq OWNED BY enviro.mon_report.mon_report_id;


--
-- Name: mon_schedule; Type: TABLE; Schema: enviro; Owner: -
--

CREATE TABLE enviro.mon_schedule (
    schedule_id bigint NOT NULL,
    parameter_code character varying(30) NOT NULL,
    station_code character varying(30) NOT NULL,
    frequency character varying(20) DEFAULT 'SEMESTERAN'::character varying NOT NULL,
    next_due date NOT NULL,
    auto_wo boolean DEFAULT true NOT NULL,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: mon_schedule_schedule_id_seq; Type: SEQUENCE; Schema: enviro; Owner: -
--

CREATE SEQUENCE enviro.mon_schedule_schedule_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mon_schedule_schedule_id_seq; Type: SEQUENCE OWNED BY; Schema: enviro; Owner: -
--

ALTER SEQUENCE enviro.mon_schedule_schedule_id_seq OWNED BY enviro.mon_schedule.schedule_id;


--
-- Name: mon_work_order; Type: TABLE; Schema: enviro; Owner: -
--

CREATE TABLE enviro.mon_work_order (
    wo_id bigint NOT NULL,
    wo_no character varying(30) NOT NULL,
    vendor_code character varying(30),
    kind character varying(20) NOT NULL,
    scheduled_date date NOT NULL,
    status character varying(20) DEFAULT 'ISSUED'::character varying NOT NULL,
    station_codes character varying[],
    parameter_codes character varying[],
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT mon_work_order_kind_check CHECK (((kind)::text = ANY ((ARRAY['SAMPLING'::character varying, 'BUOY_DOWNLOAD'::character varying])::text[]))),
    CONSTRAINT mon_work_order_status_check CHECK (((status)::text = ANY ((ARRAY['ISSUED'::character varying, 'IN_PROGRESS'::character varying, 'COMPLETED'::character varying])::text[])))
);


--
-- Name: mon_work_order_wo_id_seq; Type: SEQUENCE; Schema: enviro; Owner: -
--

CREATE SEQUENCE enviro.mon_work_order_wo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mon_work_order_wo_id_seq; Type: SEQUENCE OWNED BY; Schema: enviro; Owner: -
--

ALTER SEQUENCE enviro.mon_work_order_wo_id_seq OWNED BY enviro.mon_work_order.wo_id;


--
-- Name: reading_detail; Type: TABLE; Schema: enviro; Owner: -
--

CREATE TABLE enviro.reading_detail (
    reading_detail_id bigint NOT NULL,
    station_code character varying(30) NOT NULL,
    parameter_code character varying(30) NOT NULL,
    record_time timestamp with time zone NOT NULL,
    value numeric(18,6) NOT NULL,
    unit character varying(20),
    source character varying(10) DEFAULT 'BUOY'::character varying NOT NULL,
    source_ref character varying(100),
    qc_status character varying(10) DEFAULT 'RAW'::character varying NOT NULL,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_reading_nonneg CHECK ((value >= (0)::numeric)),
    CONSTRAINT reading_detail_qc_status_check CHECK (((qc_status)::text = ANY ((ARRAY['RAW'::character varying, 'VALIDATED'::character varying, 'REJECTED'::character varying])::text[]))),
    CONSTRAINT reading_detail_source_check CHECK (((source)::text = ANY ((ARRAY['BUOY'::character varying, 'LAB'::character varying, 'MANUAL'::character varying])::text[])))
);


--
-- Name: reading_detail_reading_detail_id_seq; Type: SEQUENCE; Schema: enviro; Owner: -
--

CREATE SEQUENCE enviro.reading_detail_reading_detail_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reading_detail_reading_detail_id_seq; Type: SEQUENCE OWNED BY; Schema: enviro; Owner: -
--

ALTER SEQUENCE enviro.reading_detail_reading_detail_id_seq OWNED BY enviro.reading_detail.reading_detail_id;


--
-- Name: remediation; Type: TABLE; Schema: enviro; Owner: -
--

CREATE TABLE enviro.remediation (
    remediation_id bigint NOT NULL,
    cause_type character varying(10) NOT NULL,
    cause_id bigint NOT NULL,
    plan text NOT NULL,
    started_at timestamp with time zone,
    status character varying(12) DEFAULT 'PLANNED'::character varying NOT NULL,
    verification_refs bigint[],
    closed_at timestamp with time zone,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT remediation_cause_type_check CHECK (((cause_type)::text = ANY ((ARRAY['EWS'::character varying, 'MON_RECORD'::character varying])::text[]))),
    CONSTRAINT remediation_status_check CHECK (((status)::text = ANY ((ARRAY['PLANNED'::character varying, 'IN_PROGRESS'::character varying, 'VERIFYING'::character varying, 'CLOSED'::character varying])::text[])))
);


--
-- Name: remediation_remediation_id_seq; Type: SEQUENCE; Schema: enviro; Owner: -
--

CREATE SEQUENCE enviro.remediation_remediation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: remediation_remediation_id_seq; Type: SEQUENCE OWNED BY; Schema: enviro; Owner: -
--

ALTER SEQUENCE enviro.remediation_remediation_id_seq OWNED BY enviro.remediation.remediation_id;


--
-- Name: station; Type: TABLE; Schema: enviro; Owner: -
--

CREATE TABLE enviro.station (
    station_code character varying(30) NOT NULL,
    station_name character varying(150) NOT NULL,
    station_type character varying(20),
    location public.geometry(Point,4326)
);


--
-- Name: cost_entry; Type: TABLE; Schema: financial; Owner: -
--

CREATE TABLE financial.cost_entry (
    cost_entry_id bigint NOT NULL,
    trip_id bigint NOT NULL,
    category character varying(15) NOT NULL,
    charter_contract_id bigint,
    amount numeric(18,2) NOT NULL,
    source character varying(10) DEFAULT 'AUTO'::character varying NOT NULL,
    description text,
    journal_id bigint,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_cost_amount_nonneg CHECK ((amount >= (0)::numeric)),
    CONSTRAINT cost_entry_category_check CHECK (((category)::text = ANY ((ARRAY['CHARTER'::character varying, 'STANDBY'::character varying, 'OTHER'::character varying])::text[]))),
    CONSTRAINT cost_entry_source_check CHECK (((source)::text = ANY ((ARRAY['AUTO'::character varying, 'MANUAL'::character varying])::text[])))
);


--
-- Name: cost_entry_cost_entry_id_seq; Type: SEQUENCE; Schema: financial; Owner: -
--

CREATE SEQUENCE financial.cost_entry_cost_entry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cost_entry_cost_entry_id_seq; Type: SEQUENCE OWNED BY; Schema: financial; Owner: -
--

ALTER SEQUENCE financial.cost_entry_cost_entry_id_seq OWNED BY financial.cost_entry.cost_entry_id;


--
-- Name: invoice; Type: TABLE; Schema: financial; Owner: -
--

CREATE TABLE financial.invoice (
    invoice_id bigint NOT NULL,
    invoice_no character varying(50) NOT NULL,
    invoice_type character varying(10) NOT NULL,
    partner_code character varying(30),
    amount numeric(18,2) NOT NULL,
    currency_code character(3) DEFAULT 'IDR'::bpchar,
    status character varying(20) DEFAULT 'ISSUED'::character varying,
    issued_at date,
    due_date date,
    buyer_code character varying(30),
    CONSTRAINT invoice_invoice_type_check CHECK (((invoice_type)::text = ANY ((ARRAY['SALES'::character varying, 'PURCHASE'::character varying])::text[])))
);


--
-- Name: invoice_invoice_id_seq; Type: SEQUENCE; Schema: financial; Owner: -
--

CREATE SEQUENCE financial.invoice_invoice_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invoice_invoice_id_seq; Type: SEQUENCE OWNED BY; Schema: financial; Owner: -
--

ALTER SEQUENCE financial.invoice_invoice_id_seq OWNED BY financial.invoice.invoice_id;


--
-- Name: journal; Type: TABLE; Schema: financial; Owner: -
--

CREATE TABLE financial.journal (
    journal_id bigint NOT NULL,
    journal_no character varying(30) NOT NULL,
    je_date date NOT NULL,
    ref_type character varying(50),
    ref_doc character varying(100),
    description character varying(300),
    total_amount numeric(18,2)
);


--
-- Name: journal_journal_id_seq; Type: SEQUENCE; Schema: financial; Owner: -
--

CREATE SEQUENCE financial.journal_journal_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: journal_journal_id_seq; Type: SEQUENCE OWNED BY; Schema: financial; Owner: -
--

ALTER SEQUENCE financial.journal_journal_id_seq OWNED BY financial.journal.journal_id;


--
-- Name: journal_line; Type: TABLE; Schema: financial; Owner: -
--

CREATE TABLE financial.journal_line (
    journal_line_id bigint NOT NULL,
    journal_id bigint NOT NULL,
    line_no integer NOT NULL,
    account_code character varying(20) NOT NULL,
    account_name character varying(150),
    debit numeric(18,2) DEFAULT 0,
    credit numeric(18,2) DEFAULT 0
);


--
-- Name: journal_line_journal_line_id_seq; Type: SEQUENCE; Schema: financial; Owner: -
--

CREATE SEQUENCE financial.journal_line_journal_line_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: journal_line_journal_line_id_seq; Type: SEQUENCE OWNED BY; Schema: financial; Owner: -
--

ALTER SEQUENCE financial.journal_line_journal_line_id_seq OWNED BY financial.journal_line.journal_line_id;


--
-- Name: pnbp_charge; Type: TABLE; Schema: financial; Owner: -
--

CREATE TABLE financial.pnbp_charge (
    pnbp_charge_id bigint NOT NULL,
    trip_id bigint NOT NULL,
    bap_id bigint NOT NULL,
    volume_basis_m3 numeric(14,3) NOT NULL,
    rate numeric(18,4) NOT NULL,
    amount numeric(18,2) NOT NULL,
    period character varying(10),
    status character varying(15) DEFAULT 'ACCRUED'::character varying NOT NULL,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_pnbp_nonneg CHECK (((volume_basis_m3 >= (0)::numeric) AND (amount >= (0)::numeric))),
    CONSTRAINT pnbp_charge_status_check CHECK (((status)::text = ANY ((ARRAY['ACCRUED'::character varying, 'REPORTED'::character varying, 'PAID'::character varying])::text[])))
);


--
-- Name: pnbp_charge_pnbp_charge_id_seq; Type: SEQUENCE; Schema: financial; Owner: -
--

CREATE SEQUENCE financial.pnbp_charge_pnbp_charge_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pnbp_charge_pnbp_charge_id_seq; Type: SEQUENCE OWNED BY; Schema: financial; Owner: -
--

ALTER SEQUENCE financial.pnbp_charge_pnbp_charge_id_seq OWNED BY financial.pnbp_charge.pnbp_charge_id;


--
-- Name: pnbp_tahap_awal; Type: TABLE; Schema: financial; Owner: -
--

CREATE TABLE financial.pnbp_tahap_awal (
    tahap_id integer NOT NULL,
    sales_contract_id bigint NOT NULL,
    proyeksi_m3 numeric NOT NULL,
    tarif numeric NOT NULL,
    proyeksi_total numeric NOT NULL,
    amount_5pct numeric NOT NULL,
    due_date date NOT NULL,
    status character varying(12) DEFAULT 'DUE'::character varying NOT NULL,
    paid_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: pnbp_tahap_awal_tahap_id_seq; Type: SEQUENCE; Schema: financial; Owner: -
--

CREATE SEQUENCE financial.pnbp_tahap_awal_tahap_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pnbp_tahap_awal_tahap_id_seq; Type: SEQUENCE OWNED BY; Schema: financial; Owner: -
--

ALTER SEQUENCE financial.pnbp_tahap_awal_tahap_id_seq OWNED BY financial.pnbp_tahap_awal.tahap_id;


--
-- Name: pnbp_tarif; Type: TABLE; Schema: financial; Owner: -
--

CREATE TABLE financial.pnbp_tarif (
    tarif_id integer NOT NULL,
    kategori character varying(20) NOT NULL,
    harga_patokan numeric NOT NULL,
    tarif_pct numeric NOT NULL,
    dasar_hukum character varying(200) NOT NULL,
    berlaku_mulai date NOT NULL,
    is_aktif boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: pnbp_tarif_tarif_id_seq; Type: SEQUENCE; Schema: financial; Owner: -
--

CREATE SEQUENCE financial.pnbp_tarif_tarif_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pnbp_tarif_tarif_id_seq; Type: SEQUENCE OWNED BY; Schema: financial; Owner: -
--

ALTER SEQUENCE financial.pnbp_tarif_tarif_id_seq OWNED BY financial.pnbp_tarif.tarif_id;


--
-- Name: info; Type: TABLE; Schema: fleet; Owner: -
--

CREATE TABLE fleet.info (
    fleet_code character varying(30) NOT NULL,
    fleet_name character varying(100) NOT NULL,
    vessel_type character varying(30),
    status character varying(20) DEFAULT 'AKTIF'::character varying,
    latest_lat double precision,
    latest_lng double precision,
    latest_seen_at timestamp with time zone,
    hopper_capacity_m3 numeric(14,3),
    CONSTRAINT chk_fleet_hopper_capacity CHECK (((hopper_capacity_m3 IS NULL) OR (hopper_capacity_m3 > (0)::numeric)))
);


--
-- Name: capa; Type: TABLE; Schema: hse; Owner: -
--

CREATE TABLE hse.capa (
    capa_id bigint NOT NULL,
    capa_no character varying(30) NOT NULL,
    source_type character varying(12) NOT NULL,
    source_ref character varying(30) NOT NULL,
    description text NOT NULL,
    severity integer NOT NULL,
    due_date date NOT NULL,
    status character varying(12) DEFAULT 'OPEN'::character varying NOT NULL,
    closed_at date,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT capa_check CHECK ((((status)::text <> 'CLOSED'::text) OR (closed_at IS NOT NULL))),
    CONSTRAINT capa_severity_check CHECK (((severity >= 1) AND (severity <= 5))),
    CONSTRAINT capa_source_type_check CHECK (((source_type)::text = ANY ((ARRAY['INSPECTION'::character varying, 'INCIDENT'::character varying])::text[]))),
    CONSTRAINT capa_status_check CHECK (((status)::text = ANY ((ARRAY['OPEN'::character varying, 'IN_PROGRESS'::character varying, 'CLOSED'::character varying])::text[])))
);


--
-- Name: capa_capa_id_seq; Type: SEQUENCE; Schema: hse; Owner: -
--

CREATE SEQUENCE hse.capa_capa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: capa_capa_id_seq; Type: SEQUENCE OWNED BY; Schema: hse; Owner: -
--

ALTER SEQUENCE hse.capa_capa_id_seq OWNED BY hse.capa.capa_id;


--
-- Name: certificate; Type: TABLE; Schema: hse; Owner: -
--

CREATE TABLE hse.certificate (
    certificate_id bigint NOT NULL,
    fleet_code character varying(30) NOT NULL,
    cert_type character varying(60) NOT NULL,
    issued_at date NOT NULL,
    expires_at date NOT NULL,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT certificate_check CHECK ((expires_at > issued_at))
);


--
-- Name: certificate_certificate_id_seq; Type: SEQUENCE; Schema: hse; Owner: -
--

CREATE SEQUENCE hse.certificate_certificate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: certificate_certificate_id_seq; Type: SEQUENCE OWNED BY; Schema: hse; Owner: -
--

ALTER SEQUENCE hse.certificate_certificate_id_seq OWNED BY hse.certificate.certificate_id;


--
-- Name: incident; Type: TABLE; Schema: hse; Owner: -
--

CREATE TABLE hse.incident (
    incident_id bigint NOT NULL,
    incident_no character varying(30) NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    fleet_code character varying(30),
    category character varying(20) NOT NULL,
    description text NOT NULL,
    reported_via character varying(10) DEFAULT 'PWA'::character varying NOT NULL,
    status character varying(10) DEFAULT 'OPEN'::character varying NOT NULL,
    closed_at timestamp with time zone,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by text,
    CONSTRAINT incident_category_check CHECK (((category)::text = ANY ((ARRAY['NEAR_MISS'::character varying, 'FIRST_AID'::character varying, 'MEDICAL_TREATMENT'::character varying, 'LTI'::character varying, 'ENVIRONMENT'::character varying])::text[]))),
    CONSTRAINT incident_reported_via_check CHECK (((reported_via)::text = ANY ((ARRAY['PWA'::character varying, 'PORTAL'::character varying, 'EMAIL'::character varying])::text[]))),
    CONSTRAINT incident_status_check CHECK (((status)::text = ANY ((ARRAY['OPEN'::character varying, 'CLOSED'::character varying])::text[])))
);


--
-- Name: incident_incident_id_seq; Type: SEQUENCE; Schema: hse; Owner: -
--

CREATE SEQUENCE hse.incident_incident_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: incident_incident_id_seq; Type: SEQUENCE OWNED BY; Schema: hse; Owner: -
--

ALTER SEQUENCE hse.incident_incident_id_seq OWNED BY hse.incident.incident_id;


--
-- Name: induction; Type: TABLE; Schema: hse; Owner: -
--

CREATE TABLE hse.induction (
    induction_id bigint NOT NULL,
    crew_name character varying(100) NOT NULL,
    crew_role character varying(60),
    fleet_code character varying(30),
    done_at date NOT NULL,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: induction_induction_id_seq; Type: SEQUENCE; Schema: hse; Owner: -
--

CREATE SEQUENCE hse.induction_induction_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: induction_induction_id_seq; Type: SEQUENCE OWNED BY; Schema: hse; Owner: -
--

ALTER SEQUENCE hse.induction_induction_id_seq OWNED BY hse.induction.induction_id;


--
-- Name: inspection; Type: TABLE; Schema: hse; Owner: -
--

CREATE TABLE hse.inspection (
    inspection_id bigint NOT NULL,
    inspection_no character varying(30) NOT NULL,
    scheduled_date date NOT NULL,
    unit_kode character varying(30) NOT NULL,
    checklist character varying(20) NOT NULL,
    status character varying(12) DEFAULT 'SCHEDULED'::character varying NOT NULL,
    result character varying(12),
    findings integer DEFAULT 0 NOT NULL,
    inspector character varying(80),
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT inspection_check CHECK ((((status)::text = 'SCHEDULED'::text) OR (result IS NOT NULL))),
    CONSTRAINT inspection_checklist_check CHECK (((checklist)::text = ANY ((ARRAY['APD'::character varying, 'ALAT_APUNG'::character varying, 'DECK'::character varying, 'RUMAH_MESIN'::character varying, 'HOUSEKEEPING'::character varying])::text[]))),
    CONSTRAINT inspection_result_check CHECK (((result)::text = ANY ((ARRAY['COMPLIANT'::character varying, 'FINDING'::character varying])::text[]))),
    CONSTRAINT inspection_status_check CHECK (((status)::text = ANY ((ARRAY['SCHEDULED'::character varying, 'DONE'::character varying])::text[])))
);


--
-- Name: inspection_inspection_id_seq; Type: SEQUENCE; Schema: hse; Owner: -
--

CREATE SEQUENCE hse.inspection_inspection_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: inspection_inspection_id_seq; Type: SEQUENCE OWNED BY; Schema: hse; Owner: -
--

ALTER SEQUENCE hse.inspection_inspection_id_seq OWNED BY hse.inspection.inspection_id;


--
-- Name: toolbox_meeting; Type: TABLE; Schema: hse; Owner: -
--

CREATE TABLE hse.toolbox_meeting (
    ttm_id bigint NOT NULL,
    unit_kode character varying(30) NOT NULL,
    period_week date NOT NULL,
    held boolean DEFAULT false NOT NULL,
    attendees integer,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: toolbox_meeting_ttm_id_seq; Type: SEQUENCE; Schema: hse; Owner: -
--

CREATE SEQUENCE hse.toolbox_meeting_ttm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: toolbox_meeting_ttm_id_seq; Type: SEQUENCE OWNED BY; Schema: hse; Owner: -
--

ALTER SEQUENCE hse.toolbox_meeting_ttm_id_seq OWNED BY hse.toolbox_meeting.ttm_id;


--
-- Name: email_outbox; Type: TABLE; Schema: notification; Owner: -
--

CREATE TABLE notification.email_outbox (
    outbox_id bigint NOT NULL,
    schedule_id bigint,
    slug text NOT NULL,
    no_dokumen text NOT NULL,
    recipients text NOT NULL,
    subject text NOT NULL,
    attachment_path text,
    status text DEFAULT 'QUEUED'::text NOT NULL,
    note text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    sent_at timestamp with time zone
);


--
-- Name: email_outbox_outbox_id_seq; Type: SEQUENCE; Schema: notification; Owner: -
--

CREATE SEQUENCE notification.email_outbox_outbox_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_outbox_outbox_id_seq; Type: SEQUENCE OWNED BY; Schema: notification; Owner: -
--

ALTER SEQUENCE notification.email_outbox_outbox_id_seq OWNED BY notification.email_outbox.outbox_id;


--
-- Name: log; Type: TABLE; Schema: notification; Owner: -
--

CREATE TABLE notification.log (
    notif_id bigint NOT NULL,
    rule_id bigint,
    channel character varying(10) NOT NULL,
    recipient character varying(200) NOT NULL,
    payload jsonb,
    status character varying(10) DEFAULT 'QUEUED'::character varying NOT NULL,
    sent_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT log_channel_check CHECK (((channel)::text = ANY ((ARRAY['TELEGRAM'::character varying, 'EMAIL'::character varying, 'WEB'::character varying])::text[]))),
    CONSTRAINT log_status_check CHECK (((status)::text = ANY ((ARRAY['QUEUED'::character varying, 'SENT'::character varying, 'FAILED'::character varying])::text[])))
);


--
-- Name: log_notif_id_seq; Type: SEQUENCE; Schema: notification; Owner: -
--

CREATE SEQUENCE notification.log_notif_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: log_notif_id_seq; Type: SEQUENCE OWNED BY; Schema: notification; Owner: -
--

ALTER SEQUENCE notification.log_notif_id_seq OWNED BY notification.log.notif_id;


--
-- Name: report_schedule; Type: TABLE; Schema: notification; Owner: -
--

CREATE TABLE notification.report_schedule (
    schedule_id bigint NOT NULL,
    slug text NOT NULL,
    recipients text NOT NULL,
    frekuensi text DEFAULT 'DAILY'::text NOT NULL,
    jam integer DEFAULT 7 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    last_sent_at timestamp with time zone,
    created_by text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: report_schedule_schedule_id_seq; Type: SEQUENCE; Schema: notification; Owner: -
--

CREATE SEQUENCE notification.report_schedule_schedule_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: report_schedule_schedule_id_seq; Type: SEQUENCE OWNED BY; Schema: notification; Owner: -
--

ALTER SEQUENCE notification.report_schedule_schedule_id_seq OWNED BY notification.report_schedule.schedule_id;


--
-- Name: rule; Type: TABLE; Schema: notification; Owner: -
--

CREATE TABLE notification.rule (
    rule_id bigint NOT NULL,
    event_type character varying(50) NOT NULL,
    template_ref character varying(100),
    recipients jsonb,
    escalation jsonb,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: rule_rule_id_seq; Type: SEQUENCE; Schema: notification; Owner: -
--

CREATE SEQUENCE notification.rule_rule_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rule_rule_id_seq; Type: SEQUENCE OWNED BY; Schema: notification; Owner: -
--

ALTER SEQUENCE notification.rule_rule_id_seq OWNED BY notification.rule.rule_id;


--
-- Name: discharge_event; Type: TABLE; Schema: operational; Owner: -
--

CREATE TABLE operational.discharge_event (
    event_id uuid DEFAULT gen_random_uuid() NOT NULL,
    trip_id bigint NOT NULL,
    event character varying(10) NOT NULL,
    event_at timestamp with time zone NOT NULL,
    reason character varying(20),
    note text,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT discharge_event_event_check CHECK (((event)::text = ANY ((ARRAY['START'::character varying, 'STOP'::character varying, 'RESUME'::character varying, 'COMPLETE'::character varying])::text[]))),
    CONSTRAINT discharge_event_reason_check CHECK (((reason)::text = ANY ((ARRAY['BREAKDOWN_KAPAL'::character varying, 'CUACA'::character varying, 'AREA_PENUH'::character varying, 'MASALAH_SITE'::character varying, 'LAINNYA'::character varying])::text[])))
);


--
-- Name: manual_report; Type: TABLE; Schema: operational; Owner: -
--

CREATE TABLE operational.manual_report (
    report_id uuid DEFAULT gen_random_uuid() NOT NULL,
    trip_id bigint NOT NULL,
    report_type character varying(20) NOT NULL,
    reported_at timestamp with time zone NOT NULL,
    reported_by character varying(150),
    payload jsonb,
    client_synced_at timestamp with time zone,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT manual_report_report_type_check CHECK (((report_type)::text = ANY ((ARRAY['BREAKDOWN'::character varying, 'OVERFLOW'::character varying, 'DEPTH'::character varying, 'WEATHER'::character varying, 'FUEL_STATUS'::character varying, 'OTHER'::character varying])::text[])))
);


--
-- Name: nor; Type: TABLE; Schema: operational; Owner: -
--

CREATE TABLE operational.nor (
    nor_id uuid DEFAULT gen_random_uuid() NOT NULL,
    trip_id bigint NOT NULL,
    declared_by character varying(150) NOT NULL,
    declared_at timestamp with time zone NOT NULL,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: schedule_plan; Type: TABLE; Schema: operational; Owner: -
--

CREATE TABLE operational.schedule_plan (
    plan_id bigint NOT NULL,
    trip_id bigint NOT NULL,
    planned_loading_start timestamp with time zone NOT NULL,
    planned_discharge_end timestamp with time zone NOT NULL,
    delta_jam numeric(10,2) DEFAULT 0 NOT NULL,
    status character varying(20) DEFAULT 'PROPOSED'::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_by character varying(50),
    approved_at timestamp with time zone,
    rejected_at timestamp with time zone,
    note text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT plan_status_check CHECK (((status)::text = ANY ((ARRAY['PROPOSED'::character varying, 'APPROVED'::character varying, 'REJECTED'::character varying])::text[])))
);


--
-- Name: schedule_plan_plan_id_seq; Type: SEQUENCE; Schema: operational; Owner: -
--

CREATE SEQUENCE operational.schedule_plan_plan_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: schedule_plan_plan_id_seq; Type: SEQUENCE OWNED BY; Schema: operational; Owner: -
--

ALTER SEQUENCE operational.schedule_plan_plan_id_seq OWNED BY operational.schedule_plan.plan_id;


--
-- Name: schedule_proposal; Type: TABLE; Schema: operational; Owner: -
--

CREATE TABLE operational.schedule_proposal (
    proposal_id bigint NOT NULL,
    payload jsonb NOT NULL,
    n_trip integer DEFAULT 0 NOT NULL,
    status text DEFAULT 'PENDING'::text NOT NULL,
    proposed_by text NOT NULL,
    proposed_at timestamp with time zone DEFAULT now() NOT NULL,
    decided_by text,
    decided_at timestamp with time zone,
    catatan text
);


--
-- Name: schedule_proposal_proposal_id_seq; Type: SEQUENCE; Schema: operational; Owner: -
--

CREATE SEQUENCE operational.schedule_proposal_proposal_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: schedule_proposal_proposal_id_seq; Type: SEQUENCE OWNED BY; Schema: operational; Owner: -
--

ALTER SEQUENCE operational.schedule_proposal_proposal_id_seq OWNED BY operational.schedule_proposal.proposal_id;


--
-- Name: shipment_instruction; Type: TABLE; Schema: operational; Owner: -
--

CREATE TABLE operational.shipment_instruction (
    si_id bigint NOT NULL,
    si_num character varying(30) NOT NULL,
    do_id bigint,
    issued_at timestamp with time zone DEFAULT now(),
    status character varying(20) DEFAULT 'ISSUED'::character varying
);


--
-- Name: shipment_instruction_si_id_seq; Type: SEQUENCE; Schema: operational; Owner: -
--

CREATE SEQUENCE operational.shipment_instruction_si_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: shipment_instruction_si_id_seq; Type: SEQUENCE OWNED BY; Schema: operational; Owner: -
--

ALTER SEQUENCE operational.shipment_instruction_si_id_seq OWNED BY operational.shipment_instruction.si_id;


--
-- Name: site_permit; Type: TABLE; Schema: operational; Owner: -
--

CREATE TABLE operational.site_permit (
    site_permit_id bigint NOT NULL,
    trip_id bigint NOT NULL,
    permit_no character varying(50),
    issuer character varying(150),
    issued_at timestamp with time zone,
    valid_until timestamp with time zone,
    note text,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: site_permit_site_permit_id_seq; Type: SEQUENCE; Schema: operational; Owner: -
--

CREATE SEQUENCE operational.site_permit_site_permit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: site_permit_site_permit_id_seq; Type: SEQUENCE OWNED BY; Schema: operational; Owner: -
--

ALTER SEQUENCE operational.site_permit_site_permit_id_seq OWNED BY operational.site_permit.site_permit_id;


--
-- Name: trip; Type: TABLE; Schema: operational; Owner: -
--

CREATE TABLE operational.trip (
    trip_id bigint NOT NULL,
    trip_no character varying(30) NOT NULL,
    si_num character varying(30) NOT NULL,
    fleet_code character varying(30) NOT NULL,
    work_area_code character varying(30),
    status character varying(20) NOT NULL,
    discharge_method character varying(20),
    ts_loading_start timestamp with time zone,
    ts_departed timestamp with time zone,
    ts_arrived timestamp with time zone,
    ts_discharge_start timestamp with time zone,
    ts_discharge_end timestamp with time zone,
    ts_bap_signed timestamp with time zone,
    ts_closed timestamp with time zone,
    volume_load_m3 numeric(14,3),
    volume_bap_m3 numeric(14,3),
    residual_m3 numeric(14,3),
    is_locked boolean DEFAULT false NOT NULL,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_trip_ts_order CHECK ((((ts_loading_start IS NULL) OR (ts_departed IS NULL) OR (ts_loading_start < ts_departed)) AND ((ts_departed IS NULL) OR (ts_arrived IS NULL) OR (ts_departed < ts_arrived)) AND ((ts_arrived IS NULL) OR (ts_discharge_start IS NULL) OR (ts_arrived < ts_discharge_start)) AND ((ts_discharge_start IS NULL) OR (ts_discharge_end IS NULL) OR (ts_discharge_start < ts_discharge_end)) AND ((ts_discharge_end IS NULL) OR (ts_bap_signed IS NULL) OR (ts_discharge_end < ts_bap_signed)) AND ((ts_bap_signed IS NULL) OR (ts_closed IS NULL) OR (ts_bap_signed < ts_closed)))),
    CONSTRAINT trip_discharge_method_check CHECK (((discharge_method)::text = ANY ((ARRAY['PUMP_ASHORE'::character varying, 'RAINBOWING'::character varying, 'BOTTOM_DUMP'::character varying, 'LAINNYA'::character varying])::text[]))),
    CONSTRAINT trip_status_check CHECK (((status)::text = ANY ((ARRAY['LOADING'::character varying, 'SURVEY_SETTLING'::character varying, 'DEPARTED'::character varying, 'ARRIVED'::character varying, 'SURVEY_DISCHARGE'::character varying, 'DISCHARGING'::character varying, 'BAP_RETURN'::character varying, 'INVOICED'::character varying, 'SETTLED'::character varying, 'CLOSED'::character varying, 'CANCELLED'::character varying, 'PARTIAL'::character varying, 'CLAIM'::character varying])::text[])))
);


--
-- Name: TABLE trip; Type: COMMENT; Schema: operational; Owner: -
--

COMMENT ON TABLE operational.trip IS 'Tulang punggung eksekusi (1—1 dengan SI); lifecycle 13 status; is_locked saat BAP sah (R10)';


--
-- Name: COLUMN trip.volume_bap_m3; Type: COMMENT; Schema: operational; Owner: -
--

COMMENT ON COLUMN operational.trip.volume_bap_m3 IS 'Volume final basis BAP (delivered) — sumber deposit, PNBP, hak partner (FR-06-01)';


--
-- Name: trip_trip_id_seq; Type: SEQUENCE; Schema: operational; Owner: -
--

CREATE SEQUENCE operational.trip_trip_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: trip_trip_id_seq; Type: SEQUENCE OWNED BY; Schema: operational; Owner: -
--

ALTER SEQUENCE operational.trip_trip_id_seq OWNED BY operational.trip.trip_id;


--
-- Name: waiting_log; Type: TABLE; Schema: operational; Owner: -
--

CREATE TABLE operational.waiting_log (
    waiting_id uuid DEFAULT gen_random_uuid() NOT NULL,
    trip_id bigint NOT NULL,
    start_at timestamp with time zone NOT NULL,
    end_at timestamp with time zone,
    cause character varying(20) NOT NULL,
    note text,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT waiting_log_cause_check CHECK (((cause)::text = ANY ((ARRAY['ANTRIAN_KAPAL'::character varying, 'IZIN_MASUK'::character varying, 'PASUT'::character varying, 'AREA_BELUM_SIAP'::character varying, 'CUACA'::character varying, 'DOKUMEN'::character varying, 'LAINNYA'::character varying])::text[])))
);


--
-- Name: work_area; Type: TABLE; Schema: operational; Owner: -
--

CREATE TABLE operational.work_area (
    area_code character varying(30) NOT NULL,
    area_name character varying(150) NOT NULL,
    area_type character varying(20) DEFAULT 'BLOK_KERUK'::character varying,
    status character varying(20) DEFAULT 'AKTIF'::character varying,
    permit_no character varying(50),
    quota_m3 numeric(14,3),
    quota_used_m3 numeric(14,3) DEFAULT 0,
    CONSTRAINT chk_work_area_quota_used CHECK (((quota_used_m3 IS NULL) OR (quota_used_m3 >= (0)::numeric)))
);


--
-- Name: audit_log; Type: TABLE; Schema: param; Owner: -
--

CREATE TABLE param.audit_log (
    audit_id bigint NOT NULL,
    tabel text NOT NULL,
    record_key text NOT NULL,
    kolom text NOT NULL,
    nilai_lama text,
    nilai_baru text,
    diubah_oleh text NOT NULL,
    diubah_pada timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: audit_log_audit_id_seq; Type: SEQUENCE; Schema: param; Owner: -
--

CREATE SEQUENCE param.audit_log_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_log_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: param; Owner: -
--

ALTER SEQUENCE param.audit_log_audit_id_seq OWNED BY param.audit_log.audit_id;


--
-- Name: currency; Type: TABLE; Schema: param; Owner: -
--

CREATE TABLE param.currency (
    currency_code character(3) NOT NULL,
    currency_name character varying(50)
);


--
-- Name: status; Type: TABLE; Schema: param; Owner: -
--

CREATE TABLE param.status (
    status_group character varying(30) NOT NULL,
    status_code character varying(30) NOT NULL,
    status_name character varying(150)
);


--
-- Name: system_parameter; Type: TABLE; Schema: param; Owner: -
--

CREATE TABLE param.system_parameter (
    param_key text NOT NULL,
    label text NOT NULL,
    nilai text NOT NULL,
    satuan text,
    keterangan text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT 'seed'::text NOT NULL
);


--
-- Name: charter_contract; Type: TABLE; Schema: partner; Owner: -
--

CREATE TABLE partner.charter_contract (
    charter_contract_id bigint NOT NULL,
    contract_no character varying(50) NOT NULL,
    partner_code character varying(30) NOT NULL,
    fleet_code character varying(30) NOT NULL,
    date_start date NOT NULL,
    date_end date,
    scheme character varying(10) NOT NULL,
    billing_schedule character varying(30),
    gps_starlink_clause text,
    status character varying(30) NOT NULL,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT charter_contract_scheme_check CHECK (((scheme)::text = ANY ((ARRAY['PER_M3'::character varying, 'PER_TRIP'::character varying, 'TC'::character varying])::text[]))),
    CONSTRAINT chk_cc_status CHECK (((status)::text = ANY ((ARRAY['DRAFT'::character varying, 'AKTIF'::character varying, 'EXPIRED'::character varying, 'TERMINATED'::character varying])::text[])))
);


--
-- Name: charter_contract_charter_contract_id_seq; Type: SEQUENCE; Schema: partner; Owner: -
--

CREATE SEQUENCE partner.charter_contract_charter_contract_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: charter_contract_charter_contract_id_seq; Type: SEQUENCE OWNED BY; Schema: partner; Owner: -
--

ALTER SEQUENCE partner.charter_contract_charter_contract_id_seq OWNED BY partner.charter_contract.charter_contract_id;


--
-- Name: info; Type: TABLE; Schema: partner; Owner: -
--

CREATE TABLE partner.info (
    partner_code character varying(30) NOT NULL,
    partner_name character varying(150) NOT NULL,
    partner_type character varying(20),
    contact character varying(150),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: invoice; Type: TABLE; Schema: partner; Owner: -
--

CREATE TABLE partner.invoice (
    partner_invoice_id bigint NOT NULL,
    partner_code character varying(30) NOT NULL,
    charter_contract_id bigint,
    invoice_no character varying(50) NOT NULL,
    received_at date NOT NULL,
    claimed_amount numeric(18,2) NOT NULL,
    matching_result character varying(10),
    diff_note text,
    matched_by character varying(30),
    matched_at timestamp with time zone,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT invoice_matching_result_check CHECK (((matching_result)::text = ANY ((ARRAY['MATCH'::character varying, 'DIFF'::character varying])::text[])))
);


--
-- Name: invoice_partner_invoice_id_seq; Type: SEQUENCE; Schema: partner; Owner: -
--

CREATE SEQUENCE partner.invoice_partner_invoice_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invoice_partner_invoice_id_seq; Type: SEQUENCE OWNED BY; Schema: partner; Owner: -
--

ALTER SEQUENCE partner.invoice_partner_invoice_id_seq OWNED BY partner.invoice.partner_invoice_id;


--
-- Name: payment; Type: TABLE; Schema: partner; Owner: -
--

CREATE TABLE partner.payment (
    payment_id bigint NOT NULL,
    partner_code character varying(30) NOT NULL,
    paid_at date NOT NULL,
    amount numeric(18,2) NOT NULL,
    method character varying(30),
    approved_by character varying(30),
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: payment_allocation; Type: TABLE; Schema: partner; Owner: -
--

CREATE TABLE partner.payment_allocation (
    payment_allocation_id bigint NOT NULL,
    payment_id bigint NOT NULL,
    statement_line_id bigint NOT NULL,
    amount numeric(18,2) NOT NULL
);


--
-- Name: payment_allocation_payment_allocation_id_seq; Type: SEQUENCE; Schema: partner; Owner: -
--

CREATE SEQUENCE partner.payment_allocation_payment_allocation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payment_allocation_payment_allocation_id_seq; Type: SEQUENCE OWNED BY; Schema: partner; Owner: -
--

ALTER SEQUENCE partner.payment_allocation_payment_allocation_id_seq OWNED BY partner.payment_allocation.payment_allocation_id;


--
-- Name: payment_payment_id_seq; Type: SEQUENCE; Schema: partner; Owner: -
--

CREATE SEQUENCE partner.payment_payment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payment_payment_id_seq; Type: SEQUENCE OWNED BY; Schema: partner; Owner: -
--

ALTER SEQUENCE partner.payment_payment_id_seq OWNED BY partner.payment.payment_id;


--
-- Name: rate_card; Type: TABLE; Schema: partner; Owner: -
--

CREATE TABLE partner.rate_card (
    rate_card_id bigint NOT NULL,
    charter_contract_id bigint NOT NULL,
    rate_per_m3 numeric(18,4),
    rate_per_trip numeric(18,2),
    tc_monthly_fee numeric(18,2),
    effective_from date NOT NULL,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: rate_card_rate_card_id_seq; Type: SEQUENCE; Schema: partner; Owner: -
--

CREATE SEQUENCE partner.rate_card_rate_card_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rate_card_rate_card_id_seq; Type: SEQUENCE OWNED BY; Schema: partner; Owner: -
--

ALTER SEQUENCE partner.rate_card_rate_card_id_seq OWNED BY partner.rate_card.rate_card_id;


--
-- Name: statement_line; Type: TABLE; Schema: partner; Owner: -
--

CREATE TABLE partner.statement_line (
    statement_line_id bigint NOT NULL,
    trip_id bigint NOT NULL,
    charter_contract_id bigint NOT NULL,
    rate_card_id bigint,
    scheme character varying(10) NOT NULL,
    volume_basis_m3 numeric(14,3) NOT NULL,
    rate numeric(18,4) NOT NULL,
    amount numeric(18,2) NOT NULL,
    payable_status character varying(10) DEFAULT 'WAITING'::character varying NOT NULL,
    trigger_event character varying(20),
    triggered_at timestamp with time zone,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_stmt_nonneg CHECK (((volume_basis_m3 >= (0)::numeric) AND (amount >= (0)::numeric))),
    CONSTRAINT statement_line_payable_status_check CHECK (((payable_status)::text = ANY ((ARRAY['WAITING'::character varying, 'TRIGGERED'::character varying, 'PAID'::character varying])::text[]))),
    CONSTRAINT statement_line_scheme_check CHECK (((scheme)::text = ANY ((ARRAY['PER_M3'::character varying, 'PER_TRIP'::character varying, 'TC'::character varying])::text[]))),
    CONSTRAINT statement_line_trigger_event_check CHECK (((trigger_event)::text = ANY ((ARRAY['DEPOSIT_DEDUCTED'::character varying, 'PO_COMPLETED'::character varying])::text[])))
);


--
-- Name: TABLE statement_line; Type: COMMENT; Schema: partner; Owner: -
--

COMMENT ON TABLE partner.statement_line IS 'Hak partner accrue per trip basis BAP; WAITING → TRIGGERED → PAID (FR-06-03, R2)';


--
-- Name: statement_line_statement_line_id_seq; Type: SEQUENCE; Schema: partner; Owner: -
--

CREATE SEQUENCE partner.statement_line_statement_line_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: statement_line_statement_line_id_seq; Type: SEQUENCE OWNED BY; Schema: partner; Owner: -
--

ALTER SEQUENCE partner.statement_line_statement_line_id_seq OWNED BY partner.statement_line.statement_line_id;


--
-- Name: info; Type: TABLE; Schema: site; Owner: -
--

CREATE TABLE site.info (
    site_code character varying(30) NOT NULL,
    site_name character varying(150) NOT NULL,
    owner_buyer_code character varying(30),
    location public.geometry(Point,4326),
    polygon public.geometry(Polygon,4326)
);


--
-- Name: draft_survey; Type: TABLE; Schema: survey; Owner: -
--

CREATE TABLE survey.draft_survey (
    draft_survey_id bigint NOT NULL,
    trip_id bigint NOT NULL,
    tipe character varying(15) NOT NULL,
    surveyor_name character varying(150) NOT NULL,
    surveyor_company character varying(150),
    surveyor_license character varying(50),
    surveyed_at timestamp with time zone NOT NULL,
    draft_readings jsonb NOT NULL,
    soundings jsonb,
    water_density numeric(8,5),
    material_density numeric(8,5),
    displacement_t numeric(14,3),
    corrections_t numeric(14,3),
    tonnage_t numeric(14,3),
    volume_m3 numeric(14,3) NOT NULL,
    witnesses jsonb,
    signed_at timestamp with time zone,
    doc_ref bigint,
    is_locked boolean DEFAULT false NOT NULL,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_ds_volume_nonneg CHECK ((volume_m3 >= (0)::numeric)),
    CONSTRAINT draft_survey_tipe_check CHECK (((tipe)::text = ANY ((ARRAY['MUAT'::character varying, 'AWAL_BONGKAR'::character varying, 'AKHIR_BONGKAR'::character varying])::text[])))
);


--
-- Name: TABLE draft_survey; Type: COMMENT; Schema: survey; Owner: -
--

COMMENT ON TABLE survey.draft_survey IS 'Volume resmi = hitungan sistem dari 6 titik draft + density diukur ulang (FR-04-06, v0.12)';


--
-- Name: COLUMN draft_survey.volume_m3; Type: COMMENT; Schema: survey; Owner: -
--

COMMENT ON COLUMN survey.draft_survey.volume_m3 IS 'Hitungan sistem — TIDAK boleh input manual';


--
-- Name: draft_survey_draft_survey_id_seq; Type: SEQUENCE; Schema: survey; Owner: -
--

CREATE SEQUENCE survey.draft_survey_draft_survey_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: draft_survey_draft_survey_id_seq; Type: SEQUENCE OWNED BY; Schema: survey; Owner: -
--

ALTER SEQUENCE survey.draft_survey_draft_survey_id_seq OWNED BY survey.draft_survey.draft_survey_id;


--
-- Name: ais_position; Type: TABLE; Schema: telemetry; Owner: -
--

CREATE TABLE telemetry.ais_position (
    position_id bigint NOT NULL,
    fleet_code character varying(30),
    mmsi character varying(20),
    lat double precision,
    lng double precision,
    speed_kn numeric(6,2),
    course_deg numeric(6,1),
    position_at timestamp with time zone NOT NULL
);


--
-- Name: ais_position_position_id_seq; Type: SEQUENCE; Schema: telemetry; Owner: -
--

CREATE SEQUENCE telemetry.ais_position_position_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ais_position_position_id_seq; Type: SEQUENCE OWNED BY; Schema: telemetry; Owner: -
--

ALTER SEQUENCE telemetry.ais_position_position_id_seq OWNED BY telemetry.ais_position.position_id;


--
-- Name: geofence; Type: TABLE; Schema: telemetry; Owner: -
--

CREATE TABLE telemetry.geofence (
    geofence_id bigint NOT NULL,
    fence_code character varying(50) NOT NULL,
    fence_name character varying(150),
    fence_type character varying(20),
    geom public.geometry(Polygon,4326) NOT NULL,
    radius_m numeric(12,2)
);


--
-- Name: geofence_event; Type: TABLE; Schema: telemetry; Owner: -
--

CREATE TABLE telemetry.geofence_event (
    event_id bigint NOT NULL,
    fleet_code character varying(30),
    geofence_id bigint,
    event character varying(10),
    event_at timestamp with time zone NOT NULL,
    CONSTRAINT geofence_event_event_check CHECK (((event)::text = ANY ((ARRAY['ENTRY'::character varying, 'EXIT'::character varying])::text[])))
);


--
-- Name: geofence_event_event_id_seq; Type: SEQUENCE; Schema: telemetry; Owner: -
--

CREATE SEQUENCE telemetry.geofence_event_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: geofence_event_event_id_seq; Type: SEQUENCE OWNED BY; Schema: telemetry; Owner: -
--

ALTER SEQUENCE telemetry.geofence_event_event_id_seq OWNED BY telemetry.geofence_event.event_id;


--
-- Name: geofence_geofence_id_seq; Type: SEQUENCE; Schema: telemetry; Owner: -
--

CREATE SEQUENCE telemetry.geofence_geofence_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: geofence_geofence_id_seq; Type: SEQUENCE OWNED BY; Schema: telemetry; Owner: -
--

ALTER SEQUENCE telemetry.geofence_geofence_id_seq OWNED BY telemetry.geofence.geofence_id;


--
-- Name: vessel_device; Type: TABLE; Schema: telemetry; Owner: -
--

CREATE TABLE telemetry.vessel_device (
    device_id integer NOT NULL,
    fleet_code character varying(12) NOT NULL,
    device_type character varying(12) NOT NULL,
    serial_no character varying(40) NOT NULL,
    installed_at date NOT NULL,
    last_ping_at timestamp with time zone,
    status character varying(12) DEFAULT 'ONLINE'::character varying NOT NULL,
    catatan character varying(120)
);


--
-- Name: vessel_device_device_id_seq; Type: SEQUENCE; Schema: telemetry; Owner: -
--

CREATE SEQUENCE telemetry.vessel_device_device_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: vessel_device_device_id_seq; Type: SEQUENCE OWNED BY; Schema: telemetry; Owner: -
--

ALTER SEQUENCE telemetry.vessel_device_device_id_seq OWNED BY telemetry.vessel_device.device_id;


--
-- Name: voyage; Type: TABLE; Schema: voyage; Owner: -
--

CREATE TABLE voyage.voyage (
    voyage_id bigint NOT NULL,
    fleet_code character varying(30) NOT NULL,
    trip_ref character varying(30),
    lat double precision NOT NULL,
    lng double precision NOT NULL,
    speed_kn numeric(6,2),
    heading_deg numeric(6,1),
    recorded_at timestamp with time zone NOT NULL
);


--
-- Name: voyage_voyage_id_seq; Type: SEQUENCE; Schema: voyage; Owner: -
--

CREATE SEQUENCE voyage.voyage_voyage_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: voyage_voyage_id_seq; Type: SEQUENCE OWNED BY; Schema: voyage; Owner: -
--

ALTER SEQUENCE voyage.voyage_voyage_id_seq OWNED BY voyage.voyage.voyage_id;


--
-- Name: deposit deposit_id; Type: DEFAULT; Schema: buyer; Owner: -
--

ALTER TABLE ONLY buyer.deposit ALTER COLUMN deposit_id SET DEFAULT nextval('buyer.deposit_deposit_id_seq'::regclass);


--
-- Name: deposit_transaction dep_trans_id; Type: DEFAULT; Schema: buyer; Owner: -
--

ALTER TABLE ONLY buyer.deposit_transaction ALTER COLUMN dep_trans_id SET DEFAULT nextval('buyer.deposit_transaction_dep_trans_id_seq'::regclass);


--
-- Name: ledger_hist id; Type: DEFAULT; Schema: buyer; Owner: -
--

ALTER TABLE ONLY buyer.ledger_hist ALTER COLUMN id SET DEFAULT nextval('buyer.ledger_hist_id_seq'::regclass);


--
-- Name: site buyer_site_id; Type: DEFAULT; Schema: buyer; Owner: -
--

ALTER TABLE ONLY buyer.site ALTER COLUMN buyer_site_id SET DEFAULT nextval('buyer.site_buyer_site_id_seq'::regclass);


--
-- Name: bap bap_id; Type: DEFAULT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.bap ALTER COLUMN bap_id SET DEFAULT nextval('commercial.bap_bap_id_seq'::regclass);


--
-- Name: bap_correction bap_correction_id; Type: DEFAULT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.bap_correction ALTER COLUMN bap_correction_id SET DEFAULT nextval('commercial.bap_correction_bap_correction_id_seq'::regclass);


--
-- Name: bap_objection bap_objection_id; Type: DEFAULT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.bap_objection ALTER COLUMN bap_objection_id SET DEFAULT nextval('commercial.bap_objection_bap_objection_id_seq'::regclass);


--
-- Name: delivery_order do_id; Type: DEFAULT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.delivery_order ALTER COLUMN do_id SET DEFAULT nextval('commercial.delivery_order_do_id_seq'::regclass);


--
-- Name: purchase_order po_id; Type: DEFAULT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.purchase_order ALTER COLUMN po_id SET DEFAULT nextval('commercial.purchase_order_po_id_seq'::regclass);


--
-- Name: sales_contract sales_contract_id; Type: DEFAULT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.sales_contract ALTER COLUMN sales_contract_id SET DEFAULT nextval('commercial.sales_contract_sales_contract_id_seq'::regclass);


--
-- Name: sand_spec sand_spec_id; Type: DEFAULT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.sand_spec ALTER COLUMN sand_spec_id SET DEFAULT nextval('commercial.sand_spec_sand_spec_id_seq'::regclass);


--
-- Name: standby_claim standby_claim_id; Type: DEFAULT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.standby_claim ALTER COLUMN standby_claim_id SET DEFAULT nextval('commercial.standby_claim_standby_claim_id_seq'::regclass);


--
-- Name: document document_id; Type: DEFAULT; Schema: document; Owner: -
--

ALTER TABLE ONLY document.document ALTER COLUMN document_id SET DEFAULT nextval('document.document_document_id_seq'::regclass);


--
-- Name: ews_event ews_event_id; Type: DEFAULT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.ews_event ALTER COLUMN ews_event_id SET DEFAULT nextval('enviro.ews_event_ews_event_id_seq'::regclass);


--
-- Name: mon_report mon_report_id; Type: DEFAULT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.mon_report ALTER COLUMN mon_report_id SET DEFAULT nextval('enviro.mon_report_mon_report_id_seq'::regclass);


--
-- Name: mon_schedule schedule_id; Type: DEFAULT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.mon_schedule ALTER COLUMN schedule_id SET DEFAULT nextval('enviro.mon_schedule_schedule_id_seq'::regclass);


--
-- Name: mon_work_order wo_id; Type: DEFAULT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.mon_work_order ALTER COLUMN wo_id SET DEFAULT nextval('enviro.mon_work_order_wo_id_seq'::regclass);


--
-- Name: reading_detail reading_detail_id; Type: DEFAULT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.reading_detail ALTER COLUMN reading_detail_id SET DEFAULT nextval('enviro.reading_detail_reading_detail_id_seq'::regclass);


--
-- Name: remediation remediation_id; Type: DEFAULT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.remediation ALTER COLUMN remediation_id SET DEFAULT nextval('enviro.remediation_remediation_id_seq'::regclass);


--
-- Name: cost_entry cost_entry_id; Type: DEFAULT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.cost_entry ALTER COLUMN cost_entry_id SET DEFAULT nextval('financial.cost_entry_cost_entry_id_seq'::regclass);


--
-- Name: invoice invoice_id; Type: DEFAULT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.invoice ALTER COLUMN invoice_id SET DEFAULT nextval('financial.invoice_invoice_id_seq'::regclass);


--
-- Name: journal journal_id; Type: DEFAULT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.journal ALTER COLUMN journal_id SET DEFAULT nextval('financial.journal_journal_id_seq'::regclass);


--
-- Name: journal_line journal_line_id; Type: DEFAULT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.journal_line ALTER COLUMN journal_line_id SET DEFAULT nextval('financial.journal_line_journal_line_id_seq'::regclass);


--
-- Name: pnbp_charge pnbp_charge_id; Type: DEFAULT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.pnbp_charge ALTER COLUMN pnbp_charge_id SET DEFAULT nextval('financial.pnbp_charge_pnbp_charge_id_seq'::regclass);


--
-- Name: pnbp_tahap_awal tahap_id; Type: DEFAULT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.pnbp_tahap_awal ALTER COLUMN tahap_id SET DEFAULT nextval('financial.pnbp_tahap_awal_tahap_id_seq'::regclass);


--
-- Name: pnbp_tarif tarif_id; Type: DEFAULT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.pnbp_tarif ALTER COLUMN tarif_id SET DEFAULT nextval('financial.pnbp_tarif_tarif_id_seq'::regclass);


--
-- Name: capa capa_id; Type: DEFAULT; Schema: hse; Owner: -
--

ALTER TABLE ONLY hse.capa ALTER COLUMN capa_id SET DEFAULT nextval('hse.capa_capa_id_seq'::regclass);


--
-- Name: certificate certificate_id; Type: DEFAULT; Schema: hse; Owner: -
--

ALTER TABLE ONLY hse.certificate ALTER COLUMN certificate_id SET DEFAULT nextval('hse.certificate_certificate_id_seq'::regclass);


--
-- Name: incident incident_id; Type: DEFAULT; Schema: hse; Owner: -
--

ALTER TABLE ONLY hse.incident ALTER COLUMN incident_id SET DEFAULT nextval('hse.incident_incident_id_seq'::regclass);


--
-- Name: induction induction_id; Type: DEFAULT; Schema: hse; Owner: -
--

ALTER TABLE ONLY hse.induction ALTER COLUMN induction_id SET DEFAULT nextval('hse.induction_induction_id_seq'::regclass);


--
-- Name: inspection inspection_id; Type: DEFAULT; Schema: hse; Owner: -
--

ALTER TABLE ONLY hse.inspection ALTER COLUMN inspection_id SET DEFAULT nextval('hse.inspection_inspection_id_seq'::regclass);


--
-- Name: toolbox_meeting ttm_id; Type: DEFAULT; Schema: hse; Owner: -
--

ALTER TABLE ONLY hse.toolbox_meeting ALTER COLUMN ttm_id SET DEFAULT nextval('hse.toolbox_meeting_ttm_id_seq'::regclass);


--
-- Name: email_outbox outbox_id; Type: DEFAULT; Schema: notification; Owner: -
--

ALTER TABLE ONLY notification.email_outbox ALTER COLUMN outbox_id SET DEFAULT nextval('notification.email_outbox_outbox_id_seq'::regclass);


--
-- Name: log notif_id; Type: DEFAULT; Schema: notification; Owner: -
--

ALTER TABLE ONLY notification.log ALTER COLUMN notif_id SET DEFAULT nextval('notification.log_notif_id_seq'::regclass);


--
-- Name: report_schedule schedule_id; Type: DEFAULT; Schema: notification; Owner: -
--

ALTER TABLE ONLY notification.report_schedule ALTER COLUMN schedule_id SET DEFAULT nextval('notification.report_schedule_schedule_id_seq'::regclass);


--
-- Name: rule rule_id; Type: DEFAULT; Schema: notification; Owner: -
--

ALTER TABLE ONLY notification.rule ALTER COLUMN rule_id SET DEFAULT nextval('notification.rule_rule_id_seq'::regclass);


--
-- Name: schedule_plan plan_id; Type: DEFAULT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.schedule_plan ALTER COLUMN plan_id SET DEFAULT nextval('operational.schedule_plan_plan_id_seq'::regclass);


--
-- Name: schedule_proposal proposal_id; Type: DEFAULT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.schedule_proposal ALTER COLUMN proposal_id SET DEFAULT nextval('operational.schedule_proposal_proposal_id_seq'::regclass);


--
-- Name: shipment_instruction si_id; Type: DEFAULT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.shipment_instruction ALTER COLUMN si_id SET DEFAULT nextval('operational.shipment_instruction_si_id_seq'::regclass);


--
-- Name: site_permit site_permit_id; Type: DEFAULT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.site_permit ALTER COLUMN site_permit_id SET DEFAULT nextval('operational.site_permit_site_permit_id_seq'::regclass);


--
-- Name: trip trip_id; Type: DEFAULT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.trip ALTER COLUMN trip_id SET DEFAULT nextval('operational.trip_trip_id_seq'::regclass);


--
-- Name: audit_log audit_id; Type: DEFAULT; Schema: param; Owner: -
--

ALTER TABLE ONLY param.audit_log ALTER COLUMN audit_id SET DEFAULT nextval('param.audit_log_audit_id_seq'::regclass);


--
-- Name: charter_contract charter_contract_id; Type: DEFAULT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.charter_contract ALTER COLUMN charter_contract_id SET DEFAULT nextval('partner.charter_contract_charter_contract_id_seq'::regclass);


--
-- Name: invoice partner_invoice_id; Type: DEFAULT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.invoice ALTER COLUMN partner_invoice_id SET DEFAULT nextval('partner.invoice_partner_invoice_id_seq'::regclass);


--
-- Name: payment payment_id; Type: DEFAULT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.payment ALTER COLUMN payment_id SET DEFAULT nextval('partner.payment_payment_id_seq'::regclass);


--
-- Name: payment_allocation payment_allocation_id; Type: DEFAULT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.payment_allocation ALTER COLUMN payment_allocation_id SET DEFAULT nextval('partner.payment_allocation_payment_allocation_id_seq'::regclass);


--
-- Name: rate_card rate_card_id; Type: DEFAULT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.rate_card ALTER COLUMN rate_card_id SET DEFAULT nextval('partner.rate_card_rate_card_id_seq'::regclass);


--
-- Name: statement_line statement_line_id; Type: DEFAULT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.statement_line ALTER COLUMN statement_line_id SET DEFAULT nextval('partner.statement_line_statement_line_id_seq'::regclass);


--
-- Name: draft_survey draft_survey_id; Type: DEFAULT; Schema: survey; Owner: -
--

ALTER TABLE ONLY survey.draft_survey ALTER COLUMN draft_survey_id SET DEFAULT nextval('survey.draft_survey_draft_survey_id_seq'::regclass);


--
-- Name: ais_position position_id; Type: DEFAULT; Schema: telemetry; Owner: -
--

ALTER TABLE ONLY telemetry.ais_position ALTER COLUMN position_id SET DEFAULT nextval('telemetry.ais_position_position_id_seq'::regclass);


--
-- Name: geofence geofence_id; Type: DEFAULT; Schema: telemetry; Owner: -
--

ALTER TABLE ONLY telemetry.geofence ALTER COLUMN geofence_id SET DEFAULT nextval('telemetry.geofence_geofence_id_seq'::regclass);


--
-- Name: geofence_event event_id; Type: DEFAULT; Schema: telemetry; Owner: -
--

ALTER TABLE ONLY telemetry.geofence_event ALTER COLUMN event_id SET DEFAULT nextval('telemetry.geofence_event_event_id_seq'::regclass);


--
-- Name: vessel_device device_id; Type: DEFAULT; Schema: telemetry; Owner: -
--

ALTER TABLE ONLY telemetry.vessel_device ALTER COLUMN device_id SET DEFAULT nextval('telemetry.vessel_device_device_id_seq'::regclass);


--
-- Name: voyage voyage_id; Type: DEFAULT; Schema: voyage; Owner: -
--

ALTER TABLE ONLY voyage.voyage ALTER COLUMN voyage_id SET DEFAULT nextval('voyage.voyage_voyage_id_seq'::regclass);


--
-- Name: deposit deposit_pkey; Type: CONSTRAINT; Schema: buyer; Owner: -
--

ALTER TABLE ONLY buyer.deposit
    ADD CONSTRAINT deposit_pkey PRIMARY KEY (deposit_id);


--
-- Name: deposit deposit_sales_contract_id_key; Type: CONSTRAINT; Schema: buyer; Owner: -
--

ALTER TABLE ONLY buyer.deposit
    ADD CONSTRAINT deposit_sales_contract_id_key UNIQUE (sales_contract_id);


--
-- Name: deposit_transaction deposit_transaction_pkey; Type: CONSTRAINT; Schema: buyer; Owner: -
--

ALTER TABLE ONLY buyer.deposit_transaction
    ADD CONSTRAINT deposit_transaction_pkey PRIMARY KEY (dep_trans_id);


--
-- Name: info info_pkey; Type: CONSTRAINT; Schema: buyer; Owner: -
--

ALTER TABLE ONLY buyer.info
    ADD CONSTRAINT info_pkey PRIMARY KEY (buyer_code);


--
-- Name: ledger_hist ledger_hist_pkey; Type: CONSTRAINT; Schema: buyer; Owner: -
--

ALTER TABLE ONLY buyer.ledger_hist
    ADD CONSTRAINT ledger_hist_pkey PRIMARY KEY (id);


--
-- Name: site site_pkey; Type: CONSTRAINT; Schema: buyer; Owner: -
--

ALTER TABLE ONLY buyer.site
    ADD CONSTRAINT site_pkey PRIMARY KEY (buyer_site_id);


--
-- Name: bap bap_bap_no_key; Type: CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.bap
    ADD CONSTRAINT bap_bap_no_key UNIQUE (bap_no);


--
-- Name: bap_correction bap_correction_correction_no_key; Type: CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.bap_correction
    ADD CONSTRAINT bap_correction_correction_no_key UNIQUE (correction_no);


--
-- Name: bap_correction bap_correction_pkey; Type: CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.bap_correction
    ADD CONSTRAINT bap_correction_pkey PRIMARY KEY (bap_correction_id);


--
-- Name: bap_objection bap_objection_pkey; Type: CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.bap_objection
    ADD CONSTRAINT bap_objection_pkey PRIMARY KEY (bap_objection_id);


--
-- Name: bap bap_pkey; Type: CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.bap
    ADD CONSTRAINT bap_pkey PRIMARY KEY (bap_id);


--
-- Name: delivery_order delivery_order_do_no_key; Type: CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.delivery_order
    ADD CONSTRAINT delivery_order_do_no_key UNIQUE (do_no);


--
-- Name: delivery_order delivery_order_pkey; Type: CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.delivery_order
    ADD CONSTRAINT delivery_order_pkey PRIMARY KEY (do_id);


--
-- Name: purchase_order purchase_order_pkey; Type: CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.purchase_order
    ADD CONSTRAINT purchase_order_pkey PRIMARY KEY (po_id);


--
-- Name: purchase_order purchase_order_po_no_key; Type: CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.purchase_order
    ADD CONSTRAINT purchase_order_po_no_key UNIQUE (po_no);


--
-- Name: qa_sample qa_sample_pkey; Type: CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.qa_sample
    ADD CONSTRAINT qa_sample_pkey PRIMARY KEY (qa_sample_id);


--
-- Name: sales_contract sales_contract_contract_no_key; Type: CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.sales_contract
    ADD CONSTRAINT sales_contract_contract_no_key UNIQUE (contract_no);


--
-- Name: sales_contract sales_contract_pkey; Type: CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.sales_contract
    ADD CONSTRAINT sales_contract_pkey PRIMARY KEY (sales_contract_id);


--
-- Name: sand_spec sand_spec_pkey; Type: CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.sand_spec
    ADD CONSTRAINT sand_spec_pkey PRIMARY KEY (sand_spec_id);


--
-- Name: standby_claim standby_claim_pkey; Type: CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.standby_claim
    ADD CONSTRAINT standby_claim_pkey PRIMARY KEY (standby_claim_id);


--
-- Name: standby_claim standby_claim_trip_id_key; Type: CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.standby_claim
    ADD CONSTRAINT standby_claim_trip_id_key UNIQUE (trip_id);


--
-- Name: qa_sample uq_qa_trip_tipe; Type: CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.qa_sample
    ADD CONSTRAINT uq_qa_trip_tipe UNIQUE (trip_id, tipe);


--
-- Name: document document_doc_key_key; Type: CONSTRAINT; Schema: document; Owner: -
--

ALTER TABLE ONLY document.document
    ADD CONSTRAINT document_doc_key_key UNIQUE (doc_key);


--
-- Name: document_link document_link_pkey; Type: CONSTRAINT; Schema: document; Owner: -
--

ALTER TABLE ONLY document.document_link
    ADD CONSTRAINT document_link_pkey PRIMARY KEY (document_id, entity_type, entity_id);


--
-- Name: document document_pkey; Type: CONSTRAINT; Schema: document; Owner: -
--

ALTER TABLE ONLY document.document
    ADD CONSTRAINT document_pkey PRIMARY KEY (document_id);


--
-- Name: ews_event ews_event_pkey; Type: CONSTRAINT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.ews_event
    ADD CONSTRAINT ews_event_pkey PRIMARY KEY (ews_event_id);


--
-- Name: mon_parameter mon_parameter_pkey; Type: CONSTRAINT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.mon_parameter
    ADD CONSTRAINT mon_parameter_pkey PRIMARY KEY (parameter_code);


--
-- Name: mon_report mon_report_pkey; Type: CONSTRAINT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.mon_report
    ADD CONSTRAINT mon_report_pkey PRIMARY KEY (mon_report_id);


--
-- Name: mon_schedule mon_schedule_pkey; Type: CONSTRAINT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.mon_schedule
    ADD CONSTRAINT mon_schedule_pkey PRIMARY KEY (schedule_id);


--
-- Name: mon_work_order mon_work_order_pkey; Type: CONSTRAINT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.mon_work_order
    ADD CONSTRAINT mon_work_order_pkey PRIMARY KEY (wo_id);


--
-- Name: mon_work_order mon_work_order_wo_no_key; Type: CONSTRAINT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.mon_work_order
    ADD CONSTRAINT mon_work_order_wo_no_key UNIQUE (wo_no);


--
-- Name: reading_detail reading_detail_pkey; Type: CONSTRAINT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.reading_detail
    ADD CONSTRAINT reading_detail_pkey PRIMARY KEY (reading_detail_id);


--
-- Name: remediation remediation_pkey; Type: CONSTRAINT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.remediation
    ADD CONSTRAINT remediation_pkey PRIMARY KEY (remediation_id);


--
-- Name: station station_pkey; Type: CONSTRAINT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.station
    ADD CONSTRAINT station_pkey PRIMARY KEY (station_code);


--
-- Name: mon_report uq_mon_report_period_type; Type: CONSTRAINT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.mon_report
    ADD CONSTRAINT uq_mon_report_period_type UNIQUE (period, report_type);


--
-- Name: mon_schedule uq_mon_schedule_pair; Type: CONSTRAINT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.mon_schedule
    ADD CONSTRAINT uq_mon_schedule_pair UNIQUE (station_code, parameter_code);


--
-- Name: reading_detail uq_reading_batch; Type: CONSTRAINT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.reading_detail
    ADD CONSTRAINT uq_reading_batch UNIQUE (station_code, parameter_code, record_time, source);


--
-- Name: invoice chk_invoice_party; Type: CHECK CONSTRAINT; Schema: financial; Owner: -
--

ALTER TABLE financial.invoice
    ADD CONSTRAINT chk_invoice_party CHECK (((((invoice_type)::text = 'SALES'::text) AND (buyer_code IS NOT NULL)) OR (((invoice_type)::text = 'PURCHASE'::text) AND (partner_code IS NOT NULL)))) NOT VALID;


--
-- Name: cost_entry cost_entry_pkey; Type: CONSTRAINT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.cost_entry
    ADD CONSTRAINT cost_entry_pkey PRIMARY KEY (cost_entry_id);


--
-- Name: invoice invoice_invoice_no_key; Type: CONSTRAINT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.invoice
    ADD CONSTRAINT invoice_invoice_no_key UNIQUE (invoice_no);


--
-- Name: invoice invoice_pkey; Type: CONSTRAINT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.invoice
    ADD CONSTRAINT invoice_pkey PRIMARY KEY (invoice_id);


--
-- Name: journal journal_journal_no_key; Type: CONSTRAINT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.journal
    ADD CONSTRAINT journal_journal_no_key UNIQUE (journal_no);


--
-- Name: journal_line journal_line_journal_id_line_no_key; Type: CONSTRAINT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.journal_line
    ADD CONSTRAINT journal_line_journal_id_line_no_key UNIQUE (journal_id, line_no);


--
-- Name: journal_line journal_line_pkey; Type: CONSTRAINT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.journal_line
    ADD CONSTRAINT journal_line_pkey PRIMARY KEY (journal_line_id);


--
-- Name: journal journal_pkey; Type: CONSTRAINT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.journal
    ADD CONSTRAINT journal_pkey PRIMARY KEY (journal_id);


--
-- Name: pnbp_charge pnbp_charge_pkey; Type: CONSTRAINT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.pnbp_charge
    ADD CONSTRAINT pnbp_charge_pkey PRIMARY KEY (pnbp_charge_id);


--
-- Name: pnbp_charge pnbp_charge_trip_id_key; Type: CONSTRAINT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.pnbp_charge
    ADD CONSTRAINT pnbp_charge_trip_id_key UNIQUE (trip_id);


--
-- Name: pnbp_tahap_awal pnbp_tahap_awal_pkey; Type: CONSTRAINT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.pnbp_tahap_awal
    ADD CONSTRAINT pnbp_tahap_awal_pkey PRIMARY KEY (tahap_id);


--
-- Name: pnbp_tarif pnbp_tarif_kategori_key; Type: CONSTRAINT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.pnbp_tarif
    ADD CONSTRAINT pnbp_tarif_kategori_key UNIQUE (kategori);


--
-- Name: pnbp_tarif pnbp_tarif_pkey; Type: CONSTRAINT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.pnbp_tarif
    ADD CONSTRAINT pnbp_tarif_pkey PRIMARY KEY (tarif_id);


--
-- Name: cost_entry uq_cost_trip_category; Type: CONSTRAINT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.cost_entry
    ADD CONSTRAINT uq_cost_trip_category UNIQUE (trip_id, category);


--
-- Name: info info_pkey; Type: CONSTRAINT; Schema: fleet; Owner: -
--

ALTER TABLE ONLY fleet.info
    ADD CONSTRAINT info_pkey PRIMARY KEY (fleet_code);


--
-- Name: capa capa_capa_no_key; Type: CONSTRAINT; Schema: hse; Owner: -
--

ALTER TABLE ONLY hse.capa
    ADD CONSTRAINT capa_capa_no_key UNIQUE (capa_no);


--
-- Name: capa capa_pkey; Type: CONSTRAINT; Schema: hse; Owner: -
--

ALTER TABLE ONLY hse.capa
    ADD CONSTRAINT capa_pkey PRIMARY KEY (capa_id);


--
-- Name: certificate certificate_pkey; Type: CONSTRAINT; Schema: hse; Owner: -
--

ALTER TABLE ONLY hse.certificate
    ADD CONSTRAINT certificate_pkey PRIMARY KEY (certificate_id);


--
-- Name: incident incident_incident_no_key; Type: CONSTRAINT; Schema: hse; Owner: -
--

ALTER TABLE ONLY hse.incident
    ADD CONSTRAINT incident_incident_no_key UNIQUE (incident_no);


--
-- Name: incident incident_pkey; Type: CONSTRAINT; Schema: hse; Owner: -
--

ALTER TABLE ONLY hse.incident
    ADD CONSTRAINT incident_pkey PRIMARY KEY (incident_id);


--
-- Name: induction induction_pkey; Type: CONSTRAINT; Schema: hse; Owner: -
--

ALTER TABLE ONLY hse.induction
    ADD CONSTRAINT induction_pkey PRIMARY KEY (induction_id);


--
-- Name: inspection inspection_inspection_no_key; Type: CONSTRAINT; Schema: hse; Owner: -
--

ALTER TABLE ONLY hse.inspection
    ADD CONSTRAINT inspection_inspection_no_key UNIQUE (inspection_no);


--
-- Name: inspection inspection_pkey; Type: CONSTRAINT; Schema: hse; Owner: -
--

ALTER TABLE ONLY hse.inspection
    ADD CONSTRAINT inspection_pkey PRIMARY KEY (inspection_id);


--
-- Name: toolbox_meeting toolbox_meeting_pkey; Type: CONSTRAINT; Schema: hse; Owner: -
--

ALTER TABLE ONLY hse.toolbox_meeting
    ADD CONSTRAINT toolbox_meeting_pkey PRIMARY KEY (ttm_id);


--
-- Name: toolbox_meeting toolbox_meeting_unit_kode_period_week_key; Type: CONSTRAINT; Schema: hse; Owner: -
--

ALTER TABLE ONLY hse.toolbox_meeting
    ADD CONSTRAINT toolbox_meeting_unit_kode_period_week_key UNIQUE (unit_kode, period_week);


--
-- Name: email_outbox email_outbox_pkey; Type: CONSTRAINT; Schema: notification; Owner: -
--

ALTER TABLE ONLY notification.email_outbox
    ADD CONSTRAINT email_outbox_pkey PRIMARY KEY (outbox_id);


--
-- Name: log log_pkey; Type: CONSTRAINT; Schema: notification; Owner: -
--

ALTER TABLE ONLY notification.log
    ADD CONSTRAINT log_pkey PRIMARY KEY (notif_id);


--
-- Name: report_schedule report_schedule_pkey; Type: CONSTRAINT; Schema: notification; Owner: -
--

ALTER TABLE ONLY notification.report_schedule
    ADD CONSTRAINT report_schedule_pkey PRIMARY KEY (schedule_id);


--
-- Name: rule rule_event_type_key; Type: CONSTRAINT; Schema: notification; Owner: -
--

ALTER TABLE ONLY notification.rule
    ADD CONSTRAINT rule_event_type_key UNIQUE (event_type);


--
-- Name: rule rule_pkey; Type: CONSTRAINT; Schema: notification; Owner: -
--

ALTER TABLE ONLY notification.rule
    ADD CONSTRAINT rule_pkey PRIMARY KEY (rule_id);


--
-- Name: discharge_event discharge_event_pkey; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.discharge_event
    ADD CONSTRAINT discharge_event_pkey PRIMARY KEY (event_id);


--
-- Name: manual_report manual_report_pkey; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.manual_report
    ADD CONSTRAINT manual_report_pkey PRIMARY KEY (report_id);


--
-- Name: nor nor_pkey; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.nor
    ADD CONSTRAINT nor_pkey PRIMARY KEY (nor_id);


--
-- Name: nor nor_trip_id_key; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.nor
    ADD CONSTRAINT nor_trip_id_key UNIQUE (trip_id);


--
-- Name: schedule_plan schedule_plan_pkey; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.schedule_plan
    ADD CONSTRAINT schedule_plan_pkey PRIMARY KEY (plan_id);


--
-- Name: schedule_proposal schedule_proposal_pkey; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.schedule_proposal
    ADD CONSTRAINT schedule_proposal_pkey PRIMARY KEY (proposal_id);


--
-- Name: shipment_instruction shipment_instruction_pkey; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.shipment_instruction
    ADD CONSTRAINT shipment_instruction_pkey PRIMARY KEY (si_id);


--
-- Name: shipment_instruction shipment_instruction_si_num_key; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.shipment_instruction
    ADD CONSTRAINT shipment_instruction_si_num_key UNIQUE (si_num);


--
-- Name: site_permit site_permit_pkey; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.site_permit
    ADD CONSTRAINT site_permit_pkey PRIMARY KEY (site_permit_id);


--
-- Name: trip trip_pkey; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.trip
    ADD CONSTRAINT trip_pkey PRIMARY KEY (trip_id);


--
-- Name: trip trip_si_num_key; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.trip
    ADD CONSTRAINT trip_si_num_key UNIQUE (si_num);


--
-- Name: trip trip_trip_no_key; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.trip
    ADD CONSTRAINT trip_trip_no_key UNIQUE (trip_no);


--
-- Name: waiting_log waiting_log_pkey; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.waiting_log
    ADD CONSTRAINT waiting_log_pkey PRIMARY KEY (waiting_id);


--
-- Name: work_area work_area_pkey; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.work_area
    ADD CONSTRAINT work_area_pkey PRIMARY KEY (area_code);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: param; Owner: -
--

ALTER TABLE ONLY param.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (audit_id);


--
-- Name: currency currency_pkey; Type: CONSTRAINT; Schema: param; Owner: -
--

ALTER TABLE ONLY param.currency
    ADD CONSTRAINT currency_pkey PRIMARY KEY (currency_code);


--
-- Name: status status_pkey; Type: CONSTRAINT; Schema: param; Owner: -
--

ALTER TABLE ONLY param.status
    ADD CONSTRAINT status_pkey PRIMARY KEY (status_group, status_code);


--
-- Name: system_parameter system_parameter_pkey; Type: CONSTRAINT; Schema: param; Owner: -
--

ALTER TABLE ONLY param.system_parameter
    ADD CONSTRAINT system_parameter_pkey PRIMARY KEY (param_key);


--
-- Name: charter_contract charter_contract_contract_no_key; Type: CONSTRAINT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.charter_contract
    ADD CONSTRAINT charter_contract_contract_no_key UNIQUE (contract_no);


--
-- Name: charter_contract charter_contract_pkey; Type: CONSTRAINT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.charter_contract
    ADD CONSTRAINT charter_contract_pkey PRIMARY KEY (charter_contract_id);


--
-- Name: info info_pkey; Type: CONSTRAINT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.info
    ADD CONSTRAINT info_pkey PRIMARY KEY (partner_code);


--
-- Name: invoice invoice_invoice_no_key; Type: CONSTRAINT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.invoice
    ADD CONSTRAINT invoice_invoice_no_key UNIQUE (invoice_no);


--
-- Name: invoice invoice_pkey; Type: CONSTRAINT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.invoice
    ADD CONSTRAINT invoice_pkey PRIMARY KEY (partner_invoice_id);


--
-- Name: payment_allocation payment_allocation_pkey; Type: CONSTRAINT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.payment_allocation
    ADD CONSTRAINT payment_allocation_pkey PRIMARY KEY (payment_allocation_id);


--
-- Name: payment payment_pkey; Type: CONSTRAINT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.payment
    ADD CONSTRAINT payment_pkey PRIMARY KEY (payment_id);


--
-- Name: rate_card rate_card_pkey; Type: CONSTRAINT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.rate_card
    ADD CONSTRAINT rate_card_pkey PRIMARY KEY (rate_card_id);


--
-- Name: statement_line statement_line_pkey; Type: CONSTRAINT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.statement_line
    ADD CONSTRAINT statement_line_pkey PRIMARY KEY (statement_line_id);


--
-- Name: payment_allocation uq_alloc_payment_statement; Type: CONSTRAINT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.payment_allocation
    ADD CONSTRAINT uq_alloc_payment_statement UNIQUE (payment_id, statement_line_id);


--
-- Name: rate_card uq_rate_card_contract_eff; Type: CONSTRAINT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.rate_card
    ADD CONSTRAINT uq_rate_card_contract_eff UNIQUE (charter_contract_id, effective_from);


--
-- Name: info info_pkey; Type: CONSTRAINT; Schema: site; Owner: -
--

ALTER TABLE ONLY site.info
    ADD CONSTRAINT info_pkey PRIMARY KEY (site_code);


--
-- Name: draft_survey draft_survey_pkey; Type: CONSTRAINT; Schema: survey; Owner: -
--

ALTER TABLE ONLY survey.draft_survey
    ADD CONSTRAINT draft_survey_pkey PRIMARY KEY (draft_survey_id);


--
-- Name: draft_survey uq_survey_trip_tipe; Type: CONSTRAINT; Schema: survey; Owner: -
--

ALTER TABLE ONLY survey.draft_survey
    ADD CONSTRAINT uq_survey_trip_tipe UNIQUE (trip_id, tipe);


--
-- Name: ais_position ais_position_pkey; Type: CONSTRAINT; Schema: telemetry; Owner: -
--

ALTER TABLE ONLY telemetry.ais_position
    ADD CONSTRAINT ais_position_pkey PRIMARY KEY (position_id);


--
-- Name: geofence_event geofence_event_pkey; Type: CONSTRAINT; Schema: telemetry; Owner: -
--

ALTER TABLE ONLY telemetry.geofence_event
    ADD CONSTRAINT geofence_event_pkey PRIMARY KEY (event_id);


--
-- Name: geofence geofence_fence_code_key; Type: CONSTRAINT; Schema: telemetry; Owner: -
--

ALTER TABLE ONLY telemetry.geofence
    ADD CONSTRAINT geofence_fence_code_key UNIQUE (fence_code);


--
-- Name: geofence geofence_pkey; Type: CONSTRAINT; Schema: telemetry; Owner: -
--

ALTER TABLE ONLY telemetry.geofence
    ADD CONSTRAINT geofence_pkey PRIMARY KEY (geofence_id);


--
-- Name: vessel_device vessel_device_pkey; Type: CONSTRAINT; Schema: telemetry; Owner: -
--

ALTER TABLE ONLY telemetry.vessel_device
    ADD CONSTRAINT vessel_device_pkey PRIMARY KEY (device_id);


--
-- Name: voyage voyage_pkey; Type: CONSTRAINT; Schema: voyage; Owner: -
--

ALTER TABLE ONLY voyage.voyage
    ADD CONSTRAINT voyage_pkey PRIMARY KEY (voyage_id);


--
-- Name: idx_dt_deposit; Type: INDEX; Schema: buyer; Owner: -
--

CREATE INDEX idx_dt_deposit ON buyer.deposit_transaction USING btree (deposit_id, tx_date);


--
-- Name: idx_dt_trip; Type: INDEX; Schema: buyer; Owner: -
--

CREATE INDEX idx_dt_trip ON buyer.deposit_transaction USING btree (trip_id);


--
-- Name: idx_bap_status; Type: INDEX; Schema: commercial; Owner: -
--

CREATE INDEX idx_bap_status ON commercial.bap USING btree (status);


--
-- Name: idx_bap_trip; Type: INDEX; Schema: commercial; Owner: -
--

CREATE INDEX idx_bap_trip ON commercial.bap USING btree (trip_id);


--
-- Name: idx_bo_bap; Type: INDEX; Schema: commercial; Owner: -
--

CREATE INDEX idx_bo_bap ON commercial.bap_objection USING btree (bap_id);


--
-- Name: idx_do_fleet; Type: INDEX; Schema: commercial; Owner: -
--

CREATE INDEX idx_do_fleet ON commercial.delivery_order USING btree (fleet_code);


--
-- Name: idx_po_sales_contract; Type: INDEX; Schema: commercial; Owner: -
--

CREATE INDEX idx_po_sales_contract ON commercial.purchase_order USING btree (sales_contract_id);


--
-- Name: idx_qs_trip; Type: INDEX; Schema: commercial; Owner: -
--

CREATE INDEX idx_qs_trip ON commercial.qa_sample USING btree (trip_id);


--
-- Name: idx_sc_buyer; Type: INDEX; Schema: commercial; Owner: -
--

CREATE INDEX idx_sc_buyer ON commercial.sales_contract USING btree (buyer_code);


--
-- Name: idx_sc_status; Type: INDEX; Schema: commercial; Owner: -
--

CREATE INDEX idx_sc_status ON commercial.sales_contract USING btree (status);


--
-- Name: idx_document_entity; Type: INDEX; Schema: document; Owner: -
--

CREATE INDEX idx_document_entity ON document.document USING btree (entity_type, entity_id);


--
-- Name: idx_document_link_entity; Type: INDEX; Schema: document; Owner: -
--

CREATE INDEX idx_document_link_entity ON document.document_link USING btree (entity_type, entity_id);


--
-- Name: uq_document_link_primary; Type: INDEX; Schema: document; Owner: -
--

CREATE UNIQUE INDEX uq_document_link_primary ON document.document_link USING btree (entity_type, entity_id) WHERE is_primary;


--
-- Name: idx_ews_created; Type: INDEX; Schema: enviro; Owner: -
--

CREATE INDEX idx_ews_created ON enviro.ews_event USING btree (created_at);


--
-- Name: idx_ews_station; Type: INDEX; Schema: enviro; Owner: -
--

CREATE INDEX idx_ews_station ON enviro.ews_event USING btree (station_code);


--
-- Name: idx_mr_period; Type: INDEX; Schema: enviro; Owner: -
--

CREATE INDEX idx_mr_period ON enviro.mon_report USING btree (period);


--
-- Name: idx_ms_next; Type: INDEX; Schema: enviro; Owner: -
--

CREATE INDEX idx_ms_next ON enviro.mon_schedule USING btree (next_due);


--
-- Name: idx_mwo_status; Type: INDEX; Schema: enviro; Owner: -
--

CREATE INDEX idx_mwo_status ON enviro.mon_work_order USING btree (status);


--
-- Name: idx_reading_detail_param_time; Type: INDEX; Schema: enviro; Owner: -
--

CREATE INDEX idx_reading_detail_param_time ON enviro.reading_detail USING btree (parameter_code, record_time DESC);


--
-- Name: idx_reading_detail_station_time; Type: INDEX; Schema: enviro; Owner: -
--

CREATE INDEX idx_reading_detail_station_time ON enviro.reading_detail USING btree (station_code, record_time DESC);


--
-- Name: idx_rem_status; Type: INDEX; Schema: enviro; Owner: -
--

CREATE INDEX idx_rem_status ON enviro.remediation USING btree (status);


--
-- Name: idx_ce_trip; Type: INDEX; Schema: financial; Owner: -
--

CREATE INDEX idx_ce_trip ON financial.cost_entry USING btree (trip_id);


--
-- Name: idx_invoice_buyer; Type: INDEX; Schema: financial; Owner: -
--

CREATE INDEX idx_invoice_buyer ON financial.invoice USING btree (buyer_code);


--
-- Name: idx_pnbp_status; Type: INDEX; Schema: financial; Owner: -
--

CREATE INDEX idx_pnbp_status ON financial.pnbp_charge USING btree (status);


--
-- Name: idx_notiflog_rule; Type: INDEX; Schema: notification; Owner: -
--

CREATE INDEX idx_notiflog_rule ON notification.log USING btree (rule_id);


--
-- Name: idx_notiflog_status; Type: INDEX; Schema: notification; Owner: -
--

CREATE INDEX idx_notiflog_status ON notification.log USING btree (status);


--
-- Name: idx_de_trip; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX idx_de_trip ON operational.discharge_event USING btree (trip_id, event_at);


--
-- Name: idx_mr_trip; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX idx_mr_trip ON operational.manual_report USING btree (trip_id, reported_at);


--
-- Name: idx_trip_fleet; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX idx_trip_fleet ON operational.trip USING btree (fleet_code);


--
-- Name: idx_trip_status; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX idx_trip_status ON operational.trip USING btree (status) WHERE ((status)::text <> ALL ((ARRAY['CLOSED'::character varying, 'CANCELLED'::character varying])::text[]));


--
-- Name: idx_wl_trip; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX idx_wl_trip ON operational.waiting_log USING btree (trip_id, start_at);


--
-- Name: idx_work_area_permit; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX idx_work_area_permit ON operational.work_area USING btree (permit_no);


--
-- Name: ix_plan_trip; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX ix_plan_trip ON operational.schedule_plan USING btree (trip_id);


--
-- Name: uq_plan_aktif_per_trip; Type: INDEX; Schema: operational; Owner: -
--

CREATE UNIQUE INDEX uq_plan_aktif_per_trip ON operational.schedule_plan USING btree (trip_id) WHERE is_active;


--
-- Name: idx_cc_fleet; Type: INDEX; Schema: partner; Owner: -
--

CREATE INDEX idx_cc_fleet ON partner.charter_contract USING btree (fleet_code);


--
-- Name: idx_cc_partner; Type: INDEX; Schema: partner; Owner: -
--

CREATE INDEX idx_cc_partner ON partner.charter_contract USING btree (partner_code);


--
-- Name: idx_pa_line; Type: INDEX; Schema: partner; Owner: -
--

CREATE INDEX idx_pa_line ON partner.payment_allocation USING btree (statement_line_id);


--
-- Name: idx_pay_partner; Type: INDEX; Schema: partner; Owner: -
--

CREATE INDEX idx_pay_partner ON partner.payment USING btree (partner_code);


--
-- Name: idx_pi_partner; Type: INDEX; Schema: partner; Owner: -
--

CREATE INDEX idx_pi_partner ON partner.invoice USING btree (partner_code, received_at);


--
-- Name: idx_rc_cc; Type: INDEX; Schema: partner; Owner: -
--

CREATE INDEX idx_rc_cc ON partner.rate_card USING btree (charter_contract_id);


--
-- Name: idx_sl_status; Type: INDEX; Schema: partner; Owner: -
--

CREATE INDEX idx_sl_status ON partner.statement_line USING btree (payable_status);


--
-- Name: idx_sl_trip; Type: INDEX; Schema: partner; Owner: -
--

CREATE INDEX idx_sl_trip ON partner.statement_line USING btree (trip_id);


--
-- Name: idx_site_polygon; Type: INDEX; Schema: site; Owner: -
--

CREATE INDEX idx_site_polygon ON site.info USING gist (polygon);


--
-- Name: deposit_transaction trg_deposit_balance_sync; Type: TRIGGER; Schema: buyer; Owner: -
--

CREATE TRIGGER trg_deposit_balance_sync AFTER INSERT OR DELETE OR UPDATE ON buyer.deposit_transaction FOR EACH ROW EXECUTE FUNCTION buyer.fn_deposit_balance_sync();


--
-- Name: bap trg_po_delivered_sync; Type: TRIGGER; Schema: commercial; Owner: -
--

CREATE TRIGGER trg_po_delivered_sync AFTER INSERT OR UPDATE OF volume_m3, status ON commercial.bap FOR EACH ROW WHEN (((new.status)::text = ANY ((ARRAY['SIGNED'::character varying, 'CORRECTED'::character varying])::text[]))) EXECUTE FUNCTION commercial.fn_po_delivered_sync();


--
-- Name: voyage trg_voyage_append_only; Type: TRIGGER; Schema: voyage; Owner: -
--

CREATE TRIGGER trg_voyage_append_only BEFORE DELETE OR UPDATE ON voyage.voyage FOR EACH ROW EXECUTE FUNCTION voyage.fn_append_only_guard();


--
-- Name: deposit deposit_sales_contract_id_fkey; Type: FK CONSTRAINT; Schema: buyer; Owner: -
--

ALTER TABLE ONLY buyer.deposit
    ADD CONSTRAINT deposit_sales_contract_id_fkey FOREIGN KEY (sales_contract_id) REFERENCES commercial.sales_contract(sales_contract_id);


--
-- Name: deposit_transaction deposit_transaction_bap_id_fkey; Type: FK CONSTRAINT; Schema: buyer; Owner: -
--

ALTER TABLE ONLY buyer.deposit_transaction
    ADD CONSTRAINT deposit_transaction_bap_id_fkey FOREIGN KEY (bap_id) REFERENCES commercial.bap(bap_id);


--
-- Name: deposit_transaction deposit_transaction_deposit_id_fkey; Type: FK CONSTRAINT; Schema: buyer; Owner: -
--

ALTER TABLE ONLY buyer.deposit_transaction
    ADD CONSTRAINT deposit_transaction_deposit_id_fkey FOREIGN KEY (deposit_id) REFERENCES buyer.deposit(deposit_id);


--
-- Name: deposit_transaction deposit_transaction_trip_id_fkey; Type: FK CONSTRAINT; Schema: buyer; Owner: -
--

ALTER TABLE ONLY buyer.deposit_transaction
    ADD CONSTRAINT deposit_transaction_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES operational.trip(trip_id);


--
-- Name: deposit fk_deposit_currency; Type: FK CONSTRAINT; Schema: buyer; Owner: -
--

ALTER TABLE ONLY buyer.deposit
    ADD CONSTRAINT fk_deposit_currency FOREIGN KEY (currency_code) REFERENCES param.currency(currency_code);


--
-- Name: deposit_transaction fk_dt_ledger; Type: FK CONSTRAINT; Schema: buyer; Owner: -
--

ALTER TABLE ONLY buyer.deposit_transaction
    ADD CONSTRAINT fk_dt_ledger FOREIGN KEY (ledger_entry_id) REFERENCES buyer.ledger_hist(id);


--
-- Name: ledger_hist ledger_hist_buyer_code_fkey; Type: FK CONSTRAINT; Schema: buyer; Owner: -
--

ALTER TABLE ONLY buyer.ledger_hist
    ADD CONSTRAINT ledger_hist_buyer_code_fkey FOREIGN KEY (buyer_code) REFERENCES buyer.info(buyer_code);


--
-- Name: site site_buyer_code_fkey; Type: FK CONSTRAINT; Schema: buyer; Owner: -
--

ALTER TABLE ONLY buyer.site
    ADD CONSTRAINT site_buyer_code_fkey FOREIGN KEY (buyer_code) REFERENCES buyer.info(buyer_code);


--
-- Name: bap_correction bap_correction_bap_id_fkey; Type: FK CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.bap_correction
    ADD CONSTRAINT bap_correction_bap_id_fkey FOREIGN KEY (bap_id) REFERENCES commercial.bap(bap_id);


--
-- Name: bap_objection bap_objection_bap_id_fkey; Type: FK CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.bap_objection
    ADD CONSTRAINT bap_objection_bap_id_fkey FOREIGN KEY (bap_id) REFERENCES commercial.bap(bap_id);


--
-- Name: bap bap_trip_id_fkey; Type: FK CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.bap
    ADD CONSTRAINT bap_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES operational.trip(trip_id);


--
-- Name: delivery_order delivery_order_po_id_fkey; Type: FK CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.delivery_order
    ADD CONSTRAINT delivery_order_po_id_fkey FOREIGN KEY (po_id) REFERENCES commercial.purchase_order(po_id);


--
-- Name: delivery_order fk_do_fleet; Type: FK CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.delivery_order
    ADD CONSTRAINT fk_do_fleet FOREIGN KEY (fleet_code) REFERENCES fleet.info(fleet_code);


--
-- Name: purchase_order fk_po_sales_contract; Type: FK CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.purchase_order
    ADD CONSTRAINT fk_po_sales_contract FOREIGN KEY (sales_contract_id) REFERENCES commercial.sales_contract(sales_contract_id);


--
-- Name: sales_contract fk_sc_buyer; Type: FK CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.sales_contract
    ADD CONSTRAINT fk_sc_buyer FOREIGN KEY (buyer_code) REFERENCES buyer.info(buyer_code);


--
-- Name: sales_contract fk_sc_currency; Type: FK CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.sales_contract
    ADD CONSTRAINT fk_sc_currency FOREIGN KEY (currency_code) REFERENCES param.currency(currency_code);


--
-- Name: sales_contract fk_sc_site; Type: FK CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.sales_contract
    ADD CONSTRAINT fk_sc_site FOREIGN KEY (site_code) REFERENCES site.info(site_code);


--
-- Name: purchase_order purchase_order_buyer_code_fkey; Type: FK CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.purchase_order
    ADD CONSTRAINT purchase_order_buyer_code_fkey FOREIGN KEY (buyer_code) REFERENCES buyer.info(buyer_code);


--
-- Name: qa_sample qa_sample_sales_contract_id_fkey; Type: FK CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.qa_sample
    ADD CONSTRAINT qa_sample_sales_contract_id_fkey FOREIGN KEY (sales_contract_id) REFERENCES commercial.sales_contract(sales_contract_id);


--
-- Name: qa_sample qa_sample_trip_id_fkey; Type: FK CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.qa_sample
    ADD CONSTRAINT qa_sample_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES operational.trip(trip_id);


--
-- Name: sales_contract sales_contract_sand_spec_id_fkey; Type: FK CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.sales_contract
    ADD CONSTRAINT sales_contract_sand_spec_id_fkey FOREIGN KEY (sand_spec_id) REFERENCES commercial.sand_spec(sand_spec_id);


--
-- Name: standby_claim standby_claim_trip_id_fkey; Type: FK CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.standby_claim
    ADD CONSTRAINT standby_claim_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES operational.trip(trip_id);


--
-- Name: document_link document_link_document_id_fkey; Type: FK CONSTRAINT; Schema: document; Owner: -
--

ALTER TABLE ONLY document.document_link
    ADD CONSTRAINT document_link_document_id_fkey FOREIGN KEY (document_id) REFERENCES document.document(document_id) ON DELETE CASCADE;


--
-- Name: ews_event ews_event_parameter_code_fkey; Type: FK CONSTRAINT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.ews_event
    ADD CONSTRAINT ews_event_parameter_code_fkey FOREIGN KEY (parameter_code) REFERENCES enviro.mon_parameter(parameter_code);


--
-- Name: mon_report fk_monrep_document; Type: FK CONSTRAINT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.mon_report
    ADD CONSTRAINT fk_monrep_document FOREIGN KEY (doc_ref) REFERENCES document.document(document_id);


--
-- Name: mon_work_order fk_mwo_vendor; Type: FK CONSTRAINT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.mon_work_order
    ADD CONSTRAINT fk_mwo_vendor FOREIGN KEY (vendor_code) REFERENCES partner.info(partner_code);


--
-- Name: reading_detail fk_reading_detail_parameter; Type: FK CONSTRAINT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.reading_detail
    ADD CONSTRAINT fk_reading_detail_parameter FOREIGN KEY (parameter_code) REFERENCES enviro.mon_parameter(parameter_code);


--
-- Name: mon_schedule mon_schedule_parameter_code_fkey; Type: FK CONSTRAINT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.mon_schedule
    ADD CONSTRAINT mon_schedule_parameter_code_fkey FOREIGN KEY (parameter_code) REFERENCES enviro.mon_parameter(parameter_code);


--
-- Name: mon_schedule mon_schedule_station_code_fkey; Type: FK CONSTRAINT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.mon_schedule
    ADD CONSTRAINT mon_schedule_station_code_fkey FOREIGN KEY (station_code) REFERENCES enviro.station(station_code);


--
-- Name: reading_detail reading_detail_station_code_fkey; Type: FK CONSTRAINT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.reading_detail
    ADD CONSTRAINT reading_detail_station_code_fkey FOREIGN KEY (station_code) REFERENCES enviro.station(station_code);


--
-- Name: cost_entry cost_entry_charter_contract_id_fkey; Type: FK CONSTRAINT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.cost_entry
    ADD CONSTRAINT cost_entry_charter_contract_id_fkey FOREIGN KEY (charter_contract_id) REFERENCES partner.charter_contract(charter_contract_id);


--
-- Name: cost_entry cost_entry_trip_id_fkey; Type: FK CONSTRAINT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.cost_entry
    ADD CONSTRAINT cost_entry_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES operational.trip(trip_id);


--
-- Name: cost_entry fk_cost_journal; Type: FK CONSTRAINT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.cost_entry
    ADD CONSTRAINT fk_cost_journal FOREIGN KEY (journal_id) REFERENCES financial.journal(journal_id);


--
-- Name: invoice fk_invoice_buyer; Type: FK CONSTRAINT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.invoice
    ADD CONSTRAINT fk_invoice_buyer FOREIGN KEY (buyer_code) REFERENCES buyer.info(buyer_code);


--
-- Name: journal_line journal_line_journal_id_fkey; Type: FK CONSTRAINT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.journal_line
    ADD CONSTRAINT journal_line_journal_id_fkey FOREIGN KEY (journal_id) REFERENCES financial.journal(journal_id) ON DELETE CASCADE;


--
-- Name: pnbp_charge pnbp_charge_bap_id_fkey; Type: FK CONSTRAINT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.pnbp_charge
    ADD CONSTRAINT pnbp_charge_bap_id_fkey FOREIGN KEY (bap_id) REFERENCES commercial.bap(bap_id);


--
-- Name: pnbp_charge pnbp_charge_trip_id_fkey; Type: FK CONSTRAINT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.pnbp_charge
    ADD CONSTRAINT pnbp_charge_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES operational.trip(trip_id);


--
-- Name: pnbp_tahap_awal pnbp_tahap_awal_sales_contract_id_fkey; Type: FK CONSTRAINT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.pnbp_tahap_awal
    ADD CONSTRAINT pnbp_tahap_awal_sales_contract_id_fkey FOREIGN KEY (sales_contract_id) REFERENCES commercial.sales_contract(sales_contract_id);


--
-- Name: certificate certificate_fleet_code_fkey; Type: FK CONSTRAINT; Schema: hse; Owner: -
--

ALTER TABLE ONLY hse.certificate
    ADD CONSTRAINT certificate_fleet_code_fkey FOREIGN KEY (fleet_code) REFERENCES fleet.info(fleet_code);


--
-- Name: incident incident_fleet_code_fkey; Type: FK CONSTRAINT; Schema: hse; Owner: -
--

ALTER TABLE ONLY hse.incident
    ADD CONSTRAINT incident_fleet_code_fkey FOREIGN KEY (fleet_code) REFERENCES fleet.info(fleet_code);


--
-- Name: induction induction_fleet_code_fkey; Type: FK CONSTRAINT; Schema: hse; Owner: -
--

ALTER TABLE ONLY hse.induction
    ADD CONSTRAINT induction_fleet_code_fkey FOREIGN KEY (fleet_code) REFERENCES fleet.info(fleet_code);


--
-- Name: email_outbox email_outbox_schedule_id_fkey; Type: FK CONSTRAINT; Schema: notification; Owner: -
--

ALTER TABLE ONLY notification.email_outbox
    ADD CONSTRAINT email_outbox_schedule_id_fkey FOREIGN KEY (schedule_id) REFERENCES notification.report_schedule(schedule_id);


--
-- Name: log log_rule_id_fkey; Type: FK CONSTRAINT; Schema: notification; Owner: -
--

ALTER TABLE ONLY notification.log
    ADD CONSTRAINT log_rule_id_fkey FOREIGN KEY (rule_id) REFERENCES notification.rule(rule_id);


--
-- Name: discharge_event discharge_event_trip_id_fkey; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.discharge_event
    ADD CONSTRAINT discharge_event_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES operational.trip(trip_id);


--
-- Name: trip fk_trip_si; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.trip
    ADD CONSTRAINT fk_trip_si FOREIGN KEY (si_num) REFERENCES operational.shipment_instruction(si_num);


--
-- Name: trip fk_trip_work_area; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.trip
    ADD CONSTRAINT fk_trip_work_area FOREIGN KEY (work_area_code) REFERENCES operational.work_area(area_code);


--
-- Name: manual_report manual_report_trip_id_fkey; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.manual_report
    ADD CONSTRAINT manual_report_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES operational.trip(trip_id);


--
-- Name: nor nor_trip_id_fkey; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.nor
    ADD CONSTRAINT nor_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES operational.trip(trip_id);


--
-- Name: schedule_plan schedule_plan_trip_id_fkey; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.schedule_plan
    ADD CONSTRAINT schedule_plan_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES operational.trip(trip_id);


--
-- Name: shipment_instruction shipment_instruction_do_id_fkey; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.shipment_instruction
    ADD CONSTRAINT shipment_instruction_do_id_fkey FOREIGN KEY (do_id) REFERENCES commercial.delivery_order(do_id);


--
-- Name: site_permit site_permit_trip_id_fkey; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.site_permit
    ADD CONSTRAINT site_permit_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES operational.trip(trip_id);


--
-- Name: trip trip_fleet_code_fkey; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.trip
    ADD CONSTRAINT trip_fleet_code_fkey FOREIGN KEY (fleet_code) REFERENCES fleet.info(fleet_code);


--
-- Name: waiting_log waiting_log_trip_id_fkey; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.waiting_log
    ADD CONSTRAINT waiting_log_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES operational.trip(trip_id);


--
-- Name: charter_contract charter_contract_fleet_code_fkey; Type: FK CONSTRAINT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.charter_contract
    ADD CONSTRAINT charter_contract_fleet_code_fkey FOREIGN KEY (fleet_code) REFERENCES fleet.info(fleet_code);


--
-- Name: charter_contract charter_contract_partner_code_fkey; Type: FK CONSTRAINT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.charter_contract
    ADD CONSTRAINT charter_contract_partner_code_fkey FOREIGN KEY (partner_code) REFERENCES partner.info(partner_code);


--
-- Name: invoice invoice_charter_contract_id_fkey; Type: FK CONSTRAINT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.invoice
    ADD CONSTRAINT invoice_charter_contract_id_fkey FOREIGN KEY (charter_contract_id) REFERENCES partner.charter_contract(charter_contract_id);


--
-- Name: invoice invoice_partner_code_fkey; Type: FK CONSTRAINT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.invoice
    ADD CONSTRAINT invoice_partner_code_fkey FOREIGN KEY (partner_code) REFERENCES partner.info(partner_code);


--
-- Name: payment_allocation payment_allocation_payment_id_fkey; Type: FK CONSTRAINT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.payment_allocation
    ADD CONSTRAINT payment_allocation_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES partner.payment(payment_id) ON DELETE CASCADE;


--
-- Name: payment_allocation payment_allocation_statement_line_id_fkey; Type: FK CONSTRAINT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.payment_allocation
    ADD CONSTRAINT payment_allocation_statement_line_id_fkey FOREIGN KEY (statement_line_id) REFERENCES partner.statement_line(statement_line_id);


--
-- Name: payment payment_partner_code_fkey; Type: FK CONSTRAINT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.payment
    ADD CONSTRAINT payment_partner_code_fkey FOREIGN KEY (partner_code) REFERENCES partner.info(partner_code);


--
-- Name: rate_card rate_card_charter_contract_id_fkey; Type: FK CONSTRAINT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.rate_card
    ADD CONSTRAINT rate_card_charter_contract_id_fkey FOREIGN KEY (charter_contract_id) REFERENCES partner.charter_contract(charter_contract_id);


--
-- Name: statement_line statement_line_charter_contract_id_fkey; Type: FK CONSTRAINT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.statement_line
    ADD CONSTRAINT statement_line_charter_contract_id_fkey FOREIGN KEY (charter_contract_id) REFERENCES partner.charter_contract(charter_contract_id);


--
-- Name: statement_line statement_line_rate_card_id_fkey; Type: FK CONSTRAINT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.statement_line
    ADD CONSTRAINT statement_line_rate_card_id_fkey FOREIGN KEY (rate_card_id) REFERENCES partner.rate_card(rate_card_id);


--
-- Name: statement_line statement_line_trip_id_fkey; Type: FK CONSTRAINT; Schema: partner; Owner: -
--

ALTER TABLE ONLY partner.statement_line
    ADD CONSTRAINT statement_line_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES operational.trip(trip_id);


--
-- Name: info info_owner_buyer_code_fkey; Type: FK CONSTRAINT; Schema: site; Owner: -
--

ALTER TABLE ONLY site.info
    ADD CONSTRAINT info_owner_buyer_code_fkey FOREIGN KEY (owner_buyer_code) REFERENCES buyer.info(buyer_code);


--
-- Name: draft_survey draft_survey_trip_id_fkey; Type: FK CONSTRAINT; Schema: survey; Owner: -
--

ALTER TABLE ONLY survey.draft_survey
    ADD CONSTRAINT draft_survey_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES operational.trip(trip_id);


--
-- Name: draft_survey fk_ds_document; Type: FK CONSTRAINT; Schema: survey; Owner: -
--

ALTER TABLE ONLY survey.draft_survey
    ADD CONSTRAINT fk_ds_document FOREIGN KEY (doc_ref) REFERENCES document.document(document_id);


--
-- Name: ais_position ais_position_fleet_code_fkey; Type: FK CONSTRAINT; Schema: telemetry; Owner: -
--

ALTER TABLE ONLY telemetry.ais_position
    ADD CONSTRAINT ais_position_fleet_code_fkey FOREIGN KEY (fleet_code) REFERENCES fleet.info(fleet_code);


--
-- Name: geofence_event geofence_event_geofence_id_fkey; Type: FK CONSTRAINT; Schema: telemetry; Owner: -
--

ALTER TABLE ONLY telemetry.geofence_event
    ADD CONSTRAINT geofence_event_geofence_id_fkey FOREIGN KEY (geofence_id) REFERENCES telemetry.geofence(geofence_id);


--
-- Name: vessel_device vessel_device_fleet_code_fkey; Type: FK CONSTRAINT; Schema: telemetry; Owner: -
--

ALTER TABLE ONLY telemetry.vessel_device
    ADD CONSTRAINT vessel_device_fleet_code_fkey FOREIGN KEY (fleet_code) REFERENCES fleet.info(fleet_code);


--
-- Name: voyage voyage_fleet_code_fkey; Type: FK CONSTRAINT; Schema: voyage; Owner: -
--

ALTER TABLE ONLY voyage.voyage
    ADD CONSTRAINT voyage_fleet_code_fkey FOREIGN KEY (fleet_code) REFERENCES fleet.info(fleet_code);


--
-- PostgreSQL database dump complete
--

\unrestrict T7fbs8RPxDmOK6ll8EcnVmolsMM0QUBC22Cjo8WGajGzo5GU6p7EeYF7aAK7HOX

