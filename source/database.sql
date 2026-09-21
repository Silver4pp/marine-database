-- ============================================================================
-- BARU.sql — DATABASE BARU DARI NOL · ERP PASIR LAUT · level skema 18
-- ============================================================================
-- Snapshot LENGKAP (skema + data demo) hasil rantai DDL resmi 01→18.
--
-- PEMAKAIAN (database kosong mana pun — lokal, VM, Supabase):
--   psql -d <database-baru> -f BARU.sql
--   lalu jalankan aplikasi: tabel Django (auth_*/django_*/core_*) dibuat
--   otomatis oleh migrasi + bootstrap_auth saat boot.
--
-- Catatan:
--   * TANPA perintah kepemilikan/GRANT (portable ke role mana pun).
--   * Memuat ekstensi PostGIS (CREATE EXTENSION IF NOT EXISTS). Bila target
--     tidak mengizinkannya lewat SQL (mis. sebagian PaaS), aktifkan PostGIS
--     dari dashboard dulu, lalu jalankan file ini.
--   * Regenerasi kapan pun:  bash database/buat-baru.sh  (selalu sinkron
--     dengan rantai — tidak pernah basi seperti snapshot lama).
--   * 104 tabel bisnis · 4 view · level skema 18
--     (aplikasi v2026.09.21-21; DDL self-heal saat boot akan "lompat").
-- ============================================================================
--
-- PostgreSQL database dump
--

\restrict bB2osQFCA9sbuqZh0fI34EwLBAqRH4nqE1sXvDZpupNtLgSfTcANJdpXxgh4s0b

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
-- Name: enviro_raw; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA enviro_raw;


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
-- Name: fn_bap_koreksi_kuota(); Type: FUNCTION; Schema: operational; Owner: -
--

CREATE FUNCTION operational.fn_bap_koreksi_kuota() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE v_zone text;
BEGIN
  SELECT w.zone_code INTO v_zone
    FROM commercial.bap b
    JOIN operational.trip t ON t.trip_id = b.trip_id
    JOIN operational.work_area w ON w.area_code = t.work_area_code
   WHERE b.bap_id = NEW.bap_id;
  IF v_zone IS NOT NULL THEN
    UPDATE operational.work_zone
       SET quota_used_m3 = greatest(quota_used_m3 + COALESCE(NEW.delta_volume_m3, 0), 0),
           updated_at = now()
     WHERE zone_code = v_zone;
  END IF;
  RETURN NEW;
END $$;


--
-- Name: fn_bap_sah_kuota(); Type: FUNCTION; Schema: operational; Owner: -
--

CREATE FUNCTION operational.fn_bap_sah_kuota() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE v_zone text;
BEGIN
  SELECT w.zone_code INTO v_zone
    FROM commercial.bap b
    JOIN operational.trip t ON t.trip_id = b.trip_id
    JOIN operational.work_area w ON w.area_code = t.work_area_code
   WHERE b.bap_id = NEW.bap_id;
  IF v_zone IS NOT NULL THEN
    UPDATE operational.work_zone
       SET quota_used_m3 = quota_used_m3 + COALESCE(NEW.volume_m3, 0), updated_at = now()
     WHERE zone_code = v_zone;
  END IF;
  RETURN NEW;
END $$;


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
    CONSTRAINT deposit_transaction_tipe_check CHECK (((tipe)::text = ANY (ARRAY[('TOP_UP'::character varying)::text, ('DEDUCTION'::character varying)::text, ('ADJUSTMENT'::character varying)::text, ('REFUND'::character varying)::text])))
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
    CONSTRAINT bap_status_check CHECK (((status)::text = ANY (ARRAY[('DRAFT'::character varying)::text, ('SIGNED'::character varying)::text, ('DISPUTED'::character varying)::text, ('CORRECTED'::character varying)::text]))),
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
    CONSTRAINT chk_objection_status CHECK (((status)::text = ANY (ARRAY[('OPEN'::character varying)::text, ('RESOLVED'::character varying)::text, ('REJECTED'::character varying)::text])))
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
    CONSTRAINT chk_qa_claim_status CHECK (((claim_status IS NULL) OR ((claim_status)::text = ANY (ARRAY[('NONE'::character varying)::text, ('FILED'::character varying)::text, ('APPROVED'::character varying)::text, ('REJECTED'::character varying)::text])))),
    CONSTRAINT qa_sample_tipe_check CHECK (((tipe)::text = ANY (ARRAY[('MUAT'::character varying)::text, ('BONGKAR'::character varying)::text]))),
    CONSTRAINT qa_sample_verdict_check CHECK (((verdict)::text = ANY (ARRAY[('PASS'::character varying)::text, ('FAIL'::character varying)::text, ('PENDING'::character varying)::text])))
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
    CONSTRAINT sales_contract_payment_mode_check CHECK (((payment_mode)::text = ANY (ARRAY[('DEPOSIT'::character varying)::text, ('PELUNASAN'::character varying)::text])))
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
-- Name: shipment_monthly; Type: TABLE; Schema: commercial; Owner: -
--

CREATE TABLE commercial.shipment_monthly (
    bulan date NOT NULL,
    buyer_code character varying(30) NOT NULL,
    volume_m3 numeric(14,3) DEFAULT 0 NOT NULL,
    source character varying(20) DEFAULT 'DEMO_SEED'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT shipment_monthly_source_check CHECK (((source)::text = ANY ((ARRAY['DEMO_SEED'::character varying, 'AGG_BAP'::character varying])::text[])))
);


--
-- Name: TABLE shipment_monthly; Type: COMMENT; Schema: commercial; Owner: -
--

COMMENT ON TABLE commercial.shipment_monthly IS 'feat-v6 W4.1/W4.2: agregat volume pengiriman bulanan per pembeli — baris DEMO_SEED = riwayat contoh perusahaan fiktif (ganti AGG_BAP saat produksi)';


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
    CONSTRAINT standby_claim_status_check CHECK (((status)::text = ANY (ARRAY[('COMPUTED'::character varying)::text, ('DISPOSED_TAGIH'::character varying)::text, ('DISPOSED_HANGUS'::character varying)::text])))
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
-- Name: doc_verification; Type: TABLE; Schema: document; Owner: -
--

CREATE TABLE document.doc_verification (
    verification_id bigint NOT NULL,
    document_id bigint NOT NULL,
    status character varying(12) DEFAULT 'PENDING'::character varying NOT NULL,
    catatan text,
    verified_by character varying(150),
    verified_at timestamp with time zone,
    CONSTRAINT chk_dv_status CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'COCOK'::character varying, 'TIDAK_COCOK'::character varying])::text[])))
);


--
-- Name: doc_verification_verification_id_seq; Type: SEQUENCE; Schema: document; Owner: -
--

CREATE SEQUENCE document.doc_verification_verification_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: doc_verification_verification_id_seq; Type: SEQUENCE OWNED BY; Schema: document; Owner: -
--

ALTER SEQUENCE document.doc_verification_verification_id_seq OWNED BY document.doc_verification.verification_id;


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
-- Name: form_foto; Type: TABLE; Schema: document; Owner: -
--

CREATE TABLE document.form_foto (
    foto_id bigint NOT NULL,
    form_jenis character varying(20) NOT NULL,
    record_id bigint NOT NULL,
    record_label character varying(60) NOT NULL,
    file_path character varying(200) NOT NULL,
    storage character varying(10) NOT NULL,
    ukuran integer NOT NULL,
    lebar integer,
    tinggi integer,
    data bytea,
    diunggah_oleh character varying(30) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT form_foto_jenis_check CHECK (((form_jenis)::text = ANY ((ARRAY['DRAFT_SURVEY'::character varying, 'BAP'::character varying, 'INSPEKSI_HSE'::character varying, 'TOOLBOX'::character varying, 'MONITORING_ENVIRO'::character varying, 'DOK_EKSTERNAL'::character varying, 'MISI_DOK'::character varying])::text[]))),
    CONSTRAINT form_foto_storage_check CHECK (((storage)::text = ANY ((ARRAY['SUPABASE'::character varying, 'DB'::character varying])::text[])))
);


--
-- Name: form_foto_foto_id_seq; Type: SEQUENCE; Schema: document; Owner: -
--

ALTER TABLE document.form_foto ALTER COLUMN foto_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME document.form_foto_foto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
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
    CONSTRAINT ews_event_level_check CHECK (((level)::text = ANY (ARRAY[('WARNING'::character varying)::text, ('EXCEEDED'::character varying)::text]))),
    CONSTRAINT ews_event_trigger_rule_check CHECK (((trigger_rule)::text = ANY ((ARRAY['THRESHOLD'::character varying, 'TREND'::character varying, 'COMPOSITE'::character varying, 'TIDE_WINDOW'::character varying, 'SENSOR_15MNT'::character varying])::text[])))
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
    CONSTRAINT mon_parameter_parameter_group_check CHECK (((parameter_group)::text = ANY (ARRAY[('AIR'::character varying)::text, ('HIDRO'::character varying)::text, ('SEDIMEN'::character varying)::text, ('BIOTA'::character varying)::text, ('SOSIAL'::character varying)::text])))
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
    CONSTRAINT mon_work_order_kind_check CHECK (((kind)::text = ANY (ARRAY[('SAMPLING'::character varying)::text, ('BUOY_DOWNLOAD'::character varying)::text]))),
    CONSTRAINT mon_work_order_status_check CHECK (((status)::text = ANY (ARRAY[('ISSUED'::character varying)::text, ('IN_PROGRESS'::character varying)::text, ('COMPLETED'::character varying)::text])))
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
-- Name: reading_daily; Type: TABLE; Schema: enviro; Owner: -
--

CREATE TABLE enviro.reading_daily (
    station_code character varying(16) NOT NULL,
    parameter_code character varying(24) NOT NULL,
    hari date NOT NULL,
    n integer NOT NULL,
    avg numeric(12,4) NOT NULL,
    min numeric(12,4) NOT NULL,
    max numeric(12,4) NOT NULL,
    p95 numeric(12,4) NOT NULL
);


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
    CONSTRAINT reading_detail_qc_status_check CHECK (((qc_status)::text = ANY (ARRAY[('RAW'::character varying)::text, ('VALIDATED'::character varying)::text, ('REJECTED'::character varying)::text]))),
    CONSTRAINT reading_detail_source_check CHECK (((source)::text = ANY (ARRAY[('BUOY'::character varying)::text, ('LAB'::character varying)::text, ('MANUAL'::character varying)::text])))
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
-- Name: reading_monthly_v; Type: VIEW; Schema: enviro; Owner: -
--

CREATE VIEW enviro.reading_monthly_v AS
 SELECT station_code,
    parameter_code,
    (date_trunc('month'::text, (hari)::timestamp with time zone))::date AS periode,
    (sum(n))::integer AS n,
    round(avg(avg), 4) AS avg,
    min(min) AS min,
    max(max) AS max
   FROM enviro.reading_daily
  GROUP BY station_code, parameter_code, ((date_trunc('month'::text, (hari)::timestamp with time zone))::date);


--
-- Name: reading_quarterly_v; Type: VIEW; Schema: enviro; Owner: -
--

CREATE VIEW enviro.reading_quarterly_v AS
 SELECT station_code,
    parameter_code,
    (date_trunc('quarter'::text, (hari)::timestamp with time zone))::date AS periode,
    (sum(n))::integer AS n,
    round(avg(avg), 4) AS avg,
    min(min) AS min,
    max(max) AS max
   FROM enviro.reading_daily
  GROUP BY station_code, parameter_code, ((date_trunc('quarter'::text, (hari)::timestamp with time zone))::date);


--
-- Name: VIEW reading_quarterly_v; Type: COMMENT; Schema: enviro; Owner: -
--

COMMENT ON VIEW enviro.reading_quarterly_v IS 'feat-v9 BRD-v6 FR-6-08: agregat kuartalan dari reading_daily (Analisis Riwayat Enviro)';


--
-- Name: reading_yearly_v; Type: VIEW; Schema: enviro; Owner: -
--

CREATE VIEW enviro.reading_yearly_v AS
 SELECT station_code,
    parameter_code,
    (date_trunc('year'::text, (hari)::timestamp with time zone))::date AS periode,
    (sum(n))::integer AS n,
    round(avg(avg), 4) AS avg,
    min(min) AS min,
    max(max) AS max
   FROM enviro.reading_daily
  GROUP BY station_code, parameter_code, ((date_trunc('year'::text, (hari)::timestamp with time zone))::date);


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
    CONSTRAINT remediation_cause_type_check CHECK (((cause_type)::text = ANY (ARRAY[('EWS'::character varying)::text, ('MON_RECORD'::character varying)::text]))),
    CONSTRAINT remediation_status_check CHECK (((status)::text = ANY (ARRAY[('PLANNED'::character varying)::text, ('IN_PROGRESS'::character varying)::text, ('VERIFYING'::character varying)::text, ('CLOSED'::character varying)::text])))
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
-- Name: reading; Type: TABLE; Schema: enviro_raw; Owner: -
--

CREATE TABLE enviro_raw.reading (
    station_code character varying(16) NOT NULL,
    parameter_code character varying(24) NOT NULL,
    ts timestamp with time zone NOT NULL,
    value numeric(12,4) NOT NULL
)
PARTITION BY RANGE (ts);


--
-- Name: reading_default; Type: TABLE; Schema: enviro_raw; Owner: -
--

CREATE TABLE enviro_raw.reading_default (
    station_code character varying(16) NOT NULL,
    parameter_code character varying(24) NOT NULL,
    ts timestamp with time zone NOT NULL,
    value numeric(12,4) NOT NULL
);


--
-- Name: reading_p2026_09; Type: TABLE; Schema: enviro_raw; Owner: -
--

CREATE TABLE enviro_raw.reading_p2026_09 (
    station_code character varying(16) NOT NULL,
    parameter_code character varying(24) NOT NULL,
    ts timestamp with time zone NOT NULL,
    value numeric(12,4) NOT NULL
);


--
-- Name: reading_p2026_10; Type: TABLE; Schema: enviro_raw; Owner: -
--

CREATE TABLE enviro_raw.reading_p2026_10 (
    station_code character varying(16) NOT NULL,
    parameter_code character varying(24) NOT NULL,
    ts timestamp with time zone NOT NULL,
    value numeric(12,4) NOT NULL
);


--
-- Name: reading_p2026_11; Type: TABLE; Schema: enviro_raw; Owner: -
--

CREATE TABLE enviro_raw.reading_p2026_11 (
    station_code character varying(16) NOT NULL,
    parameter_code character varying(24) NOT NULL,
    ts timestamp with time zone NOT NULL,
    value numeric(12,4) NOT NULL
);


--
-- Name: sensor_threshold; Type: TABLE; Schema: enviro_raw; Owner: -
--

CREATE TABLE enviro_raw.sensor_threshold (
    parameter_code character varying(24) NOT NULL,
    ambang_min numeric(12,4),
    ambang_max numeric(12,4),
    satuan character varying(16) DEFAULT ''::character varying NOT NULL,
    referensi character varying(160) DEFAULT ''::character varying NOT NULL,
    updated_by character varying(80) DEFAULT 'seed'::character varying NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: station_token; Type: TABLE; Schema: enviro_raw; Owner: -
--

CREATE TABLE enviro_raw.station_token (
    station_code character varying(16) NOT NULL,
    token character varying(64) NOT NULL,
    aktif boolean DEFAULT true NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
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
    CONSTRAINT cost_entry_category_check CHECK (((category)::text = ANY (ARRAY[('CHARTER'::character varying)::text, ('STANDBY'::character varying)::text, ('OTHER'::character varying)::text]))),
    CONSTRAINT cost_entry_source_check CHECK (((source)::text = ANY (ARRAY[('AUTO'::character varying)::text, ('MANUAL'::character varying)::text])))
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
    CONSTRAINT invoice_invoice_type_check CHECK (((invoice_type)::text = ANY (ARRAY[('SALES'::character varying)::text, ('PURCHASE'::character varying)::text])))
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
    CONSTRAINT pnbp_charge_status_check CHECK (((status)::text = ANY (ARRAY[('ACCRUED'::character varying)::text, ('REPORTED'::character varying)::text, ('PAID'::character varying)::text])))
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
-- Name: pnbp_kode_map; Type: TABLE; Schema: financial; Owner: -
--

CREATE TABLE financial.pnbp_kode_map (
    map_id bigint NOT NULL,
    jenis character varying(30) NOT NULL,
    label text NOT NULL,
    kode character varying(40) NOT NULL,
    dasar_hukum text,
    keterangan text,
    is_placeholder boolean DEFAULT true NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT 'seed'::text NOT NULL,
    CONSTRAINT pnbp_kode_jenis_check CHECK (((jenis)::text = ANY ((ARRAY['TAHAP_AWAL'::character varying, 'REALISASI_BAP'::character varying, 'PROYEKSI'::character varying])::text[])))
);


--
-- Name: TABLE pnbp_kode_map; Type: COMMENT; Schema: financial; Owner: -
--

COMMENT ON TABLE financial.pnbp_kode_map IS 'W2.4: map kode PNBP per jenis tagihan — placeholder hingga KMA resmi; edit via UI ADMIN (audit P-3); tagihan PDF membaca dari sini';


--
-- Name: pnbp_kode_map_map_id_seq; Type: SEQUENCE; Schema: financial; Owner: -
--

ALTER TABLE financial.pnbp_kode_map ALTER COLUMN map_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME financial.pnbp_kode_map_map_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


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
-- Name: vessel_maintenance_maintenance_id_seq; Type: SEQUENCE; Schema: fleet; Owner: -
--

CREATE SEQUENCE fleet.vessel_maintenance_maintenance_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: vessel_maintenance; Type: TABLE; Schema: fleet; Owner: -
--

CREATE TABLE fleet.vessel_maintenance (
    maintenance_id bigint DEFAULT nextval('fleet.vessel_maintenance_maintenance_id_seq'::regclass) NOT NULL,
    fleet_code character varying(30) NOT NULL,
    jenis character varying(30) DEFAULT 'PERBAIKAN_RUTIN'::character varying NOT NULL,
    window_start timestamp with time zone NOT NULL,
    window_end timestamp with time zone NOT NULL,
    catatan text,
    dibuat_oleh character varying(150),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_maintenance_jenis CHECK (((jenis)::text = ANY ((ARRAY['DOCKING'::character varying, 'PERBAIKAN_RUTIN'::character varying, 'DARURAT'::character varying])::text[]))),
    CONSTRAINT chk_maintenance_window CHECK ((window_end > window_start))
);


--
-- Name: TABLE vessel_maintenance; Type: COMMENT; Schema: fleet; Owner: -
--

COMMENT ON TABLE fleet.vessel_maintenance IS 'Jendela perawatan kapal — HARD CONSTRAINT: kapal di dalam jendela tidak boleh ditugaskan (Tugaskan Kapal) & digambar di Gantt';


--
-- Name: COLUMN vessel_maintenance.jenis; Type: COMMENT; Schema: fleet; Owner: -
--

COMMENT ON COLUMN fleet.vessel_maintenance.jenis IS 'DOCKING · PERBAIKAN_RUTIN · DARURAT';


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
    CONSTRAINT capa_source_type_check CHECK (((source_type)::text = ANY (ARRAY[('INSPECTION'::character varying)::text, ('INCIDENT'::character varying)::text]))),
    CONSTRAINT capa_status_check CHECK (((status)::text = ANY (ARRAY[('OPEN'::character varying)::text, ('IN_PROGRESS'::character varying)::text, ('CLOSED'::character varying)::text])))
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
    CONSTRAINT incident_category_check CHECK (((category)::text = ANY (ARRAY[('NEAR_MISS'::character varying)::text, ('FIRST_AID'::character varying)::text, ('MEDICAL_TREATMENT'::character varying)::text, ('LTI'::character varying)::text, ('ENVIRONMENT'::character varying)::text]))),
    CONSTRAINT incident_reported_via_check CHECK (((reported_via)::text = ANY (ARRAY[('PWA'::character varying)::text, ('PORTAL'::character varying)::text, ('EMAIL'::character varying)::text]))),
    CONSTRAINT incident_status_check CHECK (((status)::text = ANY (ARRAY[('OPEN'::character varying)::text, ('CLOSED'::character varying)::text])))
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
    CONSTRAINT inspection_checklist_check CHECK (((checklist)::text = ANY (ARRAY[('APD'::character varying)::text, ('ALAT_APUNG'::character varying)::text, ('DECK'::character varying)::text, ('RUMAH_MESIN'::character varying)::text, ('HOUSEKEEPING'::character varying)::text]))),
    CONSTRAINT inspection_result_check CHECK (((result)::text = ANY (ARRAY[('COMPLIANT'::character varying)::text, ('FINDING'::character varying)::text]))),
    CONSTRAINT inspection_status_check CHECK (((status)::text = ANY (ARRAY[('SCHEDULED'::character varying)::text, ('DONE'::character varying)::text])))
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
    CONSTRAINT log_channel_check CHECK (((channel)::text = ANY (ARRAY[('TELEGRAM'::character varying)::text, ('EMAIL'::character varying)::text, ('WEB'::character varying)::text]))),
    CONSTRAINT log_status_check CHECK (((status)::text = ANY (ARRAY[('QUEUED'::character varying)::text, ('SENT'::character varying)::text, ('FAILED'::character varying)::text])))
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
-- Name: notif_inapp_inapp_id_seq; Type: SEQUENCE; Schema: notification; Owner: -
--

CREATE SEQUENCE notification.notif_inapp_inapp_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notif_inapp; Type: TABLE; Schema: notification; Owner: -
--

CREATE TABLE notification.notif_inapp (
    inapp_id bigint DEFAULT nextval('notification.notif_inapp_inapp_id_seq'::regclass) NOT NULL,
    username character varying(150) NOT NULL,
    event character varying(40) DEFAULT ''::character varying NOT NULL,
    judul character varying(200) DEFAULT ''::character varying NOT NULL,
    isi character varying(2000) DEFAULT ''::character varying NOT NULL,
    url character varying(200) DEFAULT ''::character varying NOT NULL,
    dibaca boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: notif_outbox_outbox_id_seq; Type: SEQUENCE; Schema: notification; Owner: -
--

CREATE SEQUENCE notification.notif_outbox_outbox_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notif_outbox; Type: TABLE; Schema: notification; Owner: -
--

CREATE TABLE notification.notif_outbox (
    outbox_id bigint DEFAULT nextval('notification.notif_outbox_outbox_id_seq'::regclass) NOT NULL,
    penerima_id bigint,
    kanal character varying(12) NOT NULL,
    tujuan character varying(120) NOT NULL,
    event character varying(40) NOT NULL,
    judul character varying(200) NOT NULL,
    isi text NOT NULL,
    status character varying(10) DEFAULT 'OUTBOX'::character varying NOT NULL,
    error text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    sent_at timestamp with time zone,
    CONSTRAINT chk_notif_outbox_kanal CHECK (((kanal)::text = ANY ((ARRAY['TELEGRAM'::character varying, 'WHATSAPP'::character varying])::text[]))),
    CONSTRAINT chk_notif_outbox_status CHECK (((status)::text = ANY ((ARRAY['OUTBOX'::character varying, 'TERKIRIM'::character varying, 'GAGAL'::character varying])::text[])))
);


--
-- Name: TABLE notif_outbox; Type: COMMENT; Schema: notification; Owner: -
--

COMMENT ON TABLE notification.notif_outbox IS 'feat-v2: antrean pesan instan — status OUTBOX → TERKIRIM/GAGAL oleh command kirim_notif';


--
-- Name: notif_penerima_penerima_id_seq; Type: SEQUENCE; Schema: notification; Owner: -
--

CREATE SEQUENCE notification.notif_penerima_penerima_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notif_penerima; Type: TABLE; Schema: notification; Owner: -
--

CREATE TABLE notification.notif_penerima (
    penerima_id bigint DEFAULT nextval('notification.notif_penerima_penerima_id_seq'::regclass) NOT NULL,
    kanal character varying(12) NOT NULL,
    tujuan character varying(120) NOT NULL,
    label character varying(80) NOT NULL,
    aktif boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_notif_penerima_kanal CHECK (((kanal)::text = ANY ((ARRAY['TELEGRAM'::character varying, 'WHATSAPP'::character varying])::text[])))
);


--
-- Name: TABLE notif_penerima; Type: COMMENT; Schema: notification; Owner: -
--

COMMENT ON TABLE notification.notif_penerima IS 'feat-v2: penerima notifikasi instan (WA/Telegram) — dikelola ADMIN di /modul/notifikasi/';


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
    CONSTRAINT discharge_event_event_check CHECK (((event)::text = ANY (ARRAY[('START'::character varying)::text, ('STOP'::character varying)::text, ('RESUME'::character varying)::text, ('COMPLETE'::character varying)::text]))),
    CONSTRAINT discharge_event_reason_check CHECK (((reason)::text = ANY (ARRAY[('BREAKDOWN_KAPAL'::character varying)::text, ('CUACA'::character varying)::text, ('AREA_PENUH'::character varying)::text, ('MASALAH_SITE'::character varying)::text, ('LAINNYA'::character varying)::text])))
);


--
-- Name: doc_approval; Type: TABLE; Schema: operational; Owner: -
--

CREATE TABLE operational.doc_approval (
    approval_id bigint NOT NULL,
    doc_kind character varying(20) NOT NULL,
    doc_id bigint NOT NULL,
    level integer NOT NULL,
    approver_role character varying(12) NOT NULL,
    status character varying(10) DEFAULT 'PENDING'::character varying NOT NULL,
    decided_by character varying(150),
    decided_at timestamp with time zone,
    catatan text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_ap_level CHECK ((level = ANY (ARRAY[1, 2]))),
    CONSTRAINT chk_ap_status CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'APPROVED'::character varying, 'REJECTED'::character varying])::text[])))
);


--
-- Name: doc_approval_approval_id_seq; Type: SEQUENCE; Schema: operational; Owner: -
--

CREATE SEQUENCE operational.doc_approval_approval_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: doc_approval_approval_id_seq; Type: SEQUENCE OWNED BY; Schema: operational; Owner: -
--

ALTER SEQUENCE operational.doc_approval_approval_id_seq OWNED BY operational.doc_approval.approval_id;


--
-- Name: line_compliance; Type: TABLE; Schema: operational; Owner: -
--

CREATE TABLE operational.line_compliance (
    compliance_id bigint NOT NULL,
    trip_id bigint NOT NULL,
    line_id bigint NOT NULL,
    lon numeric(10,6) NOT NULL,
    lat numeric(10,6) NOT NULL,
    jarak_m integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE line_compliance; Type: COMMENT; Schema: operational; Owner: -
--

COMMENT ON TABLE operational.line_compliance IS 'Kepatuhan strip per line (BRD-v7 W3): kapal fase MUAT di luar strip line-nya (buffer ±150 m) — dicatat tarik_ais (--cek-strip); notif STRIP_VIOLATION anti-spam 60 mnt.';


--
-- Name: line_compliance_compliance_id_seq; Type: SEQUENCE; Schema: operational; Owner: -
--

CREATE SEQUENCE operational.line_compliance_compliance_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: line_compliance_compliance_id_seq; Type: SEQUENCE OWNED BY; Schema: operational; Owner: -
--

ALTER SEQUENCE operational.line_compliance_compliance_id_seq OWNED BY operational.line_compliance.compliance_id;


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
    CONSTRAINT manual_report_report_type_check CHECK (((report_type)::text = ANY (ARRAY[('BREAKDOWN'::character varying)::text, ('OVERFLOW'::character varying)::text, ('DEPTH'::character varying)::text, ('WEATHER'::character varying)::text, ('FUEL_STATUS'::character varying)::text, ('OTHER'::character varying)::text])))
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
    CONSTRAINT plan_status_check CHECK (((status)::text = ANY (ARRAY[('PROPOSED'::character varying)::text, ('APPROVED'::character varying)::text, ('REJECTED'::character varying)::text])))
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
-- Name: site_contract; Type: TABLE; Schema: operational; Owner: -
--

CREATE TABLE operational.site_contract (
    site_contract_id bigint NOT NULL,
    area_code character varying(30) NOT NULL,
    sales_contract_id bigint NOT NULL,
    valid_from date NOT NULL,
    valid_to date,
    catatan text,
    created_by character varying(150),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_sc_periode CHECK (((valid_to IS NULL) OR (valid_to >= valid_from)))
);


--
-- Name: TABLE site_contract; Type: COMMENT; Schema: operational; Owner: -
--

COMMENT ON TABLE operational.site_contract IS 'Pemetaan site (work_area) ↔ kontrak penjualan (BRD-v7 W3): periode berlaku; informatif — TIDAK memblokir trip (keputusan default).';


--
-- Name: site_contract_site_contract_id_seq; Type: SEQUENCE; Schema: operational; Owner: -
--

CREATE SEQUENCE operational.site_contract_site_contract_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: site_contract_site_contract_id_seq; Type: SEQUENCE OWNED BY; Schema: operational; Owner: -
--

ALTER SEQUENCE operational.site_contract_site_contract_id_seq OWNED BY operational.site_contract.site_contract_id;


--
-- Name: site_line; Type: TABLE; Schema: operational; Owner: -
--

CREATE TABLE operational.site_line (
    line_id bigint NOT NULL,
    line_code character varying(40) NOT NULL,
    area_code character varying(30) NOT NULL,
    line_no integer NOT NULL,
    geom public.geometry(LineString,4326) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: site_line_line_id_seq; Type: SEQUENCE; Schema: operational; Owner: -
--

CREATE SEQUENCE operational.site_line_line_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: site_line_line_id_seq; Type: SEQUENCE OWNED BY; Schema: operational; Owner: -
--

ALTER SEQUENCE operational.site_line_line_id_seq OWNED BY operational.site_line.line_id;


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
-- Name: site_strip_v; Type: VIEW; Schema: operational; Owner: -
--

CREATE VIEW operational.site_strip_v AS
 SELECT l1.area_code,
    l1.line_no AS strip_no,
    l1.line_id AS line_id_awal,
    l2.line_id AS line_id_akhir,
    l1.line_code AS code_awal,
    l2.line_code AS code_akhir,
    public.st_makepolygon(public.st_makeline(ARRAY[l1.geom, public.st_makeline(public.st_endpoint(l1.geom), public.st_startpoint(l2.geom)), l2.geom, public.st_makeline(public.st_endpoint(l2.geom), public.st_startpoint(l1.geom))])) AS geom
   FROM (operational.site_line l1
     JOIN operational.site_line l2 ON ((((l2.area_code)::text = (l1.area_code)::text) AND (l2.line_no = (l1.line_no + 1)))));


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
    line_id bigint,
    discharge_fence_code character varying(50),
    CONSTRAINT chk_trip_ts_order CHECK ((((ts_loading_start IS NULL) OR (ts_departed IS NULL) OR (ts_loading_start < ts_departed)) AND ((ts_departed IS NULL) OR (ts_arrived IS NULL) OR (ts_departed < ts_arrived)) AND ((ts_arrived IS NULL) OR (ts_discharge_start IS NULL) OR (ts_arrived < ts_discharge_start)) AND ((ts_discharge_start IS NULL) OR (ts_discharge_end IS NULL) OR (ts_discharge_start < ts_discharge_end)) AND ((ts_discharge_end IS NULL) OR (ts_bap_signed IS NULL) OR (ts_discharge_end < ts_bap_signed)) AND ((ts_bap_signed IS NULL) OR (ts_closed IS NULL) OR (ts_bap_signed < ts_closed)))),
    CONSTRAINT trip_discharge_method_check CHECK (((discharge_method)::text = ANY (ARRAY[('PUMP_ASHORE'::character varying)::text, ('RAINBOWING'::character varying)::text, ('BOTTOM_DUMP'::character varying)::text, ('LAINNYA'::character varying)::text]))),
    CONSTRAINT trip_status_check CHECK (((status)::text = ANY (ARRAY[('LOADING'::character varying)::text, ('SURVEY_SETTLING'::character varying)::text, ('DEPARTED'::character varying)::text, ('ARRIVED'::character varying)::text, ('SURVEY_DISCHARGE'::character varying)::text, ('DISCHARGING'::character varying)::text, ('BAP_RETURN'::character varying)::text, ('INVOICED'::character varying)::text, ('SETTLED'::character varying)::text, ('CLOSED'::character varying)::text, ('CANCELLED'::character varying)::text, ('PARTIAL'::character varying)::text, ('CLAIM'::character varying)::text])))
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
-- Name: trip_doc_check; Type: TABLE; Schema: operational; Owner: -
--

CREATE TABLE operational.trip_doc_check (
    check_id bigint NOT NULL,
    trip_id bigint NOT NULL,
    result character varying(10) NOT NULL,
    catatan text,
    verified_by character varying(150) NOT NULL,
    verified_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: trip_doc_check_check_id_seq; Type: SEQUENCE; Schema: operational; Owner: -
--

CREATE SEQUENCE operational.trip_doc_check_check_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: trip_doc_check_check_id_seq; Type: SEQUENCE OWNED BY; Schema: operational; Owner: -
--

ALTER SEQUENCE operational.trip_doc_check_check_id_seq OWNED BY operational.trip_doc_check.check_id;


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
-- Name: voyage_doc; Type: TABLE; Schema: operational; Owner: -
--

CREATE TABLE operational.voyage_doc (
    doc_id bigint NOT NULL,
    doc_no character varying(40) NOT NULL,
    qr_token character varying(16) NOT NULL,
    doc_type character varying(20) NOT NULL,
    trip_id bigint NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    nor_id uuid,
    status character varying(12) DEFAULT 'DRAFT'::character varying NOT NULL,
    submitted_by character varying(150),
    submitted_at timestamp with time zone,
    decided_at timestamp with time zone,
    is_locked boolean DEFAULT false NOT NULL,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_vd_status CHECK (((status)::text = ANY ((ARRAY['DRAFT'::character varying, 'SUBMITTED'::character varying, 'APPROVED'::character varying, 'REJECTED'::character varying])::text[]))),
    CONSTRAINT chk_vd_type CHECK (((doc_type)::text = ANY ((ARRAY['BA_KEBERANGKATAN'::character varying, 'BA_KEDATANGAN'::character varying])::text[])))
);


--
-- Name: voyage_doc_doc_id_seq; Type: SEQUENCE; Schema: operational; Owner: -
--

CREATE SEQUENCE operational.voyage_doc_doc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: voyage_doc_doc_id_seq; Type: SEQUENCE OWNED BY; Schema: operational; Owner: -
--

ALTER SEQUENCE operational.voyage_doc_doc_id_seq OWNED BY operational.voyage_doc.doc_id;


--
-- Name: voyage_plan; Type: TABLE; Schema: operational; Owner: -
--

CREATE TABLE operational.voyage_plan (
    plan_id bigint NOT NULL,
    trip_id bigint NOT NULL,
    plan_no character varying(40) NOT NULL,
    qr_token character varying(16) NOT NULL,
    do_seq integer,
    route_note text,
    etd_plan timestamp with time zone,
    eta_plan timestamp with time zone,
    discharge_window character varying(80),
    discharge_method_plan character varying(20),
    volume_plan_m3 numeric(14,3),
    nav_note text,
    status character varying(12) DEFAULT 'DRAFT'::character varying NOT NULL,
    created_by character varying(150),
    submitted_by character varying(150),
    submitted_at timestamp with time zone,
    decided_at timestamp with time zone,
    is_locked boolean DEFAULT false NOT NULL,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_vp_status CHECK (((status)::text = ANY ((ARRAY['DRAFT'::character varying, 'SUBMITTED'::character varying, 'APPROVED'::character varying, 'REJECTED'::character varying])::text[])))
);


--
-- Name: voyage_plan_plan_id_seq; Type: SEQUENCE; Schema: operational; Owner: -
--

CREATE SEQUENCE operational.voyage_plan_plan_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: voyage_plan_plan_id_seq; Type: SEQUENCE OWNED BY; Schema: operational; Owner: -
--

ALTER SEQUENCE operational.voyage_plan_plan_id_seq OWNED BY operational.voyage_plan.plan_id;


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
    CONSTRAINT waiting_log_cause_check CHECK (((cause)::text = ANY (ARRAY[('ANTRIAN_KAPAL'::character varying)::text, ('IZIN_MASUK'::character varying)::text, ('PASUT'::character varying)::text, ('AREA_BELUM_SIAP'::character varying)::text, ('CUACA'::character varying)::text, ('DOKUMEN'::character varying)::text, ('LAINNYA'::character varying)::text])))
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
    zone_code character varying(30),
    geom public.geometry(Polygon,4326),
    fence_code character varying(50),
    CONSTRAINT chk_work_area_quota_used CHECK (((quota_used_m3 IS NULL) OR (quota_used_m3 >= (0)::numeric)))
);


--
-- Name: work_zone; Type: TABLE; Schema: operational; Owner: -
--

CREATE TABLE operational.work_zone (
    zone_code character varying(30) NOT NULL,
    zone_name character varying(150) NOT NULL,
    permit_no character varying(50),
    status character varying(20) DEFAULT 'AKTIF'::character varying NOT NULL,
    geom public.geometry(MultiPolygon,4326) NOT NULL,
    quota_m3 numeric(14,3),
    quota_used_m3 numeric(14,3) DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_wz_quota_used CHECK ((quota_used_m3 >= (0)::numeric)),
    CONSTRAINT chk_wz_status CHECK (((status)::text = ANY ((ARRAY['AKTIF'::character varying, 'DITUTUP'::character varying])::text[])))
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
-- Name: audit_log_arch; Type: TABLE; Schema: param; Owner: -
--

CREATE TABLE param.audit_log_arch (
    audit_id bigint NOT NULL,
    tabel text NOT NULL,
    record_key text NOT NULL,
    kolom text NOT NULL,
    nilai_lama text,
    nilai_baru text,
    diubah_oleh text NOT NULL,
    diubah_pada timestamp with time zone NOT NULL,
    diarsip_pada timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE audit_log_arch; Type: COMMENT; Schema: param; Owner: -
--

COMMENT ON TABLE param.audit_log_arch IS 'Arsip param.audit_log > 12 bulan (BRD-v7 W1, keputusan retensi) — dipindah command arsip_audit (cron harian, idempoten); tanpa penghapusan permanen.';


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
-- Name: doc_code; Type: TABLE; Schema: param; Owner: -
--

CREATE TABLE param.doc_code (
    code_kind character varying(10) NOT NULL,
    code character varying(20) NOT NULL,
    label character varying(150),
    ref_table character varying(40),
    ref_key character varying(40),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: doc_seq; Type: TABLE; Schema: param; Owner: -
--

CREATE TABLE param.doc_seq (
    jenis character varying(10) NOT NULL,
    scope character varying(60) NOT NULL,
    thbl character varying(6) NOT NULL,
    last_no integer DEFAULT 0 NOT NULL
);


--
-- Name: module_acl; Type: TABLE; Schema: param; Owner: -
--

CREATE TABLE param.module_acl (
    modul_key character varying(40) NOT NULL,
    peran character varying(12) NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE module_acl; Type: COMMENT; Schema: param; Owner: -
--

COMMENT ON TABLE param.module_acl IS 'RBAC per modul (BRD-v7 W1): matriks modul×peran — dibaca loader _akses() views.py; guardrail: ADMIN×pengaturan tak boleh dihapus (server-side).';


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
    CONSTRAINT charter_contract_scheme_check CHECK (((scheme)::text = ANY (ARRAY[('PER_M3'::character varying)::text, ('PER_TRIP'::character varying)::text, ('TC'::character varying)::text]))),
    CONSTRAINT chk_cc_status CHECK (((status)::text = ANY (ARRAY[('DRAFT'::character varying)::text, ('AKTIF'::character varying)::text, ('EXPIRED'::character varying)::text, ('TERMINATED'::character varying)::text])))
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
    CONSTRAINT invoice_matching_result_check CHECK (((matching_result)::text = ANY (ARRAY[('MATCH'::character varying)::text, ('DIFF'::character varying)::text])))
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
    CONSTRAINT statement_line_payable_status_check CHECK (((payable_status)::text = ANY (ARRAY[('WAITING'::character varying)::text, ('TRIGGERED'::character varying)::text, ('PAID'::character varying)::text]))),
    CONSTRAINT statement_line_scheme_check CHECK (((scheme)::text = ANY (ARRAY[('PER_M3'::character varying)::text, ('PER_TRIP'::character varying)::text, ('TC'::character varying)::text]))),
    CONSTRAINT statement_line_trigger_event_check CHECK (((trigger_event)::text = ANY (ARRAY[('DEPOSIT_DEDUCTED'::character varying)::text, ('PO_COMPLETED'::character varying)::text])))
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
    CONSTRAINT draft_survey_tipe_check CHECK (((tipe)::text = ANY (ARRAY[('MUAT'::character varying)::text, ('AWAL_BONGKAR'::character varying)::text, ('AKHIR_BONGKAR'::character varying)::text])))
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
-- Name: instrument; Type: TABLE; Schema: survey; Owner: -
--

CREATE TABLE survey.instrument (
    instrument_code character varying(30) NOT NULL,
    nama character varying(150) NOT NULL,
    tipe character varying(20) DEFAULT 'LAIN'::character varying NOT NULL,
    status character varying(20) DEFAULT 'AKTIF'::character varying NOT NULL,
    cert_no character varying(60),
    issuer character varying(120),
    issued_at date,
    expires_at date,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_ins_status CHECK (((status)::text = ANY ((ARRAY['AKTIF'::character varying, 'PERBAIKAN'::character varying, 'KELUAR'::character varying])::text[]))),
    CONSTRAINT chk_ins_tipe CHECK (((tipe)::text = ANY ((ARRAY['ECHOSOUNDER'::character varying, 'GPS'::character varying, 'SONDE'::character varying, 'LAIN'::character varying])::text[])))
);


--
-- Name: mission; Type: TABLE; Schema: survey; Owner: -
--

CREATE TABLE survey.mission (
    mission_id bigint NOT NULL,
    mission_no character varying(60) NOT NULL,
    fleet_code character varying(30) NOT NULL,
    mission_kind character varying(12) NOT NULL,
    target_type character varying(12) NOT NULL,
    target_code character varying(40),
    lat double precision,
    lng double precision,
    purpose text,
    planned_start timestamp with time zone NOT NULL,
    planned_end timestamp with time zone NOT NULL,
    ts_departed timestamp with time zone,
    ts_returned timestamp with time zone,
    engine_hours numeric(10,2),
    status character varying(12) DEFAULT 'RENCANA'::character varying NOT NULL,
    leader_name character varying(150),
    crew jsonb DEFAULT '[]'::jsonb NOT NULL,
    mon_wo_id bigint,
    is_locked boolean DEFAULT false NOT NULL,
    tenant_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    source character varying(12) DEFAULT 'MANUAL'::character varying NOT NULL,
    schedule_id bigint,
    incident_id bigint,
    CONSTRAINT chk_mission_source CHECK (((source)::text = ANY ((ARRAY['MANUAL'::character varying, 'RUTIN'::character varying])::text[]))),
    CONSTRAINT chk_msn_jendela CHECK ((planned_end > planned_start)),
    CONSTRAINT chk_msn_kind CHECK (((mission_kind)::text = ANY ((ARRAY['BATHY'::character varying, 'SAMP'::character varying, 'ENV'::character varying, 'BUOY'::character varying, 'ANGKUT'::character varying, 'MAINT'::character varying, 'PATROLI'::character varying])::text[]))),
    CONSTRAINT chk_msn_koordinat CHECK ((((target_type)::text <> 'KOORDINAT'::text) OR ((lat IS NOT NULL) AND (lng IS NOT NULL)))),
    CONSTRAINT chk_msn_status CHECK (((status)::text = ANY ((ARRAY['RENCANA'::character varying, 'DISETUJUI'::character varying, 'BERANGKAT'::character varying, 'DI LAUT'::character varying, 'PULANG'::character varying, 'LAPORAN'::character varying, 'SELESAI'::character varying, 'DITOLAK'::character varying, 'BATAL'::character varying])::text[]))),
    CONSTRAINT chk_msn_target CHECK (((target_type)::text = ANY ((ARRAY['ZONE'::character varying, 'WORK_AREA'::character varying, 'STATION'::character varying, 'KOORDINAT'::character varying])::text[])))
);


--
-- Name: COLUMN mission.source; Type: COMMENT; Schema: survey; Owner: -
--

COMMENT ON COLUMN survey.mission.source IS 'feat-v8.1: asal misi — MANUAL (form OPS/ADMIN) / RUTIN (generator dari enviro.mon_schedule)';


--
-- Name: COLUMN mission.schedule_id; Type: COMMENT; Schema: survey; Owner: -
--

COMMENT ON COLUMN survey.mission.schedule_id IS 'feat-v8.1: jadwal monitoring asal bila misi dibuat generator rutin (nullable)';


--
-- Name: COLUMN mission.incident_id; Type: COMMENT; Schema: survey; Owner: -
--

COMMENT ON COLUMN survey.mission.incident_id IS 'FR-4-14: insiden HSE yang terjadi selama misi (nullable, 1-1 per misi)';


--
-- Name: mission_check; Type: TABLE; Schema: survey; Owner: -
--

CREATE TABLE survey.mission_check (
    check_id bigint NOT NULL,
    mission_id bigint NOT NULL,
    item_key character varying(20) NOT NULL,
    status character varying(8) DEFAULT 'TIDAK'::character varying NOT NULL,
    catatan text,
    verified_by character varying(150),
    verified_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_mck_status CHECK (((status)::text = ANY ((ARRAY['OK'::character varying, 'TIDAK'::character varying])::text[])))
);


--
-- Name: mission_check_check_id_seq; Type: SEQUENCE; Schema: survey; Owner: -
--

ALTER TABLE survey.mission_check ALTER COLUMN check_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME survey.mission_check_check_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: mission_cost; Type: TABLE; Schema: survey; Owner: -
--

CREATE TABLE survey.mission_cost (
    cost_id bigint NOT NULL,
    mission_id bigint NOT NULL,
    category character varying(12) NOT NULL,
    amount numeric(16,2) NOT NULL,
    qty_liter numeric(12,2),
    engine_meter numeric(12,2),
    source character varying(12) DEFAULT 'MANUAL'::character varying NOT NULL,
    description text,
    created_by character varying(150),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_mcs_cat CHECK (((category)::text = ANY ((ARRAY['BBM'::character varying, 'CREW'::character varying, 'LOGISTIK'::character varying, 'LAIN'::character varying])::text[]))),
    CONSTRAINT mission_cost_amount_check CHECK ((amount >= (0)::numeric))
);


--
-- Name: mission_cost_cost_id_seq; Type: SEQUENCE; Schema: survey; Owner: -
--

ALTER TABLE survey.mission_cost ALTER COLUMN cost_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME survey.mission_cost_cost_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: mission_log; Type: TABLE; Schema: survey; Owner: -
--

CREATE TABLE survey.mission_log (
    log_id bigint NOT NULL,
    mission_id bigint NOT NULL,
    logged_at timestamp with time zone DEFAULT now() NOT NULL,
    log_type character varying(12) NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_by character varying(150),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_mlg_type CHECK (((log_type)::text = ANY ((ARRAY['KEGIATAN'::character varying, 'CUACA'::character varying, 'HAMBATAN'::character varying, 'NARATIF'::character varying])::text[])))
);


--
-- Name: mission_log_log_id_seq; Type: SEQUENCE; Schema: survey; Owner: -
--

ALTER TABLE survey.mission_log ALTER COLUMN log_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME survey.mission_log_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: mission_mission_id_seq; Type: SEQUENCE; Schema: survey; Owner: -
--

ALTER TABLE survey.mission ALTER COLUMN mission_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME survey.mission_mission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: mission_result; Type: TABLE; Schema: survey; Owner: -
--

CREATE TABLE survey.mission_result (
    result_id bigint NOT NULL,
    mission_id bigint NOT NULL,
    kind character varying(12) NOT NULL,
    summary jsonb DEFAULT '{}'::jsonb NOT NULL,
    station_code character varying(30),
    doc_ref bigint,
    instrument_code character varying(30),
    created_by character varying(150),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_mrs_kind CHECK (((kind)::text = ANY ((ARRAY['BATHY'::character varying, 'SAMP'::character varying, 'ENV'::character varying, 'BUOY'::character varying, 'ANGKUT'::character varying, 'MAINT'::character varying, 'PATROLI'::character varying])::text[])))
);


--
-- Name: mission_result_result_id_seq; Type: SEQUENCE; Schema: survey; Owner: -
--

ALTER TABLE survey.mission_result ALTER COLUMN result_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME survey.mission_result_result_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


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
    CONSTRAINT geofence_event_event_check CHECK (((event)::text = ANY (ARRAY[('ENTRY'::character varying)::text, ('EXIT'::character varying)::text])))
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
-- Name: reading_default; Type: TABLE ATTACH; Schema: enviro_raw; Owner: -
--

ALTER TABLE ONLY enviro_raw.reading ATTACH PARTITION enviro_raw.reading_default DEFAULT;


--
-- Name: reading_p2026_09; Type: TABLE ATTACH; Schema: enviro_raw; Owner: -
--

ALTER TABLE ONLY enviro_raw.reading ATTACH PARTITION enviro_raw.reading_p2026_09 FOR VALUES FROM ('2026-09-01 00:00:00+00') TO ('2026-10-01 00:00:00+00');


--
-- Name: reading_p2026_10; Type: TABLE ATTACH; Schema: enviro_raw; Owner: -
--

ALTER TABLE ONLY enviro_raw.reading ATTACH PARTITION enviro_raw.reading_p2026_10 FOR VALUES FROM ('2026-10-01 00:00:00+00') TO ('2026-11-01 00:00:00+00');


--
-- Name: reading_p2026_11; Type: TABLE ATTACH; Schema: enviro_raw; Owner: -
--

ALTER TABLE ONLY enviro_raw.reading ATTACH PARTITION enviro_raw.reading_p2026_11 FOR VALUES FROM ('2026-11-01 00:00:00+00') TO ('2026-12-01 00:00:00+00');


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
-- Name: doc_verification verification_id; Type: DEFAULT; Schema: document; Owner: -
--

ALTER TABLE ONLY document.doc_verification ALTER COLUMN verification_id SET DEFAULT nextval('document.doc_verification_verification_id_seq'::regclass);


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
-- Name: doc_approval approval_id; Type: DEFAULT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.doc_approval ALTER COLUMN approval_id SET DEFAULT nextval('operational.doc_approval_approval_id_seq'::regclass);


--
-- Name: line_compliance compliance_id; Type: DEFAULT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.line_compliance ALTER COLUMN compliance_id SET DEFAULT nextval('operational.line_compliance_compliance_id_seq'::regclass);


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
-- Name: site_contract site_contract_id; Type: DEFAULT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.site_contract ALTER COLUMN site_contract_id SET DEFAULT nextval('operational.site_contract_site_contract_id_seq'::regclass);


--
-- Name: site_line line_id; Type: DEFAULT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.site_line ALTER COLUMN line_id SET DEFAULT nextval('operational.site_line_line_id_seq'::regclass);


--
-- Name: site_permit site_permit_id; Type: DEFAULT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.site_permit ALTER COLUMN site_permit_id SET DEFAULT nextval('operational.site_permit_site_permit_id_seq'::regclass);


--
-- Name: trip trip_id; Type: DEFAULT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.trip ALTER COLUMN trip_id SET DEFAULT nextval('operational.trip_trip_id_seq'::regclass);


--
-- Name: trip_doc_check check_id; Type: DEFAULT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.trip_doc_check ALTER COLUMN check_id SET DEFAULT nextval('operational.trip_doc_check_check_id_seq'::regclass);


--
-- Name: voyage_doc doc_id; Type: DEFAULT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.voyage_doc ALTER COLUMN doc_id SET DEFAULT nextval('operational.voyage_doc_doc_id_seq'::regclass);


--
-- Name: voyage_plan plan_id; Type: DEFAULT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.voyage_plan ALTER COLUMN plan_id SET DEFAULT nextval('operational.voyage_plan_plan_id_seq'::regclass);


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
-- Data for Name: deposit; Type: TABLE DATA; Schema: buyer; Owner: -
--

COPY buyer.deposit (deposit_id, sales_contract_id, currency_code, balance, tenant_id, created_at, updated_at) FROM stdin;
1	1	IDR	364506300.00	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
2	2	IDR	0.00	\N	2026-09-11 04:37:38.473406+00	2026-09-11 04:37:38.473406+00
\.


--
-- Data for Name: deposit_transaction; Type: TABLE DATA; Schema: buyer; Owner: -
--

COPY buyer.deposit_transaction (dep_trans_id, deposit_id, tipe, amount, trip_id, bap_id, tx_date, ref_doc, created_by, ledger_entry_id, tenant_id, created_at, updated_at) FROM stdin;
1	1	TOP_UP	700000000.00	\N	\N	2026-01-12	TRF-2026-0117	finance	1	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
2	1	DEDUCTION	112875000.00	899	85	2026-09-02	BAP-2026-0085	system	2	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
3	1	DEDUCTION	107124997.00	903	86	2026-09-04	BAP-2026-0086	system	3	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
4	1	ADJUSTMENT	3.00	\N	\N	2026-09-04	KOREKSI-PEMBULATAN-0086	finance	4	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
5	1	DEDUCTION	115493700.00	907	87	2026-09-07	BAP-2026-0087	system	5	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
6	2	TOP_UP	50000000.00	\N	\N	2026-09-01	TRF-2026-0301	finance	6	\N	2026-09-11 04:37:38.474519+00	2026-09-11 04:37:38.474519+00
7	2	DEDUCTION	50000000.00	910	88	2026-09-10	BAP-2026-0088	system	7	\N	2026-09-11 04:37:38.483379+00	2026-09-11 04:37:38.483379+00
\.


--
-- Data for Name: info; Type: TABLE DATA; Schema: buyer; Owner: -
--

COPY buyer.info (buyer_code, buyer_name, pic_name, email, created_at) FROM stdin;
B-PRN	PT Pembangunan Reklamasi Nusantara	Ir. Rahmat	rahmat@prn.co.id	2026-09-11 04:37:38.232279+00
B-WKR	PT Wijaya Karya Reklamasi	Andi Prasetyo	andi@wkr.co.id	2026-09-11 04:37:38.232279+00
B-PSR	PT Pulau Sejahtara Reklamasi	Ir. Sinta Wijaya	sinta@psr.co.id	2026-09-11 04:37:38.471111+00
B-XPD	Pan Jurong Reclamation Pte Ltd	Lim Wei Sheng	ops@panjurong.sg	2026-09-11 04:37:38.910326+00
\.


--
-- Data for Name: ledger_hist; Type: TABLE DATA; Schema: buyer; Owner: -
--

COPY buyer.ledger_hist (id, buyer_code, entry_date, ref_type, ref_doc, debit, credit, running_balance) FROM stdin;
1	B-PRN	2026-01-12	DEPOSIT_TOPUP	TRF-2026-0117	0.00	700000000.00	700000000.00
2	B-PRN	2026-09-02	BAP_DEDUCTION	BAP-2026-0085	112875000.00	0.00	587125000.00
3	B-PRN	2026-09-04	BAP_DEDUCTION	BAP-2026-0086	107124997.00	0.00	480000003.00
4	B-PRN	2026-09-04	ADJUSTMENT	KOREKSI-PEMBULATAN-0086	3.00	0.00	480000000.00
5	B-PRN	2026-09-07	BAP_DEDUCTION	BAP-2026-0087	115493700.00	0.00	364506300.00
6	B-PSR	2026-09-01	DEPOSIT_TOPUP	TRF-2026-0301	0.00	50000000.00	50000000.00
7	B-PSR	2026-09-10	BAP_DEDUCTION	BAP-2026-0088	50000000.00	0.00	0.00
\.


--
-- Data for Name: site; Type: TABLE DATA; Schema: buyer; Owner: -
--

COPY buyer.site (buyer_site_id, buyer_code, site_code, note) FROM stdin;
1	B-PRN	SITE-G	Site bongkar utama SC-2026-014
2	B-PRN	ETAP-2	Etap lanjutan reklamasi
3	B-WKR	MARINA-JAYA	Pengisian marina
\.


--
-- Data for Name: bap; Type: TABLE DATA; Schema: commercial; Owner: -
--

COPY commercial.bap (bap_id, bap_no, trip_id, volume_m3, status, signed_vessel_by, signed_vessel_at, signed_customer_by, signed_customer_at, signed_surveyor_by, signed_surveyor_at, issued_at, tenant_id, created_at, updated_at, signed_vessel_img, signed_customer_img, signed_surveyor_img) FROM stdin;
86	BAP-2026-0086	903	4982.558	SIGNED	Capt. Dedi (Nakhoda MV Sinar Laut 09)	2026-09-04 00:10:00+00	Ir. Rahmat (PT PRN)	2026-09-04 00:08:00+00	Budi Santoso	2026-09-04 00:09:00+00	2026-09-04 00:12:00+00	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00	\N	\N	\N
87	BAP-2026-0087	907	5371.800	SIGNED	H. Bakti (Nakhoda MV Sinar Laut 02)	2026-09-07 07:35:00+00	Ir. Rahmat (PT PRN)	2026-09-07 07:33:00+00	Budi Santoso	2026-09-07 07:34:00+00	2026-09-07 07:36:00+00	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00	\N	\N	\N
88	BAP-2026-0088	910	3900.000	CORRECTED	H. Andi (Nakhoda MV Sinar Laut 05)	2026-09-09 19:12:00+00	Ir. Sinta Wijaya (PT PSR)	2026-09-09 19:13:00+00	Budi Santoso	2026-09-09 19:14:00+00	2026-09-09 19:15:00+00	\N	2026-09-11 04:37:38.481079+00	2026-09-11 04:37:38.481079+00	\N	\N	\N
85	BAP-2026-0085	899	5250.000	SIGNED	H. Andi (Nakhoda MV Sinar Laut 05)	2026-09-01 22:10:00+00	Ir. Rahmat (PT PRN)	2026-09-01 22:08:00+00	Budi Santoso	2026-09-01 22:09:00+00	2026-09-01 22:12:00+00	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00	\N	\N	\N
\.


--
-- Data for Name: bap_correction; Type: TABLE DATA; Schema: commercial; Owner: -
--

COPY commercial.bap_correction (bap_correction_id, correction_no, bap_id, delta_volume_m3, reason, approved_by, approved_at, tenant_id, created_at) FROM stdin;
1	COR-2026-001	88	-50.000	Kesalahan pembacaan sisa material di hopper pada survey akhir; volume terkoreksi 3.950 → 3.900 m³.	finance	2026-09-12 03:00:00+00	\N	2026-09-11 04:37:38.486308+00
\.


--
-- Data for Name: bap_objection; Type: TABLE DATA; Schema: commercial; Owner: -
--

COPY commercial.bap_objection (bap_objection_id, bap_id, raised_by, raised_at, content, resolution, resolved_at, status, tenant_id, created_at) FROM stdin;
1	88	Ir. Sinta Wijaya (PT PSR)	2026-09-10 02:00:00+00	Kadar lumpur hasil QA bongkar 6,2% melebihi spek kontrak maks 5% — mohon penyesuaian tagihan.	Disepakati: sampel pengujian ulang laboratorium rujukan menunjukkan 4,8% (dalam spek). Tagihan TETAP sesuai BAP; credit note tidak terbit (FR-05-07).	2026-09-11 08:00:00+00	RESOLVED	\N	2026-09-11 04:37:38.485244+00
\.


--
-- Data for Name: delivery_order; Type: TABLE DATA; Schema: commercial; Owner: -
--

COPY commercial.delivery_order (do_id, do_no, po_id, vessel_name, volume_m3, do_date, status, fleet_code) FROM stdin;
330	DO-2026-0330	86	MV Sinar Laut 09	5001.120	2026-09-03	CLOSED	SL09
341	DO-2026-0341	88	MV Sinar Laut 02	5420.500	2026-09-05	CLOSED	SL02
329	DO-2026-0329	85	MV Sinar Laut 05	5250.000	2026-09-01	CLOSED	SL05
353	DO-2026-0353	91	MV Bahari 09	3500.000	2026-09-09	CANCELLED	SL09
352	DO-2026-0352	90	MV Sinar Laut 05	4000.000	2026-09-08	CLOSED	SL05
354	DO-2026-0399	88	—	5200.000	2026-09-21	ISSUED	\N
355	DO-2026-0400	90	—	3200.000	2026-09-21	ISSUED	\N
\.


--
-- Data for Name: purchase_order; Type: TABLE DATA; Schema: commercial; Owner: -
--

COPY commercial.purchase_order (po_id, po_no, buyer_code, contract_number, volume_m3, delivered_m3, po_date, status, sales_contract_id) FROM stdin;
91	PO-2026-0091	B-PSR	SC-2026-015	3500.000	0.000	2026-09-08	CANCELLED	2
86	PO-2026-0086	B-PRN	SC-2026-014	5001.120	4982.558	2026-09-01	COMPLETED	1
88	PO-2026-0088	B-PRN	SC-2026-014	5420.500	5371.800	2026-09-04	COMPLETED	1
90	PO-2026-0090	B-PSR	SC-2026-015	4000.000	3900.000	2026-09-07	COMPLETED	2
85	PO-2026-0085	B-PRN	SC-2026-014	5250.000	5250.000	2026-08-28	COMPLETED	1
\.


--
-- Data for Name: qa_sample; Type: TABLE DATA; Schema: commercial; Owner: -
--

COPY commercial.qa_sample (qa_sample_id, trip_id, tipe, sampled_at, sampled_by, sales_contract_id, results, verdict, claim_status, tenant_id, created_at, updated_at) FROM stdin;
9a000000-0000-0000-0000-00000000a907	907	MUAT	2026-09-05 06:40:00+00	Tim QA Internal	1	{"gradasi": "MEDIUM", "mud_content_pct": 2.8, "kadar_organik_pct": 1.2}	PASS	\N	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
9a000000-0000-0000-0000-00000000b907	907	BONGKAR	2026-09-07 03:00:00+00	Tim QA Internal	1	{"gradasi": "MEDIUM", "mud_content_pct": 3.1, "kadar_organik_pct": 1.4}	PASS	\N	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
9a000000-0000-0000-0000-00000000a910	910	MUAT	2026-09-08 01:00:00+00	Tim QA Internal	2	{"gradasi": "MEDIUM", "mud_content_pct": 3.0, "kadar_organik_pct": 1.3}	PASS	\N	\N	2026-09-11 04:37:38.484289+00	2026-09-11 04:37:38.484289+00
9a000000-0000-0000-0000-00000000b910	910	BONGKAR	2026-09-09 16:30:00+00	Tim QA Internal	2	{"gradasi": "MEDIUM", "mud_content_pct": 6.2, "kadar_organik_pct": 2.1}	FAIL	FILED	\N	2026-09-11 04:37:38.484289+00	2026-09-11 04:37:38.484289+00
\.


--
-- Data for Name: sales_contract; Type: TABLE DATA; Schema: commercial; Owner: -
--

COPY commercial.sales_contract (sales_contract_id, contract_no, buyer_code, site_code, date_start, date_end, volume_min_m3, volume_max_m3, price_per_m3, currency_code, sand_spec_id, payment_mode, free_time_hours, standby_rate_per_hour, status, is_active, tenant_id, created_at, updated_at) FROM stdin;
1	SC-2026-014	B-PRN	SITE-G	2026-01-10	2026-12-31	200000.000	300000.000	21500.0000	IDR	1	DEPOSIT	12	4500000.00	AKTIF	t	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
2	SC-2026-015	B-PSR	SITE-G	2026-03-01	2026-12-31	50000.000	150000.000	21000.0000	IDR	1	DEPOSIT	12	4000000.00	AKTIF	t	\N	2026-09-11 04:37:38.472003+00	2026-09-11 04:37:38.472003+00
90	SC-2026-X01	B-XPD	SITE-JRG	2026-08-10	2027-08-09	150000.000	400000.000	10.0000	USD	1	PELUNASAN	24	0.00	AKTIF	t	\N	2026-09-11 04:37:38.921629+00	2026-09-11 04:37:38.921629+00
\.


--
-- Data for Name: sand_spec; Type: TABLE DATA; Schema: commercial; Owner: -
--

COPY commercial.sand_spec (sand_spec_id, name, params, tenant_id, created_at, updated_at) FROM stdin;
1	Spec Pasir Reklamasi G	{"gradasi": "MEDIUM", "kadar_organik_pct": 3, "max_mud_content_pct": 5}	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
\.


--
-- Data for Name: shipment_monthly; Type: TABLE DATA; Schema: commercial; Owner: -
--

COPY commercial.shipment_monthly (bulan, buyer_code, volume_m3, source, created_at) FROM stdin;
2026-04-01	B-PRN	21000.000	DEMO_SEED	2026-09-21 07:18:37.299114+00
2026-05-01	B-PRN	22500.000	DEMO_SEED	2026-09-21 07:18:37.299114+00
2026-06-01	B-PRN	19800.000	DEMO_SEED	2026-09-21 07:18:37.299114+00
2026-07-01	B-PRN	24600.000	DEMO_SEED	2026-09-21 07:18:37.299114+00
2026-08-01	B-PRN	27300.000	DEMO_SEED	2026-09-21 07:18:37.299114+00
2026-09-01	B-PRN	34800.000	DEMO_SEED	2026-09-21 07:18:37.299114+00
2026-04-01	B-PSR	12400.000	DEMO_SEED	2026-09-21 07:18:37.299114+00
2026-05-01	B-PSR	13200.000	DEMO_SEED	2026-09-21 07:18:37.299114+00
2026-06-01	B-PSR	10900.000	DEMO_SEED	2026-09-21 07:18:37.299114+00
2026-07-01	B-PSR	14100.000	DEMO_SEED	2026-09-21 07:18:37.299114+00
2026-08-01	B-PSR	15600.000	DEMO_SEED	2026-09-21 07:18:37.299114+00
2026-09-01	B-PSR	15200.000	DEMO_SEED	2026-09-21 07:18:37.299114+00
2026-06-01	B-WKR	5200.000	DEMO_SEED	2026-09-21 07:18:37.299114+00
2026-08-01	B-WKR	6100.000	DEMO_SEED	2026-09-21 07:18:37.299114+00
2026-09-01	B-WKR	7400.000	DEMO_SEED	2026-09-21 07:18:37.299114+00
\.


--
-- Data for Name: standby_claim; Type: TABLE DATA; Schema: commercial; Owner: -
--

COPY commercial.standby_claim (standby_claim_id, trip_id, free_time_minutes, standby_minutes, billable_minutes, rate, amount, status, disposed_by, disposed_at, tenant_id, created_at, updated_at) FROM stdin;
1	907	720	900	180	4500000.00	13500000.00	DISPOSED_TAGIH	finance	2026-09-07 08:00:00+00	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
2	910	720	120	0	4000000.00	0.00	DISPOSED_HANGUS	finance	2026-09-09 22:00:00+00	\N	2026-09-11 04:37:38.487835+00	2026-09-11 04:37:38.487835+00
\.


--
-- Data for Name: doc_verification; Type: TABLE DATA; Schema: document; Owner: -
--

COPY document.doc_verification (verification_id, document_id, status, catatan, verified_by, verified_at) FROM stdin;
\.


--
-- Data for Name: document; Type: TABLE DATA; Schema: document; Owner: -
--

COPY document.document (document_id, doc_key, doc_type, title, entity_type, entity_id, file_ref, created_at) FROM stdin;
101	DOC-SV-MUAT-0899	DRAFT_SURVEY	Draft Survey MUAT — TRP-2026-0899	trip	899	/doc/survey/0899-muat.pdf	2026-09-11 04:37:38.232279+00
102	DOC-BAP-0085	BAP	BAP-2026-0085 (signed)	trip	899	/doc/bap/0085.pdf	2026-09-11 04:37:38.232279+00
103	DOC-SV-MUAT-0903	DRAFT_SURVEY	Draft Survey MUAT — TRP-2026-0903	trip	903	/doc/survey/0903-muat.pdf	2026-09-11 04:37:38.232279+00
104	DOC-BAP-0086	BAP	BAP-2026-0086 (signed)	trip	903	/doc/bap/0086.pdf	2026-09-11 04:37:38.232279+00
111	DOC-SV-MUAT-0907	DRAFT_SURVEY	Draft Survey MUAT — TRP-2026-0907	trip	907	/doc/survey/0907-muat.pdf	2026-09-11 04:37:38.232279+00
112	DOC-SV-AWAL-0907	DRAFT_SURVEY	Draft Survey AWAL BONGKAR — TRP-2026-0907	trip	907	/doc/survey/0907-awal.pdf	2026-09-11 04:37:38.232279+00
113	DOC-SV-AKHIR-0907	DRAFT_SURVEY	Draft Survey AKHIR BONGKAR — TRP-2026-0907	trip	907	/doc/survey/0907-akhir.pdf	2026-09-11 04:37:38.232279+00
114	DOC-BAP-0087	BAP	BAP-2026-0087 (signed, TTD 3 pihak)	trip	907	/doc/bap/0087.pdf	2026-09-11 04:37:38.232279+00
115	DOC-SOF-0907	SOF	Statement of Facts — TRP-2026-0907	trip	907	/doc/sof/0907.pdf	2026-09-11 04:37:38.232279+00
116	DOC-QA-0907	QA	QA Report Muat — TRP-2026-0907	trip	907	/doc/qa/0907.pdf	2026-09-11 04:37:38.232279+00
\.


--
-- Data for Name: document_link; Type: TABLE DATA; Schema: document; Owner: -
--

COPY document.document_link (document_id, entity_type, entity_id, is_primary, created_at) FROM stdin;
101	trip	899	f	2026-09-11 04:37:38.33738+00
102	trip	899	f	2026-09-11 04:37:38.33738+00
103	trip	903	f	2026-09-11 04:37:38.33738+00
104	trip	903	f	2026-09-11 04:37:38.33738+00
111	trip	907	f	2026-09-11 04:37:38.33738+00
112	trip	907	f	2026-09-11 04:37:38.33738+00
113	trip	907	f	2026-09-11 04:37:38.33738+00
114	trip	907	f	2026-09-11 04:37:38.33738+00
115	trip	907	f	2026-09-11 04:37:38.33738+00
116	trip	907	f	2026-09-11 04:37:38.33738+00
\.


--
-- Data for Name: form_foto; Type: TABLE DATA; Schema: document; Owner: -
--

COPY document.form_foto (foto_id, form_jenis, record_id, record_label, file_path, storage, ukuran, lebar, tinggi, data, diunggah_oleh, created_at) FROM stdin;
\.


--
-- Data for Name: ews_event; Type: TABLE DATA; Schema: enviro; Owner: -
--

COPY enviro.ews_event (ews_event_id, station_code, parameter_code, level, trigger_rule, value_snapshot, notified, playbook_ref, playbook_executed, outcome, closed_at, tenant_id, created_at, updated_at) FROM stdin;
1	ST-03	TURBIDITY	WARNING	THRESHOLD	{"pct": 93.3, "value": 112, "warning": 108}	{"telegram": ["ops-dispatch"]}	R19	\N	\N	\N	\N	2026-09-05 23:10:00+00	2026-09-11 04:37:38.232279+00
2	ST-03	TURBIDITY	EXCEEDED	THRESHOLD	{"pct": 106.7, "value": 128, "standard": 120}	{"email": ["env@ppteluk.co.id"], "telegram": ["ops-dispatch", "nakhoda:SL02"]}	R19	\N	\N	\N	\N	2026-09-06 23:05:00+00	2026-09-11 04:37:38.232279+00
3	ST-03	IKAL	EXCEEDED	COMPOSITE	{"ikal": 39.37, "param": {"DO": 4.6, "TSS": 85, "ORTOFOSFAT": 0.068, "AMONIA_TOTAL": 0.42, "MINYAK_LEMAK": 3.2}, "periode": "2026-06", "kategori": "KURANG"}	{"email": ["env@ppteluk.co.id"], "telegram": ["ops-dispatch"]}	\N	\N	\N	2026-08-05 01:00:00+00	\N	2026-09-11 04:37:38.801287+00	2026-09-11 04:37:38.801287+00
4	ST-03	IKAL	EXCEEDED	COMPOSITE	{"ikal": 36.16, "param": {"DO": 4.4, "TSS": 92, "ORTOFOSFAT": 0.075, "AMONIA_TOTAL": 0.46, "MINYAK_LEMAK": 3.5}, "periode": "2026-07", "kategori": "KURANG"}	{"email": ["env@ppteluk.co.id"], "telegram": ["ops-dispatch"]}	\N	\N	\N	\N	\N	2026-09-11 04:37:38.802626+00	2026-09-11 04:37:38.802626+00
\.


--
-- Data for Name: mon_parameter; Type: TABLE DATA; Schema: enviro; Owner: -
--

COPY enviro.mon_parameter (parameter_code, name, unit, parameter_group, is_core, standard_value, standard_source, warning_threshold_pct, tenant_id, is_active, created_at, updated_at) FROM stdin;
TURBIDITY	Turbidity	NTU	HIDRO	t	120.000000	ASEAN MWQC [VERIFIKASI]	90.00	\N	t	2026-09-11 04:37:38.083011+00	2026-09-11 04:37:38.083011+00
TSS	Total Suspended Solid	mg/L	HIDRO	t	80.000000	ASEAN MWQC [VERIFIKASI]	90.00	\N	t	2026-09-11 04:37:38.083011+00	2026-09-11 04:37:38.083011+00
DO	Dissolved Oxygen (minimum)	mg/L	HIDRO	t	5.000000	ASEAN MWQC [VERIFIKASI]	90.00	\N	t	2026-09-11 04:37:38.083011+00	2026-09-11 04:37:38.083011+00
SALINITY	Salinitas (maksimum)	permil	HIDRO	t	34.000000	ASEAN MWQC [VERIFIKASI]	90.00	\N	t	2026-09-11 04:37:38.083011+00	2026-09-11 04:37:38.083011+00
PH	pH (rentang 7,0-8,5)	-	HIDRO	t	\N	ASEAN MWQC [VERIFIKASI]	90.00	\N	t	2026-09-11 04:37:38.083011+00	2026-09-11 04:37:38.083011+00
MINYAK_LEMAK	Minyak dan Lemak	mg/L	AIR	t	5.000000	Kepmen LH 51/2004 air laut biota [VERIFIKASI]	90.00	\N	t	2026-09-11 04:37:38.795507+00	2026-09-11 04:37:38.795507+00
AMONIA_TOTAL	Amonia Total (N-NH3)	mg/L	AIR	t	0.300000	Kepmen LH 51/2004 air laut biota [VERIFIKASI]	90.00	\N	t	2026-09-11 04:37:38.795507+00	2026-09-11 04:37:38.795507+00
ORTOFOSFAT	Orto-fosfat (PO4-P)	mg/L	AIR	t	0.015000	Kepmen LH 51/2004 air laut biota [VERIFIKASI]	90.00	\N	t	2026-09-11 04:37:38.795507+00	2026-09-11 04:37:38.795507+00
IKAL	Indeks Kualitas Air Laut — komposit 5 parameter (PermenLHK 27/2021)	indeks	AIR	f	50.000000	PermenLHK 27/2021 Tabel 2.2 · ambang alert internal 50 (KURANG)	90.00	\N	t	2026-09-11 04:37:38.795507+00	2026-09-11 04:37:38.795507+00
\.


--
-- Data for Name: mon_report; Type: TABLE DATA; Schema: enviro; Owner: -
--

COPY enviro.mon_report (mon_report_id, period, report_type, draft_generated_at, reviewed_by, submitted_at, doc_ref, tenant_id, created_at, updated_at) FROM stdin;
1	2026-II	RKL_RPL	2026-09-07 03:00:00+00	\N	\N	\N	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
\.


--
-- Data for Name: mon_schedule; Type: TABLE DATA; Schema: enviro; Owner: -
--

COPY enviro.mon_schedule (schedule_id, parameter_code, station_code, frequency, next_due, auto_wo, tenant_id, created_at, updated_at) FROM stdin;
2	TSS	ST-03	HARIAN	2026-09-08	t	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
5	PH	ST-01	SEMESTERAN	2026-10-01	f	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
4	DO	ST-02	HARIAN	2026-09-08	t	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
1	TURBIDITY	ST-03	HARIAN	2026-09-08	t	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
3	SALINITY	ST-02	HARIAN	2026-09-08	t	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
\.


--
-- Data for Name: mon_work_order; Type: TABLE DATA; Schema: enviro; Owner: -
--

COPY enviro.mon_work_order (wo_id, wo_no, vendor_code, kind, scheduled_date, status, station_codes, parameter_codes, tenant_id, created_at, updated_at) FROM stdin;
121	WO-MON-2026-0121	P-DLM	BUOY_DOWNLOAD	2026-09-07	COMPLETED	{ST-02,ST-03}	{TURBIDITY,TSS,SALINITY,DO}	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
123	WO-MON-2026-0123	P-DLM	SAMPLING	2026-09-10	ISSUED	{ST-01,ST-02,ST-03}	{TURBIDITY,TSS,SALINITY,DO,PH}	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
\.


--
-- Data for Name: reading_daily; Type: TABLE DATA; Schema: enviro; Owner: -
--

COPY enviro.reading_daily (station_code, parameter_code, hari, n, avg, min, max, p95) FROM stdin;
\.


--
-- Data for Name: reading_detail; Type: TABLE DATA; Schema: enviro; Owner: -
--

COPY enviro.reading_detail (reading_detail_id, station_code, parameter_code, record_time, value, unit, source, source_ref, qc_status, tenant_id, created_at, updated_at) FROM stdin;
1	ST-03	TURBIDITY	2026-08-30 23:00:00+00	98.000000	NTU	BUOY	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
2	ST-03	TSS	2026-09-01 23:00:00+00	66.000000	mg/L	BUOY	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
3	ST-03	TURBIDITY	2026-08-31 23:00:00+00	99.000000	NTU	BUOY	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
4	ST-03	TURBIDITY	2026-08-29 23:00:00+00	96.000000	NTU	BUOY	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
5	ST-01	PH	2026-09-06 02:00:00+00	8.000000	-	LAB	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
6	ST-02	DO	2026-08-31 23:00:00+00	5.800000	mg/L	BUOY	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
7	ST-02	SALINITY	2026-08-31 23:00:00+00	28.100000	permil	BUOY	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
8	ST-03	TSS	2026-09-02 23:00:00+00	68.000000	mg/L	BUOY	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
9	ST-03	TSS	2026-09-04 23:00:00+00	71.000000	mg/L	BUOY	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
10	ST-03	TURBIDITY	2026-09-03 23:00:00+00	106.000000	NTU	BUOY	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
11	ST-03	TURBIDITY	2026-09-05 23:00:00+00	118.000000	NTU	BUOY	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
12	ST-03	TURBIDITY	2026-09-06 23:00:00+00	128.000000	NTU	BUOY	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
13	ST-02	DO	2026-09-06 23:00:00+00	5.600000	mg/L	BUOY	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
14	ST-02	SALINITY	2026-09-06 23:00:00+00	28.900000	permil	BUOY	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
15	ST-03	TURBIDITY	2026-09-04 23:00:00+00	112.000000	NTU	BUOY	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
16	ST-03	TSS	2026-09-05 23:00:00+00	73.000000	mg/L	BUOY	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
17	ST-03	TSS	2026-09-03 23:00:00+00	69.000000	mg/L	BUOY	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
18	ST-02	SALINITY	2026-09-04 23:00:00+00	28.600000	permil	BUOY	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
19	ST-02	DO	2026-09-04 23:00:00+00	5.500000	mg/L	BUOY	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
20	ST-03	TSS	2026-09-06 23:00:00+00	76.000000	mg/L	BUOY	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
21	ST-03	TSS	2026-08-31 23:00:00+00	64.000000	mg/L	BUOY	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
22	ST-03	TURBIDITY	2026-09-01 23:00:00+00	101.000000	NTU	BUOY	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
23	ST-01	PH	2026-09-07 02:00:00+00	8.100000	-	LAB	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
24	ST-02	DO	2026-09-02 23:00:00+00	5.600000	mg/L	BUOY	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
25	ST-02	SALINITY	2026-09-02 23:00:00+00	28.400000	permil	BUOY	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
26	ST-03	TURBIDITY	2026-09-02 23:00:00+00	104.000000	NTU	BUOY	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
27	ST-01	PH	2026-09-05 02:00:00+00	8.100000	-	LAB	\N	VALIDATED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
28	ST-01	TSS	2026-04-05 01:00:00+00	12.000000	mg/L	LAB	IKAL-202604	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
29	ST-01	DO	2026-04-05 01:00:00+00	6.800000	mg/L	LAB	IKAL-202604	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
30	ST-01	MINYAK_LEMAK	2026-04-05 01:00:00+00	0.800000	mg/L	LAB	IKAL-202604	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
31	ST-01	AMONIA_TOTAL	2026-04-05 01:00:00+00	0.055000	mg/L	LAB	IKAL-202604	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
32	ST-01	ORTOFOSFAT	2026-04-05 01:00:00+00	0.008000	mg/L	LAB	IKAL-202604	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
33	ST-01	TSS	2026-05-05 01:00:00+00	11.000000	mg/L	LAB	IKAL-202605	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
34	ST-01	DO	2026-05-05 01:00:00+00	6.900000	mg/L	LAB	IKAL-202605	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
35	ST-01	MINYAK_LEMAK	2026-05-05 01:00:00+00	0.700000	mg/L	LAB	IKAL-202605	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
36	ST-01	AMONIA_TOTAL	2026-05-05 01:00:00+00	0.050000	mg/L	LAB	IKAL-202605	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
37	ST-01	ORTOFOSFAT	2026-05-05 01:00:00+00	0.007000	mg/L	LAB	IKAL-202605	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
38	ST-01	TSS	2026-06-05 01:00:00+00	13.000000	mg/L	LAB	IKAL-202606	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
39	ST-01	DO	2026-06-05 01:00:00+00	6.600000	mg/L	LAB	IKAL-202606	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
40	ST-01	MINYAK_LEMAK	2026-06-05 01:00:00+00	0.900000	mg/L	LAB	IKAL-202606	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
41	ST-01	AMONIA_TOTAL	2026-06-05 01:00:00+00	0.060000	mg/L	LAB	IKAL-202606	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
42	ST-01	ORTOFOSFAT	2026-06-05 01:00:00+00	0.009000	mg/L	LAB	IKAL-202606	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
43	ST-01	TSS	2026-07-05 01:00:00+00	12.500000	mg/L	LAB	IKAL-202607	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
44	ST-01	DO	2026-07-05 01:00:00+00	6.700000	mg/L	LAB	IKAL-202607	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
45	ST-01	MINYAK_LEMAK	2026-07-05 01:00:00+00	0.850000	mg/L	LAB	IKAL-202607	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
46	ST-01	AMONIA_TOTAL	2026-07-05 01:00:00+00	0.058000	mg/L	LAB	IKAL-202607	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
47	ST-01	ORTOFOSFAT	2026-07-05 01:00:00+00	0.008500	mg/L	LAB	IKAL-202607	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
48	ST-01	TSS	2026-08-05 01:00:00+00	14.000000	mg/L	LAB	IKAL-202608	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
49	ST-01	DO	2026-08-05 01:00:00+00	6.400000	mg/L	LAB	IKAL-202608	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
50	ST-01	MINYAK_LEMAK	2026-08-05 01:00:00+00	1.000000	mg/L	LAB	IKAL-202608	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
51	ST-01	AMONIA_TOTAL	2026-08-05 01:00:00+00	0.070000	mg/L	LAB	IKAL-202608	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
52	ST-01	ORTOFOSFAT	2026-08-05 01:00:00+00	0.010000	mg/L	LAB	IKAL-202608	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
53	ST-01	TSS	2026-09-05 01:00:00+00	15.000000	mg/L	LAB	IKAL-202609	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
54	ST-01	DO	2026-09-05 01:00:00+00	6.000000	mg/L	LAB	IKAL-202609	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
55	ST-01	MINYAK_LEMAK	2026-09-05 01:00:00+00	2.000000	mg/L	LAB	IKAL-202609	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
56	ST-01	AMONIA_TOTAL	2026-09-05 01:00:00+00	0.100000	mg/L	LAB	IKAL-202609	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
57	ST-01	ORTOFOSFAT	2026-09-05 01:00:00+00	0.020000	mg/L	LAB	IKAL-202609	VALIDATED	\N	2026-09-11 04:37:38.796158+00	2026-09-11 04:37:38.796158+00
58	ST-02	TSS	2026-04-05 01:00:00+00	38.000000	mg/L	LAB	IKAL-202604	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
59	ST-02	DO	2026-04-05 01:00:00+00	5.600000	mg/L	LAB	IKAL-202604	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
60	ST-02	MINYAK_LEMAK	2026-04-05 01:00:00+00	1.600000	mg/L	LAB	IKAL-202604	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
61	ST-02	AMONIA_TOTAL	2026-04-05 01:00:00+00	0.180000	mg/L	LAB	IKAL-202604	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
62	ST-02	ORTOFOSFAT	2026-04-05 01:00:00+00	0.030000	mg/L	LAB	IKAL-202604	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
63	ST-02	TSS	2026-05-05 01:00:00+00	42.000000	mg/L	LAB	IKAL-202605	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
64	ST-02	DO	2026-05-05 01:00:00+00	5.500000	mg/L	LAB	IKAL-202605	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
65	ST-02	MINYAK_LEMAK	2026-05-05 01:00:00+00	1.800000	mg/L	LAB	IKAL-202605	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
66	ST-02	AMONIA_TOTAL	2026-05-05 01:00:00+00	0.200000	mg/L	LAB	IKAL-202605	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
67	ST-02	ORTOFOSFAT	2026-05-05 01:00:00+00	0.033000	mg/L	LAB	IKAL-202605	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
68	ST-02	TSS	2026-06-05 01:00:00+00	50.000000	mg/L	LAB	IKAL-202606	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
69	ST-02	DO	2026-06-05 01:00:00+00	5.300000	mg/L	LAB	IKAL-202606	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
70	ST-02	MINYAK_LEMAK	2026-06-05 01:00:00+00	2.100000	mg/L	LAB	IKAL-202606	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
71	ST-02	AMONIA_TOTAL	2026-06-05 01:00:00+00	0.240000	mg/L	LAB	IKAL-202606	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
72	ST-02	ORTOFOSFAT	2026-06-05 01:00:00+00	0.038000	mg/L	LAB	IKAL-202606	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
73	ST-02	TSS	2026-07-05 01:00:00+00	47.000000	mg/L	LAB	IKAL-202607	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
74	ST-02	DO	2026-07-05 01:00:00+00	5.400000	mg/L	LAB	IKAL-202607	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
75	ST-02	MINYAK_LEMAK	2026-07-05 01:00:00+00	2.000000	mg/L	LAB	IKAL-202607	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
76	ST-02	AMONIA_TOTAL	2026-07-05 01:00:00+00	0.220000	mg/L	LAB	IKAL-202607	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
77	ST-02	ORTOFOSFAT	2026-07-05 01:00:00+00	0.036000	mg/L	LAB	IKAL-202607	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
78	ST-02	TSS	2026-08-05 01:00:00+00	44.000000	mg/L	LAB	IKAL-202608	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
79	ST-02	DO	2026-08-05 01:00:00+00	5.500000	mg/L	LAB	IKAL-202608	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
80	ST-02	MINYAK_LEMAK	2026-08-05 01:00:00+00	1.900000	mg/L	LAB	IKAL-202608	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
81	ST-02	AMONIA_TOTAL	2026-08-05 01:00:00+00	0.210000	mg/L	LAB	IKAL-202608	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
82	ST-02	ORTOFOSFAT	2026-08-05 01:00:00+00	0.034000	mg/L	LAB	IKAL-202608	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
83	ST-02	TSS	2026-09-05 01:00:00+00	40.000000	mg/L	LAB	IKAL-202609	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
84	ST-02	DO	2026-09-05 01:00:00+00	5.600000	mg/L	LAB	IKAL-202609	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
85	ST-02	MINYAK_LEMAK	2026-09-05 01:00:00+00	1.700000	mg/L	LAB	IKAL-202609	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
86	ST-02	AMONIA_TOTAL	2026-09-05 01:00:00+00	0.190000	mg/L	LAB	IKAL-202609	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
87	ST-02	ORTOFOSFAT	2026-09-05 01:00:00+00	0.031000	mg/L	LAB	IKAL-202609	VALIDATED	\N	2026-09-11 04:37:38.797686+00	2026-09-11 04:37:38.797686+00
88	ST-03	TSS	2026-04-05 01:00:00+00	55.000000	mg/L	LAB	IKAL-202604	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
89	ST-03	DO	2026-04-05 01:00:00+00	5.200000	mg/L	LAB	IKAL-202604	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
90	ST-03	MINYAK_LEMAK	2026-04-05 01:00:00+00	2.400000	mg/L	LAB	IKAL-202604	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
91	ST-03	AMONIA_TOTAL	2026-04-05 01:00:00+00	0.280000	mg/L	LAB	IKAL-202604	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
92	ST-03	ORTOFOSFAT	2026-04-05 01:00:00+00	0.045000	mg/L	LAB	IKAL-202604	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
93	ST-03	TSS	2026-05-05 01:00:00+00	62.000000	mg/L	LAB	IKAL-202605	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
94	ST-03	DO	2026-05-05 01:00:00+00	5.000000	mg/L	LAB	IKAL-202605	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
95	ST-03	MINYAK_LEMAK	2026-05-05 01:00:00+00	2.700000	mg/L	LAB	IKAL-202605	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
96	ST-03	AMONIA_TOTAL	2026-05-05 01:00:00+00	0.320000	mg/L	LAB	IKAL-202605	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
97	ST-03	ORTOFOSFAT	2026-05-05 01:00:00+00	0.052000	mg/L	LAB	IKAL-202605	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
98	ST-03	TSS	2026-06-05 01:00:00+00	85.000000	mg/L	LAB	IKAL-202606	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
99	ST-03	DO	2026-06-05 01:00:00+00	4.600000	mg/L	LAB	IKAL-202606	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
100	ST-03	MINYAK_LEMAK	2026-06-05 01:00:00+00	3.200000	mg/L	LAB	IKAL-202606	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
101	ST-03	AMONIA_TOTAL	2026-06-05 01:00:00+00	0.420000	mg/L	LAB	IKAL-202606	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
102	ST-03	ORTOFOSFAT	2026-06-05 01:00:00+00	0.068000	mg/L	LAB	IKAL-202606	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
103	ST-03	TSS	2026-07-05 01:00:00+00	92.000000	mg/L	LAB	IKAL-202607	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
104	ST-03	DO	2026-07-05 01:00:00+00	4.400000	mg/L	LAB	IKAL-202607	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
105	ST-03	MINYAK_LEMAK	2026-07-05 01:00:00+00	3.500000	mg/L	LAB	IKAL-202607	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
106	ST-03	AMONIA_TOTAL	2026-07-05 01:00:00+00	0.460000	mg/L	LAB	IKAL-202607	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
107	ST-03	ORTOFOSFAT	2026-07-05 01:00:00+00	0.075000	mg/L	LAB	IKAL-202607	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
108	ST-03	TSS	2026-08-05 01:00:00+00	68.000000	mg/L	LAB	IKAL-202608	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
109	ST-03	DO	2026-08-05 01:00:00+00	4.900000	mg/L	LAB	IKAL-202608	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
110	ST-03	MINYAK_LEMAK	2026-08-05 01:00:00+00	2.900000	mg/L	LAB	IKAL-202608	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
111	ST-03	AMONIA_TOTAL	2026-08-05 01:00:00+00	0.350000	mg/L	LAB	IKAL-202608	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
112	ST-03	ORTOFOSFAT	2026-08-05 01:00:00+00	0.058000	mg/L	LAB	IKAL-202608	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
113	ST-03	TSS	2026-09-05 01:00:00+00	58.000000	mg/L	LAB	IKAL-202609	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
114	ST-03	DO	2026-09-05 01:00:00+00	5.100000	mg/L	LAB	IKAL-202609	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
115	ST-03	MINYAK_LEMAK	2026-09-05 01:00:00+00	2.500000	mg/L	LAB	IKAL-202609	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
116	ST-03	AMONIA_TOTAL	2026-09-05 01:00:00+00	0.300000	mg/L	LAB	IKAL-202609	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
117	ST-03	ORTOFOSFAT	2026-09-05 01:00:00+00	0.048000	mg/L	LAB	IKAL-202609	VALIDATED	\N	2026-09-11 04:37:38.798632+00	2026-09-11 04:37:38.798632+00
\.


--
-- Data for Name: remediation; Type: TABLE DATA; Schema: enviro; Owner: -
--

COPY enviro.remediation (remediation_id, cause_type, cause_id, plan, started_at, status, verification_refs, closed_at, tenant_id, created_at, updated_at) FROM stdin;
1	EWS	2	R19 — kurangi intensitas pengerukan B-04 50% · pasang silt curtain · sampling verifikasi H+3 (10 Sep)	2026-09-07 00:00:00+00	IN_PROGRESS	\N	\N	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
\.


--
-- Data for Name: station; Type: TABLE DATA; Schema: enviro; Owner: -
--

COPY enviro.station (station_code, station_name, station_type, location) FROM stdin;
ST-01	Teluk Utara (Referensi)	REFERENSI	0101000020E61000006666666666865A4000000000000017C0
ST-02	Perairan Site G	DUMPING	0101000020E6100000F6285C8FC2955A40D7A3703D0AD717C0
ST-03	Muara Blok B-04	MUARA	0101000020E6100000EC51B81E857B5A403D0AD7A3703D17C0
ST-04	Zona Pengerukan Blok B-07	SENSOR	0101000020E61000008FC2F5285C8F5A409A999999999917C0
ST-05	Perairan Site H (cadangan)	SENSOR	0101000020E61000007B14AE47E19A5A4033333333333318C0
\.


--
-- Data for Name: reading_default; Type: TABLE DATA; Schema: enviro_raw; Owner: -
--

COPY enviro_raw.reading_default (station_code, parameter_code, ts, value) FROM stdin;
\.


--
-- Data for Name: reading_p2026_09; Type: TABLE DATA; Schema: enviro_raw; Owner: -
--

COPY enviro_raw.reading_p2026_09 (station_code, parameter_code, ts, value) FROM stdin;
\.


--
-- Data for Name: reading_p2026_10; Type: TABLE DATA; Schema: enviro_raw; Owner: -
--

COPY enviro_raw.reading_p2026_10 (station_code, parameter_code, ts, value) FROM stdin;
\.


--
-- Data for Name: reading_p2026_11; Type: TABLE DATA; Schema: enviro_raw; Owner: -
--

COPY enviro_raw.reading_p2026_11 (station_code, parameter_code, ts, value) FROM stdin;
\.


--
-- Data for Name: sensor_threshold; Type: TABLE DATA; Schema: enviro_raw; Owner: -
--

COPY enviro_raw.sensor_threshold (parameter_code, ambang_min, ambang_max, satuan, referensi, updated_by, updated_at) FROM stdin;
TSS	\N	80.0000	mg/L	ASEAN MWQC — maksimum 80 mg/L	seed	2026-09-21 07:18:37.165279+00
DO	5.0000	\N	mg/L	ASEAN MWQC — DO minimum 5 mg/L (di bawah ambang = pelanggaran)	seed	2026-09-21 07:18:37.165279+00
TURBIDITY	\N	120.0000	NTU	ASEAN MWQC — maksimum 120 NTU	seed	2026-09-21 07:18:37.165279+00
ORTOFOSFAT	\N	0.0150	mg/L	Kepmen LH 51/2004 — maksimum 0,015 mg/L	seed	2026-09-21 07:18:37.165279+00
MINYAK_LEMAK	\N	5.0000	mg/L	Kepmen LH 51/2004 — maksimum 5 mg/L	seed	2026-09-21 07:18:37.165279+00
PH	7.0000	8.5000	-	ASEAN MWQC — rentang pH 7,0-8,5	seed	2026-09-21 07:18:37.165279+00
AMONIA_TOTAL	\N	0.3000	mg/L	Kepmen LH 51/2004 — maksimum 0,3 mg/L	seed	2026-09-21 07:18:37.165279+00
SALINITY	\N	34.0000	permil	ASEAN MWQC — maksimum 34 permil	seed	2026-09-21 07:18:37.165279+00
\.


--
-- Data for Name: station_token; Type: TABLE DATA; Schema: enviro_raw; Owner: -
--

COPY enviro_raw.station_token (station_code, token, aktif, updated_at) FROM stdin;
ST-01	tok-st-01-pasirlaut	t	2026-09-21 07:18:37.163166+00
ST-02	tok-st-02-pasirlaut	t	2026-09-21 07:18:37.163166+00
ST-03	tok-st-03-pasirlaut	t	2026-09-21 07:18:37.163166+00
ST-04	tok-st-04-pasirlaut	t	2026-09-21 07:18:37.163166+00
ST-05	tok-st-05-pasirlaut	t	2026-09-21 07:18:37.163166+00
\.


--
-- Data for Name: cost_entry; Type: TABLE DATA; Schema: financial; Owner: -
--

COPY financial.cost_entry (cost_entry_id, trip_id, category, charter_contract_id, amount, source, description, journal_id, tenant_id, created_at, updated_at) FROM stdin;
2	903	CHARTER	5	38000000.00	AUTO	Hak partner PER_TRIP (FR-06-03)	104	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
4	907	STANDBY	\N	13500000.00	AUTO	Standby 3 jam × Rp 4,5 jt (R11)	116	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
1	899	CHARTER	4	63000000.00	AUTO	Hak partner basis BAP (FR-06-03)	98	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
3	907	CHARTER	3	64461600.00	AUTO	Hak partner basis BAP (FR-06-03)	114	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
5	910	CHARTER	4	47400000.00	AUTO	Hak partner basis BAP — deposit buyer kurang, hak TETAP penuh (FR-06-03)	120	\N	2026-09-11 04:37:38.491768+00	2026-09-11 04:37:38.491768+00
\.


--
-- Data for Name: invoice; Type: TABLE DATA; Schema: financial; Owner: -
--

COPY financial.invoice (invoice_id, invoice_no, invoice_type, partner_code, amount, currency_code, status, issued_at, due_date, buyer_code) FROM stdin;
231	INV-AR-2026-0231	SALES	\N	115493700.00	IDR	PAID	2026-09-07	2026-10-07	B-PRN
232	INV-AR-2026-0232	SALES	\N	13500000.00	IDR	ISSUED	2026-09-07	2026-10-07	B-PRN
233	INV-AR-2026-0233	SALES	\N	32950000.00	IDR	ISSUED	2026-09-10	2026-10-10	B-PSR
\.


--
-- Data for Name: journal; Type: TABLE DATA; Schema: financial; Owner: -
--

COPY financial.journal (journal_id, journal_no, je_date, ref_type, ref_doc, description, total_amount) FROM stdin;
98	J-2026-09-0098	2026-09-02	partner.statement_line	259	Hak partner TRP-2026-0899 (basis BAP-2026-0085)	63000000.00
104	J-2026-09-0104	2026-09-04	partner.statement_line	260	Hak partner TRP-2026-0903 (basis BAP-2026-0086)	38000000.00
112	J-2026-09-0112	2026-09-07	commercial.bap	BAP-2026-0087	Pengakuan pendapatan pasir TRP-2026-0907	115493700.00
113	J-2026-09-0113	2026-09-07	commercial.bap	BAP-2026-0087	Pemotongan deposit SC-2026-014	115493700.00
114	J-2026-09-0114	2026-09-07	partner.statement_line	261	Hak partner TRP-2026-0907 (basis BAP-2026-0087)	64461600.00
115	J-2026-09-0115	2026-09-07	financial.pnbp_charge	79	PNBP per trip TRP-2026-0907 (basis BAP)	80577000.00
116	J-2026-09-0116	2026-09-07	commercial.standby_claim	1	Pendapatan standby TRP-2026-0907 (3 jam)	13500000.00
117	J-2026-09-0117	2026-09-10	commercial.bap	BAP-2026-0088	Pengakuan pendapatan pasir TRP-2026-0910	82950000.00
118	J-2026-09-0118	2026-09-10	buyer.deposit_transaction	7	Pemotongan deposit SC-2026-015 (sebagian — deposit kurang)	50000000.00
119	J-2026-09-0119	2026-09-10	financial.pnbp_charge	80	PNBP per trip TRP-2026-0910 (basis BAP)	59250000.00
120	J-2026-09-0120	2026-09-10	partner.statement_line	262	Hak partner TRP-2026-0910 (basis BAP)	47400000.00
\.


--
-- Data for Name: journal_line; Type: TABLE DATA; Schema: financial; Owner: -
--

COPY financial.journal_line (journal_line_id, journal_id, line_no, account_code, account_name, debit, credit) FROM stdin;
1	98	1	5-5100	Beban Charter Kapal	63000000.00	0.00
2	98	2	2-2200	Utang Partner — PT Samudra Mitra	0.00	63000000.00
3	104	1	5-5100	Beban Charter Kapal	38000000.00	0.00
4	104	2	2-2200	Utang Partner — PT Bahari Lines	0.00	38000000.00
5	112	1	1-1200	Piutang Usaha — PT PRN	115493700.00	0.00
6	112	2	4-4000	Pendapatan Penjualan Pasir	0.00	115493700.00
7	113	1	2-2100	Deposit Customer — SC-2026-014	115493700.00	0.00
8	113	2	1-1200	Piutang Usaha — PT PRN	0.00	115493700.00
9	114	1	5-5100	Beban Charter Kapal	64461600.00	0.00
10	114	2	2-2200	Utang Partner — PT Samudra Mitra	0.00	64461600.00
11	115	1	5-5200	Beban PNBP	80577000.00	0.00
12	115	2	2-2300	Utang PNBP	0.00	80577000.00
13	116	1	1-1200	Piutang Usaha (standby) — PT PRN	13500000.00	0.00
14	116	2	4-4100	Pendapatan Standby	0.00	13500000.00
15	117	1	1-1200	Piutang Usaha — PT PSR	82950000.00	0.00
16	117	2	4-4000	Pendapatan Penjualan Pasir	0.00	82950000.00
17	118	1	2-2100	Utang Bongkar & Deposit Diterima Dimuka — PT PSR	50000000.00	0.00
18	118	2	1-1200	Piutang Usaha — PT PSR	0.00	50000000.00
19	119	1	5-5200	Beban PNBP	59250000.00	0.00
20	119	2	2-2300	Utang PNBP	0.00	59250000.00
21	120	1	5-5100	Beban Charter Kapal	47400000.00	0.00
22	120	2	2-2200	Utang Partner — PT Samudra Mitra	0.00	47400000.00
\.


--
-- Data for Name: pnbp_charge; Type: TABLE DATA; Schema: financial; Owner: -
--

COPY financial.pnbp_charge (pnbp_charge_id, trip_id, bap_id, volume_basis_m3, rate, amount, period, status, tenant_id, created_at, updated_at) FROM stdin;
77	899	85	5250.000	15000.0000	78750000.00	2026-09	PAID	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
78	903	86	4982.558	15000.0000	74738370.00	2026-09	REPORTED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
79	907	87	5371.800	15000.0000	80577000.00	2026-09	ACCRUED	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
80	910	88	3950.000	15000.0000	59250000.00	2026-09	REPORTED	\N	2026-09-11 04:37:38.488597+00	2026-09-11 04:37:38.488597+00
\.


--
-- Data for Name: pnbp_kode_map; Type: TABLE DATA; Schema: financial; Owner: -
--

COPY financial.pnbp_kode_map (map_id, jenis, label, kode, dasar_hukum, keterangan, is_placeholder, updated_at, updated_by) FROM stdin;
1	TAHAP_AWAL	PNBP tahap awal 5% (setoran awal pemanfaatan)	PNBP-PLH-000-001	Permen KP 41/2023	CONTOH — ganti dengan kode KMA resmi saat terbit	t	2026-09-21 07:18:37.256698+00	seed
2	REALISASI_BAP	PNBP realisasi pemanfaatan (per BAP)	PNBP-PLH-000-002	PP 85/2021 jo. PP 26/2023	CONTOH — ganti dengan kode KMA resmi saat terbit	t	2026-09-21 07:18:37.256698+00	seed
3	PROYEKSI	PNBP proyeksi volume kontrak (informasi)	PNBP-PLH-000-003	PP 26/2023	CONTOH — ganti dengan kode KMA resmi saat terbit	t	2026-09-21 07:18:37.256698+00	seed
\.


--
-- Data for Name: pnbp_tahap_awal; Type: TABLE DATA; Schema: financial; Owner: -
--

COPY financial.pnbp_tahap_awal (tahap_id, sales_contract_id, proyeksi_m3, tarif, proyeksi_total, amount_5pct, due_date, status, paid_at, created_at) FROM stdin;
1	1	300000	27900	8370000000	418500000	2026-08-12	PAID	2026-08-11 09:00:00+00	2026-09-11 04:37:38.922491+00
2	90	400000	65100	26040000000	1302000000	2026-09-22	DUE	\N	2026-09-11 04:37:38.923068+00
\.


--
-- Data for Name: pnbp_tarif; Type: TABLE DATA; Schema: financial; Owner: -
--

COPY financial.pnbp_tarif (tarif_id, kategori, harga_patokan, tarif_pct, dasar_hukum, berlaku_mulai, is_aktif, created_at) FROM stdin;
1	DOMESTIK	93000	30	PP 85/2021 · HPP Kepmen KP 6/2024 · pemanfaatan dalam negeri (PP 26/2023)	2024-02-28	t	2026-09-11 04:37:38.906467+00
2	EKSPOR	186000	35	PP 85/2021 · HPP Kepmen KP 6/2024 · pemanfaatan luar negeri (PP 26/2023)	2024-02-28	t	2026-09-11 04:37:38.906467+00
3	LEGACY	50000	30	tarif simulasi awal v0.12 — sudah digantikan PP 26/2023	2026-01-01	f	2026-09-11 04:37:38.906467+00
\.


--
-- Data for Name: info; Type: TABLE DATA; Schema: fleet; Owner: -
--

COPY fleet.info (fleet_code, fleet_name, vessel_type, status, latest_lat, latest_lng, latest_seen_at, hopper_capacity_m3) FROM stdin;
SL07	MV Sinar Laut 07	TSHD	AKTIF	\N	\N	\N	5400.000
SL09	MV Sinar Laut 09	TSHD	AKTIF	\N	\N	\N	5400.000
LI02	TB Laut Indah 02	TB	AKTIF	\N	\N	\N	2800.000
M03	TB Mulya 03	TB	AKTIF	\N	\N	\N	5400.000
B07	TB Bahari 07	TB	AKTIF	\N	\N	\N	4900.000
SL02	MV Sinar Laut 02	TSHD	AKTIF	-5.97	106.36	2026-09-07 07:30:00+00	5400.000
SL05	MV Sinar Laut 05	TSHD	AKTIF	-5.73	106.16	2026-09-07 07:30:00+00	5400.000
B12	TB Bahari 12	TB	AKTIF	-5.925	106.2	2026-09-07 07:30:00+00	4900.000
SV01	Catamaran Survei 01	SURVEY	AKTIF	\N	\N	\N	\N
\.


--
-- Data for Name: vessel_maintenance; Type: TABLE DATA; Schema: fleet; Owner: -
--

COPY fleet.vessel_maintenance (maintenance_id, fleet_code, jenis, window_start, window_end, catatan, dibuat_oleh, created_at) FROM stdin;
2	SL07	DOCKING	2026-09-21 01:18:37.712888+00	2026-09-26 07:18:37.712888+00	Docking berkala 2 tahun — kapal TIDAK DITUGASKAN selama jendela ini.	system	2026-09-21 07:18:37.712888+00
3	LI02	PERBAIKAN_RUTIN	2026-09-21 05:18:37.712888+00	2026-09-23 07:18:37.712888+00	Perbaikan pompa hopper di darat — belum siap berlayar.	system	2026-09-21 07:18:37.712888+00
\.


--
-- Data for Name: capa; Type: TABLE DATA; Schema: hse; Owner: -
--

COPY hse.capa (capa_id, capa_no, source_type, source_ref, description, severity, due_date, status, closed_at, tenant_id, created_at, updated_at) FROM stdin;
1	CAPA-2026-009	INCIDENT	INS-2026-001	Ganti seal hidrolik + sediakan drip tray cadangan di M03	3	2026-06-20	CLOSED	2026-06-18	\N	2026-09-11 04:37:38.683341+00	2026-09-11 04:37:38.683341+00
2	CAPA-2026-011	INSPECTION	INSP-2609-007	APD bertingkat di TB Bahari 07 — ganti harness & sepatu safety	4	2026-09-15	OPEN	\N	\N	2026-09-11 04:37:38.683341+00	2026-09-11 04:37:38.683341+00
3	CAPA-2026-012	INSPECTION	INSP-2609-009	Guardrail deck LI02 berkarat — ganti 2 segmen	3	2026-09-30	OPEN	\N	\N	2026-09-11 04:37:38.683341+00	2026-09-11 04:37:38.683341+00
\.


--
-- Data for Name: certificate; Type: TABLE DATA; Schema: hse; Owner: -
--

COPY hse.certificate (certificate_id, fleet_code, cert_type, issued_at, expires_at, tenant_id, created_at, updated_at) FROM stdin;
1	SL07	Sertifikat Keselamatan (SLC)	2024-01-15	2026-11-05	\N	2026-09-11 04:37:38.680345+00	2026-09-11 04:37:38.680345+00
2	SL05	Sertifikat Keselamatan (SLC)	2024-01-15	2027-01-14	\N	2026-09-11 04:37:38.680345+00	2026-09-11 04:37:38.680345+00
3	SL09	Sertifikat Keselamatan (SLC)	2024-01-15	2027-01-14	\N	2026-09-11 04:37:38.680345+00	2026-09-11 04:37:38.680345+00
4	SL02	Sertifikat Keselamatan (SLC)	2024-01-15	2027-01-14	\N	2026-09-11 04:37:38.680345+00	2026-09-11 04:37:38.680345+00
5	B07	Sertifikat Keselamatan (SLC)	2024-01-15	2027-01-14	\N	2026-09-11 04:37:38.680345+00	2026-09-11 04:37:38.680345+00
6	M03	Sertifikat Keselamatan (SLC)	2024-01-15	2027-01-14	\N	2026-09-11 04:37:38.680345+00	2026-09-11 04:37:38.680345+00
7	LI02	Sertifikat Keselamatan (SLC)	2024-01-15	2027-01-14	\N	2026-09-11 04:37:38.680345+00	2026-09-11 04:37:38.680345+00
8	B12	Sertifikat Keselamatan (SLC)	2024-01-15	2027-01-14	\N	2026-09-11 04:37:38.680345+00	2026-09-11 04:37:38.680345+00
9	SL07	Sertifikat Alat Apung (Liferaft)	2024-02-20	2027-02-19	\N	2026-09-11 04:37:38.681386+00	2026-09-11 04:37:38.681386+00
10	SL09	Sertifikat Alat Apung (Liferaft)	2024-02-20	2027-02-19	\N	2026-09-11 04:37:38.681386+00	2026-09-11 04:37:38.681386+00
11	LI02	Sertifikat Alat Apung (Liferaft)	2024-02-20	2026-10-28	\N	2026-09-11 04:37:38.681386+00	2026-09-11 04:37:38.681386+00
12	M03	Sertifikat Alat Apung (Liferaft)	2024-02-20	2027-02-19	\N	2026-09-11 04:37:38.681386+00	2026-09-11 04:37:38.681386+00
13	B07	Sertifikat Alat Apung (Liferaft)	2024-02-20	2027-02-19	\N	2026-09-11 04:37:38.681386+00	2026-09-11 04:37:38.681386+00
14	SL02	Sertifikat Alat Apung (Liferaft)	2024-02-20	2027-02-19	\N	2026-09-11 04:37:38.681386+00	2026-09-11 04:37:38.681386+00
15	SL05	Sertifikat Alat Apung (Liferaft)	2024-02-20	2027-02-19	\N	2026-09-11 04:37:38.681386+00	2026-09-11 04:37:38.681386+00
16	B12	Sertifikat Alat Apung (Liferaft)	2024-02-20	2027-02-19	\N	2026-09-11 04:37:38.681386+00	2026-09-11 04:37:38.681386+00
\.


--
-- Data for Name: incident; Type: TABLE DATA; Schema: hse; Owner: -
--

COPY hse.incident (incident_id, incident_no, occurred_at, fleet_code, category, description, reported_via, status, closed_at, tenant_id, created_at, updated_at, deleted_at, deleted_by) FROM stdin;
2	INS-2026-001	2026-06-03 01:15:00+00	M03	NEAR_MISS	Spill hidrolik kecil di ruang mesin — tertahan drip tray, laporan lengkap dibuat	PWA	CLOSED	2026-06-10 03:00:00+00	\N	2026-09-11 04:37:38.678545+00	2026-09-11 04:37:38.678545+00	\N	\N
3	INS-2026-002	2026-07-12 07:05:00+00	B07	FIRST_AID	Kru tersandung rak di deck saat bongkar — istirahat 1 hari	PWA	CLOSED	2026-07-15 02:00:00+00	\N	2026-09-11 04:37:38.678545+00	2026-09-11 04:37:38.678545+00	\N	\N
4	INS-2026-003	2026-08-02 23:40:00+00	SL05	NEAR_MISS	Tali tambat kendor saat sandar — ditangani awak, tanpa kerusakan	PWA	CLOSED	2026-08-05 01:30:00+00	\N	2026-09-11 04:37:38.678545+00	2026-09-11 04:37:38.678545+00	\N	\N
1	INS-2024-001	2024-05-17 02:30:00+00	LI02	LTI	Jari kru terjepit konveyor saat bongkar — cuti kerja 12 hari	PWA	CLOSED	2024-06-15 09:00:00+00	\N	2026-09-11 04:37:38.678545+00	2026-09-11 04:37:38.678545+00	\N	\N
\.


--
-- Data for Name: induction; Type: TABLE DATA; Schema: hse; Owner: -
--

COPY hse.induction (induction_id, crew_name, crew_role, fleet_code, done_at, tenant_id, created_at, updated_at) FROM stdin;
1	Dedi Kurniawan	Able Seaman	LI02	2026-09-01	\N	2026-09-11 04:37:38.682626+00	2026-09-11 04:37:38.682626+00
2	Andi Saputra	Deck Rating	SL09	2026-08-20	\N	2026-09-11 04:37:38.682626+00	2026-09-11 04:37:38.682626+00
3	Fajar Ramadhan	Oiler	SL07	2026-09-04	\N	2026-09-11 04:37:38.682626+00	2026-09-11 04:37:38.682626+00
4	Budi Hartono	Oiler	B12	2026-08-22	\N	2026-09-11 04:37:38.682626+00	2026-09-11 04:37:38.682626+00
5	Eko Prasetyo	Deck Rating	SL02	2026-09-02	\N	2026-09-11 04:37:38.682626+00	2026-09-11 04:37:38.682626+00
6	Citra Lestari	Cook	M03	2026-08-25	\N	2026-09-11 04:37:38.682626+00	2026-09-11 04:37:38.682626+00
\.


--
-- Data for Name: inspection; Type: TABLE DATA; Schema: hse; Owner: -
--

COPY hse.inspection (inspection_id, inspection_no, scheduled_date, unit_kode, checklist, status, result, findings, inspector, tenant_id, created_at, updated_at) FROM stdin;
1	INSP-2609-001	2026-09-01	SL02	APD	DONE	COMPLIANT	0	H. Rudi	\N	2026-09-11 04:37:38.679554+00	2026-09-11 04:37:38.679554+00
2	INSP-2609-002	2026-09-01	SL05	APD	DONE	COMPLIANT	0	H. Rudi	\N	2026-09-11 04:37:38.679554+00	2026-09-11 04:37:38.679554+00
3	INSP-2609-003	2026-09-02	SL07	ALAT_APUNG	DONE	COMPLIANT	0	Timo	\N	2026-09-11 04:37:38.679554+00	2026-09-11 04:37:38.679554+00
4	INSP-2609-004	2026-09-02	SL09	ALAT_APUNG	DONE	COMPLIANT	0	Timo	\N	2026-09-11 04:37:38.679554+00	2026-09-11 04:37:38.679554+00
5	INSP-2609-005	2026-09-03	B07	DECK	DONE	FINDING	1	H. Rudi	\N	2026-09-11 04:37:38.679554+00	2026-09-11 04:37:38.679554+00
6	INSP-2609-006	2026-09-03	B12	DECK	DONE	COMPLIANT	0	H. Rudi	\N	2026-09-11 04:37:38.679554+00	2026-09-11 04:37:38.679554+00
7	INSP-2609-007	2026-09-04	B07	APD	DONE	FINDING	1	Sari	\N	2026-09-11 04:37:38.679554+00	2026-09-11 04:37:38.679554+00
8	INSP-2609-008	2026-09-04	SITE-G	HOUSEKEEPING	DONE	COMPLIANT	0	Sari	\N	2026-09-11 04:37:38.679554+00	2026-09-11 04:37:38.679554+00
9	INSP-2609-009	2026-09-05	LI02	DECK	DONE	FINDING	1	Timo	\N	2026-09-11 04:37:38.679554+00	2026-09-11 04:37:38.679554+00
10	INSP-2609-010	2026-09-05	M03	RUMAH_MESIN	DONE	COMPLIANT	0	Timo	\N	2026-09-11 04:37:38.679554+00	2026-09-11 04:37:38.679554+00
11	INSP-2609-011	2026-09-06	B07	ALAT_APUNG	DONE	COMPLIANT	0	Sari	\N	2026-09-11 04:37:38.679554+00	2026-09-11 04:37:38.679554+00
12	INSP-2609-012	2026-09-06	SL05	DECK	DONE	COMPLIANT	0	Sari	\N	2026-09-11 04:37:38.679554+00	2026-09-11 04:37:38.679554+00
13	INSP-2609-013	2026-09-07	SL02	RUMAH_MESIN	DONE	COMPLIANT	0	H. Rudi	\N	2026-09-11 04:37:38.679554+00	2026-09-11 04:37:38.679554+00
14	INSP-2609-014	2026-09-07	LI02	APD	DONE	COMPLIANT	0	H. Rudi	\N	2026-09-11 04:37:38.679554+00	2026-09-11 04:37:38.679554+00
15	INSP-2609-015	2026-09-09	SL07	APD	SCHEDULED	\N	0	\N	\N	2026-09-11 04:37:38.679554+00	2026-09-11 04:37:38.679554+00
16	INSP-2609-016	2026-09-10	B12	ALAT_APUNG	SCHEDULED	\N	0	\N	\N	2026-09-11 04:37:38.679554+00	2026-09-11 04:37:38.679554+00
17	INSP-2609-017	2026-09-11	SL09	DECK	SCHEDULED	\N	0	\N	\N	2026-09-11 04:37:38.679554+00	2026-09-11 04:37:38.679554+00
18	INSP-2609-018	2026-09-15	B07	RUMAH_MESIN	SCHEDULED	\N	0	\N	\N	2026-09-11 04:37:38.679554+00	2026-09-11 04:37:38.679554+00
19	INSP-2609-019	2026-09-17	M03	APD	SCHEDULED	\N	0	\N	\N	2026-09-11 04:37:38.679554+00	2026-09-11 04:37:38.679554+00
20	INSP-2609-020	2026-09-19	SL02	ALAT_APUNG	SCHEDULED	\N	0	\N	\N	2026-09-11 04:37:38.679554+00	2026-09-11 04:37:38.679554+00
\.


--
-- Data for Name: toolbox_meeting; Type: TABLE DATA; Schema: hse; Owner: -
--

COPY hse.toolbox_meeting (ttm_id, unit_kode, period_week, held, attendees, tenant_id, created_at, updated_at) FROM stdin;
1	SL07	2026-08-24	t	9	\N	2026-09-11 04:37:38.681888+00	2026-09-11 04:37:38.681888+00
2	SL07	2026-08-31	t	9	\N	2026-09-11 04:37:38.681888+00	2026-09-11 04:37:38.681888+00
3	SL07	2026-09-07	t	9	\N	2026-09-11 04:37:38.681888+00	2026-09-11 04:37:38.681888+00
4	SL09	2026-08-24	t	9	\N	2026-09-11 04:37:38.681888+00	2026-09-11 04:37:38.681888+00
5	SL09	2026-08-31	t	9	\N	2026-09-11 04:37:38.681888+00	2026-09-11 04:37:38.681888+00
6	SL09	2026-09-07	t	9	\N	2026-09-11 04:37:38.681888+00	2026-09-11 04:37:38.681888+00
7	LI02	2026-08-24	t	8	\N	2026-09-11 04:37:38.681888+00	2026-09-11 04:37:38.681888+00
8	LI02	2026-08-31	t	8	\N	2026-09-11 04:37:38.681888+00	2026-09-11 04:37:38.681888+00
9	LI02	2026-09-07	t	8	\N	2026-09-11 04:37:38.681888+00	2026-09-11 04:37:38.681888+00
10	M03	2026-08-24	t	9	\N	2026-09-11 04:37:38.681888+00	2026-09-11 04:37:38.681888+00
11	M03	2026-08-31	t	9	\N	2026-09-11 04:37:38.681888+00	2026-09-11 04:37:38.681888+00
12	M03	2026-09-07	t	9	\N	2026-09-11 04:37:38.681888+00	2026-09-11 04:37:38.681888+00
13	B07	2026-08-24	t	9	\N	2026-09-11 04:37:38.681888+00	2026-09-11 04:37:38.681888+00
14	B07	2026-08-31	f	\N	\N	2026-09-11 04:37:38.681888+00	2026-09-11 04:37:38.681888+00
15	B07	2026-09-07	t	9	\N	2026-09-11 04:37:38.681888+00	2026-09-11 04:37:38.681888+00
16	SL02	2026-08-24	t	9	\N	2026-09-11 04:37:38.681888+00	2026-09-11 04:37:38.681888+00
17	SL02	2026-08-31	t	9	\N	2026-09-11 04:37:38.681888+00	2026-09-11 04:37:38.681888+00
18	SL02	2026-09-07	t	9	\N	2026-09-11 04:37:38.681888+00	2026-09-11 04:37:38.681888+00
19	SL05	2026-08-24	t	9	\N	2026-09-11 04:37:38.681888+00	2026-09-11 04:37:38.681888+00
20	SL05	2026-08-31	t	9	\N	2026-09-11 04:37:38.681888+00	2026-09-11 04:37:38.681888+00
21	SL05	2026-09-07	f	\N	\N	2026-09-11 04:37:38.681888+00	2026-09-11 04:37:38.681888+00
22	B12	2026-08-24	t	9	\N	2026-09-11 04:37:38.681888+00	2026-09-11 04:37:38.681888+00
23	B12	2026-08-31	t	9	\N	2026-09-11 04:37:38.681888+00	2026-09-11 04:37:38.681888+00
24	B12	2026-09-07	t	9	\N	2026-09-11 04:37:38.681888+00	2026-09-11 04:37:38.681888+00
\.


--
-- Data for Name: email_outbox; Type: TABLE DATA; Schema: notification; Owner: -
--

COPY notification.email_outbox (outbox_id, schedule_id, slug, no_dokumen, recipients, subject, attachment_path, status, note, created_at, sent_at) FROM stdin;
1	1	produksi-bap	RPT/PRODUKSIBAP/20260911/001	ops@pasirlaut.co.id, keu@pasirlaut.co.id	[ERP Pasir Laut] produksi-bap — RPT/PRODUKSIBAP/20260911/001	/demo/laporan-produksi-bap.pdf	SENT	uat-21 simulasi kirim	2026-09-11 04:37:39.116544+00	\N
2	1	produksi-bap	RPT/PRODUKSIBAP/20260911/002	ops@pasirlaut.co.id, keu@pasirlaut.co.id	[ERP Pasir Laut] #2	/demo/2.pdf	SENT	uat-21 simulasi kirim	2026-09-11 04:37:39.118637+00	\N
3	\N	pnbp	RPT/PNBP/20260909/099	keu@pasirlaut.co.id	manual	\N	SENT	uat-21 kirim manual	2026-09-11 04:37:39.119816+00	\N
\.


--
-- Data for Name: log; Type: TABLE DATA; Schema: notification; Owner: -
--

COPY notification.log (notif_id, rule_id, channel, recipient, payload, status, sent_at, created_at) FROM stdin;
1	2	EMAIL	rahmat@prn.co.id	{"bap_no": "BAP-2026-0087", "volume_m3": 5371.80}	SENT	2026-09-07 07:36:00+00	2026-09-07 07:36:00+00
2	2	EMAIL	ops@samudramitra.co.id	{"bap_no": "BAP-2026-0087", "hak_partner": 64461600}	SENT	2026-09-07 07:36:00+00	2026-09-07 07:36:00+00
3	1	TELEGRAM	ops-dispatch	{"value": 128, "station": "ST-03", "parameter": "TURBIDITY"}	SENT	2026-09-06 23:05:00+00	2026-09-06 23:05:00+00
4	1	TELEGRAM	nakhoda:SL02	{"via": "starlink", "value": 128, "station": "ST-03", "parameter": "TURBIDITY"}	SENT	2026-09-06 23:05:00+00	2026-09-06 23:05:00+00
5	4	TELEGRAM	ops-dispatch	{"zona": "Zona Dok Marina Jaya (DOK)", "event": "EXIT", "fleet": "B12", "waktu": "07 Sep 14:35 WIB", "posisi": "106.20, -5.925", "catatan": "kapal fase DOK terdeteksi di luar zona dok — cek tindak lanjut"}	SENT	2026-09-07 07:36:00+00	2026-09-11 04:37:38.859888+00
6	4	EMAIL	ops@ppteluk.co.id	{"zona": "Zona Dok Marina Jaya (DOK)", "event": "EXIT", "fleet": "B12", "waktu": "07 Sep 14:35 WIB", "posisi": "106.20, -5.925", "catatan": "kapal fase DOK terdeteksi di luar zona dok — cek tindak lanjut"}	SENT	2026-09-07 07:36:00+00	2026-09-11 04:37:38.859888+00
7	5	TELEGRAM	keu-pnbp	{"buyer": "Pan Jurong Reclamation Pte Ltd", "catatan": "bayar ≤7 hari sejak tagihan — izin batal bila lewat (Permen KP 41/2023)", "kontrak": "SC-2026-X01", "jatuh_tempo": "12 Sep 2026", "tagihan_tahap_awal": 1302000000}	SENT	2026-09-09 01:00:00+00	2026-09-11 04:37:38.925252+00
8	5	EMAIL	finance@ppteluk.co.id	{"buyer": "Pan Jurong Reclamation Pte Ltd", "catatan": "bayar ≤7 hari sejak tagihan — izin batal bila lewat (Permen KP 41/2023)", "kontrak": "SC-2026-X01", "jatuh_tempo": "12 Sep 2026", "tagihan_tahap_awal": 1302000000}	SENT	2026-09-09 01:00:00+00	2026-09-11 04:37:38.925252+00
9	6	EMAIL	ops@ppteluk.co.id	{"kapal": "SL09", "catatan": "laporan gangguan sinyal ke dispatcher", "gap_jam": 26, "klausul": "§9.1 CC-2026-005", "partner": "PT Bahari Lines"}	SENT	2026-09-11 02:37:38.964839+00	2026-09-11 04:37:38.964839+00
10	6	TELEGRAM	ops-dispatch	{"kapal": "SL09", "catatan": "transponder AIS tidak terdeteksi 26 jam — cek unit", "gap_jam": 26, "klausul": "§9.1 CC-2026-005", "partner": "PT Bahari Lines"}	SENT	2026-09-11 02:37:38.964839+00	2026-09-11 04:37:38.964839+00
11	7	EMAIL	ops@samudramitra.co.id	{"kapal": "SL05", "catatan": "mohon perbaikan terminal; sanksi potongan maks 5%", "klausul": "§8.2 CC-2026-004", "partner": "PT Samudra Mitra", "offline_jam": 72}	SENT	2026-09-11 02:37:38.964839+00	2026-09-11 04:37:38.964839+00
12	7	TELEGRAM	ops-dispatch	{"kapal": "SL05", "catatan": "Starlink offline 3 hari — BAP digital tertunda", "klausul": "§8.2 CC-2026-004", "partner": "PT Samudra Mitra", "offline_jam": 72}	SENT	2026-09-11 02:37:38.964839+00	2026-09-11 04:37:38.964839+00
\.


--
-- Data for Name: notif_inapp; Type: TABLE DATA; Schema: notification; Owner: -
--

COPY notification.notif_inapp (inapp_id, username, event, judul, isi, url, dibaca, created_at) FROM stdin;
\.


--
-- Data for Name: notif_outbox; Type: TABLE DATA; Schema: notification; Owner: -
--

COPY notification.notif_outbox (outbox_id, penerima_id, kanal, tujuan, event, judul, isi, status, error, created_at, sent_at) FROM stdin;
\.


--
-- Data for Name: notif_penerima; Type: TABLE DATA; Schema: notification; Owner: -
--

COPY notification.notif_penerima (penerima_id, kanal, tujuan, label, aktif, created_at) FROM stdin;
1	TELEGRAM	-1001234567890	Grup Dispatch (demo)	t	2026-09-21 07:18:37.066788+00
2	WHATSAPP	+6281234567890	Manager Ops (demo)	t	2026-09-21 07:18:37.067471+00
\.


--
-- Data for Name: report_schedule; Type: TABLE DATA; Schema: notification; Owner: -
--

COPY notification.report_schedule (schedule_id, slug, recipients, frekuensi, jam, is_active, last_sent_at, created_by, created_at) FROM stdin;
1	produksi-bap	ops@pasirlaut.co.id, keu@pasirlaut.co.id	DAILY	7	t	2026-09-11 04:37:39.116544+00	seed	2026-09-11 04:37:39.108027+00
\.


--
-- Data for Name: rule; Type: TABLE DATA; Schema: notification; Owner: -
--

COPY notification.rule (rule_id, event_type, template_ref, recipients, escalation, is_active, created_at, updated_at) FROM stdin;
1	EWS_EXCEEDED	tpl_ews_exceeded	{"email": ["env@ppteluk.co.id"], "telegram": ["ops-dispatch", "nakhoda-kapal"]}	{"level2_after_h": "2", "level3_after_h": "6"}	t	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
2	BAP_SIGNED	tpl_bap_signed	{"email": ["buyer-pic", "partner-pic"], "telegram": ["ops-dispatch"]}	\N	t	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
3	DEPOSIT_LOW	tpl_deposit_low	{"email": ["finance", "buyer-pic"]}	\N	t	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
4	GEOFENCE_EXIT	tpl_geofence_exit	{"email": ["ops@ppteluk.co.id"], "telegram": ["ops-dispatch", "kapten-b12"]}	{"level2_after_h": "1"}	t	2026-09-11 04:37:38.859555+00	2026-09-11 04:37:38.859555+00
5	PNBP_TAHAP_AWAL	tpl_pnbp_tahap_awal	{"email": ["finance@ppteluk.co.id", "cfo@ppteluk.co.id"], "telegram": ["keu-pnbp"]}	{"batal_izin": "tidak dibayar setelah due_date — persetujuan izin batal (Permen KP 41/2023)"}	t	2026-09-11 04:37:38.924967+00	2026-09-11 04:37:38.924967+00
6	AIS_SIGNAL_LOST	tpl_ais_lost	{"email": ["ops@ppteluk.co.id", "ops@baharilines.co.id"], "telegram": ["ops-dispatch"]}	{"sanksi": "gap > 24 jam = pelanggaran §9.1 — potongan invoice trip"}	t	2026-09-11 04:37:38.964338+00	2026-09-11 04:37:38.964338+00
7	STARLINK_OFFLINE	tpl_starlink_down	{"email": ["ops@ppteluk.co.id", "ops@samudramitra.co.id"], "telegram": ["ops-dispatch"]}	{"sanksi": "offline > 24 jam = pelanggaran §8.2 — potongan maks 5%"}	t	2026-09-11 04:37:38.964338+00	2026-09-11 04:37:38.964338+00
\.


--
-- Data for Name: discharge_event; Type: TABLE DATA; Schema: operational; Owner: -
--

COPY operational.discharge_event (event_id, trip_id, event, event_at, reason, note, tenant_id, created_at, updated_at) FROM stdin;
9a000000-0000-0000-0000-000000000921	907	START	2026-09-07 02:30:00+00	\N	mulai bongkar setelah slot site siap	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
9a000000-0000-0000-0000-000000000922	907	STOP	2026-09-07 03:45:00+00	CUACA	hujan singkat — jarak pandang	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
9a000000-0000-0000-0000-000000000923	907	RESUME	2026-09-07 04:10:00+00	\N	\N	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
9a000000-0000-0000-0000-000000000924	907	COMPLETE	2026-09-07 06:00:00+00	\N	bongkar tuntas — sisa di hopper dicek survey akhir	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
\.


--
-- Data for Name: doc_approval; Type: TABLE DATA; Schema: operational; Owner: -
--

COPY operational.doc_approval (approval_id, doc_kind, doc_id, level, approver_role, status, decided_by, decided_at, catatan, created_at) FROM stdin;
\.


--
-- Data for Name: line_compliance; Type: TABLE DATA; Schema: operational; Owner: -
--

COPY operational.line_compliance (compliance_id, trip_id, line_id, lon, lat, jarak_m, created_at) FROM stdin;
\.


--
-- Data for Name: manual_report; Type: TABLE DATA; Schema: operational; Owner: -
--

COPY operational.manual_report (report_id, trip_id, report_type, reported_at, reported_by, payload, client_synced_at, tenant_id, created_at, updated_at) FROM stdin;
9a000000-0000-0000-0000-000000000931	907	FUEL_STATUS	2026-09-06 22:00:00+00	H. Bakti	{"note": "cukup untuk 2 siklus", "fuel_level_pct": 62}	2026-09-06 22:02:00+00	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
\.


--
-- Data for Name: nor; Type: TABLE DATA; Schema: operational; Owner: -
--

COPY operational.nor (nor_id, trip_id, declared_by, declared_at, tenant_id, created_at) FROM stdin;
9a000000-0000-0000-0000-000000000907	907	H. Bakti (Nakhoda MV Sinar Laut 02)	2026-09-06 11:30:00+00	\N	2026-09-11 04:37:38.232279+00
9a000000-0000-0000-0000-000000000910	910	H. Andi (Nakhoda MV Sinar Laut 05)	2026-09-09 13:00:00+00	\N	2026-09-11 04:37:38.480484+00
\.


--
-- Data for Name: schedule_plan; Type: TABLE DATA; Schema: operational; Owner: -
--

COPY operational.schedule_plan (plan_id, trip_id, planned_loading_start, planned_discharge_end, delta_jam, status, is_active, created_by, approved_at, rejected_at, note, created_at) FROM stdin;
1	1	2026-07-19 05:00:00+00	2026-07-19 11:30:00+00	0.00	APPROVED	t	uat-approval	2026-09-11 04:37:39.064734+00	\N	AP-04	2026-09-11 04:37:39.064734+00
2	2	2026-07-20 15:00:00+00	2026-07-20 21:30:00+00	0.00	APPROVED	t	uat-approval	2026-09-11 04:37:39.064734+00	\N	AP-04	2026-09-11 04:37:39.064734+00
3	3	2026-07-21 20:00:00+00	2026-07-22 03:00:00+00	0.00	APPROVED	t	uat-approval	2026-09-11 04:37:39.064734+00	\N	AP-04	2026-09-11 04:37:39.064734+00
4	4	2026-07-23 00:00:00+00	2026-07-23 07:00:00+00	0.00	APPROVED	t	uat-approval	2026-09-11 04:37:39.064734+00	\N	AP-04	2026-09-11 04:37:39.064734+00
\.


--
-- Data for Name: schedule_proposal; Type: TABLE DATA; Schema: operational; Owner: -
--

COPY operational.schedule_proposal (proposal_id, payload, n_trip, status, proposed_by, proposed_at, decided_by, decided_at, catatan) FROM stdin;
1	{"mode": "gantt", "pinned": {}}	4	APPROVED	uat-approval	2026-09-11 04:37:39.063627+00	uat-approval	2026-09-11 04:37:39.064734+00	\N
2	{"mode": "gantt", "pinned": {}}	2	REJECTED	uat-approval	2026-09-11 04:37:39.06756+00	uat-approval	2026-09-11 04:37:39.06756+00	uji tolak
\.


--
-- Data for Name: shipment_instruction; Type: TABLE DATA; Schema: operational; Owner: -
--

COPY operational.shipment_instruction (si_id, si_num, do_id, issued_at, status) FROM stdin;
899	SI-2026-0899	329	2026-09-01 07:30:00+00	EXECUTED
903	SI-2026-0903	330	2026-09-03 05:30:00+00	EXECUTED
907	SI-2026-0907	341	2026-09-05 09:00:00+00	EXECUTED
910	SI-2026-0910	352	2026-09-07 23:30:00+00	EXECUTED
911	SI-2026-0911	353	2026-09-09 01:00:00+00	CANCELLED
1	SI-2026-00851	\N	2026-07-16 15:00:00+00	ISSUED
2	SI-2026-00852	\N	2026-07-18 01:00:00+00	ISSUED
3	SI-2026-00853	\N	2026-07-19 05:00:00+00	ISSUED
4	SI-2026-00854	\N	2026-07-20 09:00:00+00	ISSUED
5	SI-2026-00855	\N	2026-07-21 13:00:00+00	ISSUED
6	SI-2026-00856	\N	2026-07-22 03:00:00+00	ISSUED
7	SI-2026-00857	\N	2026-07-22 17:00:00+00	ISSUED
8	SI-2026-00858	\N	2026-07-23 19:00:00+00	ISSUED
9	SI-2026-00859	\N	2026-07-24 23:00:00+00	ISSUED
10	SI-2026-00860	\N	2026-07-25 03:00:00+00	ISSUED
11	SI-2026-00861	\N	2026-07-26 07:00:00+00	ISSUED
12	SI-2026-00862	\N	2026-07-27 11:00:00+00	ISSUED
13	SI-2026-00863	\N	2026-07-27 11:00:00+00	ISSUED
14	SI-2026-00864	\N	2026-07-28 13:00:00+00	ISSUED
15	SI-2026-00865	\N	2026-07-29 17:00:00+00	ISSUED
16	SI-2026-00866	\N	2026-07-30 21:00:00+00	ISSUED
17	SI-2026-00867	\N	2026-07-31 01:00:00+00	ISSUED
18	SI-2026-00868	\N	2026-08-01 05:00:00+00	ISSUED
19	SI-2026-00869	\N	2026-08-02 07:00:00+00	ISSUED
20	SI-2026-00870	\N	2026-08-02 19:00:00+00	ISSUED
21	SI-2026-00871	\N	2026-08-03 11:00:00+00	ISSUED
22	SI-2026-00872	\N	2026-08-04 09:00:00+00	ISSUED
23	SI-2026-00873	\N	2026-08-04 15:00:00+00	ISSUED
24	SI-2026-00874	\N	2026-08-05 19:00:00+00	ISSUED
25	SI-2026-00875	\N	2026-08-06 23:00:00+00	ISSUED
26	SI-2026-00876	\N	2026-08-07 21:00:00+00	ISSUED
27	SI-2026-00877	\N	2026-08-08 05:00:00+00	ISSUED
28	SI-2026-00878	\N	2026-08-10 17:00:00+00	ISSUED
912	SI-2026-DEMO-STRIP	\N	2026-09-21 04:18:37.673436+00	ISSUED
\.


--
-- Data for Name: site_contract; Type: TABLE DATA; Schema: operational; Owner: -
--

COPY operational.site_contract (site_contract_id, area_code, sales_contract_id, valid_from, valid_to, catatan, created_by, created_at) FROM stdin;
\.


--
-- Data for Name: site_line; Type: TABLE DATA; Schema: operational; Owner: -
--

COPY operational.site_line (line_id, line_code, area_code, line_no, geom, created_at) FROM stdin;
1	B04-L01	B-04	1	0102000020E610000002000000A4703D0AD77B5A401D5A643BDF4F17C091ED7C3F357E5A40022B8716D94E17C0	2026-09-21 07:18:37.659581+00
2	B04-L02	B-04	2	0102000020E61000000200000096438B6CE77B5A40F2D24D62105817C083C0CAA1457E5A40D7A3703D0A5717C0	2026-09-21 07:18:37.672921+00
\.


--
-- Data for Name: site_permit; Type: TABLE DATA; Schema: operational; Owner: -
--

COPY operational.site_permit (site_permit_id, trip_id, permit_no, issuer, issued_at, valid_until, note, tenant_id, created_at, updated_at) FROM stdin;
1	907	SP-SITEG-2026-0907	PT Pembangunan Reklamasi Nusantara	2026-09-05 02:00:00+00	2026-09-08 16:59:00+00	izin memasuki area bongkar site G	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
\.


--
-- Data for Name: trip; Type: TABLE DATA; Schema: operational; Owner: -
--

COPY operational.trip (trip_id, trip_no, si_num, fleet_code, work_area_code, status, discharge_method, ts_loading_start, ts_departed, ts_arrived, ts_discharge_start, ts_discharge_end, ts_bap_signed, ts_closed, volume_load_m3, volume_bap_m3, residual_m3, is_locked, tenant_id, created_at, updated_at, line_id, discharge_fence_code) FROM stdin;
899	TRP-2026-0899	SI-2026-0899	SL05	B-04	CLOSED	PUMP_ASHORE	2026-08-31 18:00:00+00	2026-09-01 08:00:00+00	2026-09-01 14:00:00+00	2026-09-01 14:30:00+00	2026-09-01 20:00:00+00	2026-09-01 22:10:00+00	2026-09-03 02:00:00+00	5250.000	5250.000	0.000	t	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00	\N	\N
903	TRP-2026-0903	SI-2026-0903	SL09	B-07	CLOSED	BOTTOM_DUMP	2026-09-02 18:00:00+00	2026-09-03 07:00:00+00	2026-09-03 13:00:00+00	2026-09-03 13:30:00+00	2026-09-03 19:00:00+00	2026-09-04 00:10:00+00	2026-09-05 03:00:00+00	5001.120	4982.558	18.562	t	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00	\N	\N
907	TRP-2026-0907	SI-2026-0907	SL02	B-04	SETTLED	PUMP_ASHORE	2026-09-04 18:00:00+00	2026-09-06 11:00:00+00	2026-09-06 19:00:00+00	2026-09-07 02:30:00+00	2026-09-07 06:00:00+00	2026-09-07 07:35:00+00	\N	5420.500	5371.800	26.400	t	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00	\N	\N
910	TRP-2026-0910	SI-2026-0910	SL05	B-07	INVOICED	PUMP_ASHORE	2026-09-07 23:00:00+00	2026-09-08 07:00:00+00	2026-09-09 10:30:00+00	2026-09-09 15:00:00+00	2026-09-09 18:00:00+00	2026-09-09 19:15:00+00	\N	4000.000	3950.000	20.000	f	\N	2026-09-11 04:37:38.478612+00	2026-09-11 04:37:38.478612+00	\N	\N
911	TRP-2026-0911	SI-2026-0911	SL09	B-07	CANCELLED	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	\N	2026-09-11 04:37:38.478612+00	2026-09-11 04:37:38.478612+00	\N	\N
1	TRP-2026-00851	SI-2026-00851	SL05	B-04	CLOSED	PUMP_ASHORE	2026-07-18 15:00:00+00	2026-07-19 05:00:00+00	2026-07-19 11:30:00+00	2026-07-19 12:00:00+00	2026-07-19 18:00:00+00	2026-07-19 20:10:00+00	2026-07-20 22:10:00+00	5400.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
2	TRP-2026-00852	SI-2026-00852	SL07	B-04	CLOSED	PUMP_ASHORE	2026-07-20 01:00:00+00	2026-07-20 15:00:00+00	2026-07-20 21:30:00+00	2026-07-20 22:00:00+00	2026-07-21 04:00:00+00	2026-07-21 06:10:00+00	2026-07-22 08:10:00+00	5400.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
3	TRP-2026-00853	SI-2026-00853	B07	B-04	CLOSED	BOTTOM_DUMP	2026-07-21 05:00:00+00	2026-07-21 20:00:00+00	2026-07-22 03:00:00+00	2026-07-22 03:30:00+00	2026-07-22 10:00:00+00	2026-07-22 12:10:00+00	2026-07-23 14:10:00+00	4900.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
4	TRP-2026-00854	SI-2026-00854	B12	B-04	CLOSED	BOTTOM_DUMP	2026-07-22 09:00:00+00	2026-07-23 00:00:00+00	2026-07-23 07:00:00+00	2026-07-23 07:30:00+00	2026-07-23 14:00:00+00	2026-07-23 16:10:00+00	2026-07-24 18:10:00+00	4900.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
5	TRP-2026-00855	SI-2026-00855	LI02	B-04	CLOSED	BOTTOM_DUMP	2026-07-23 13:00:00+00	2026-07-23 22:00:00+00	2026-07-24 04:00:00+00	2026-07-24 04:30:00+00	2026-07-24 09:30:00+00	2026-07-24 11:40:00+00	2026-07-25 13:40:00+00	2800.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
6	TRP-2026-00856	SI-2026-00856	SL05	B-07	CLOSED	BOTTOM_DUMP	2026-07-24 03:00:00+00	2026-07-24 17:00:00+00	2026-07-24 23:30:00+00	2026-07-25 00:00:00+00	2026-07-25 06:00:00+00	2026-07-25 08:10:00+00	2026-07-26 17:10:00+00	5400.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
7	TRP-2026-00857	SI-2026-00857	M03	B-04	CLOSED	BOTTOM_DUMP	2026-07-24 17:00:00+00	2026-07-25 07:00:00+00	2026-07-25 14:00:00+00	2026-07-25 14:30:00+00	2026-07-25 20:30:00+00	2026-07-25 22:40:00+00	2026-07-27 00:40:00+00	5400.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
8	TRP-2026-00858	SI-2026-00858	SL07	B-07	CLOSED	BOTTOM_DUMP	2026-07-25 19:00:00+00	2026-07-26 09:00:00+00	2026-07-26 15:30:00+00	2026-07-26 16:00:00+00	2026-07-26 22:00:00+00	2026-07-27 00:10:00+00	2026-07-28 09:10:00+00	5400.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
9	TRP-2026-00859	SI-2026-00859	B07	B-07	CLOSED	PUMP_ASHORE	2026-07-26 23:00:00+00	2026-07-27 14:00:00+00	2026-07-27 21:00:00+00	2026-07-27 21:30:00+00	2026-07-28 04:00:00+00	2026-07-28 06:10:00+00	2026-07-29 15:10:00+00	4900.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
10	TRP-2026-00860	SI-2026-00860	B12	B-07	CLOSED	PUMP_ASHORE	2026-07-27 03:00:00+00	2026-07-27 18:00:00+00	2026-07-28 01:00:00+00	2026-07-28 01:30:00+00	2026-07-28 08:00:00+00	2026-07-28 10:10:00+00	2026-07-29 19:10:00+00	4900.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
11	TRP-2026-00861	SI-2026-00861	LI02	B-07	CLOSED	PUMP_ASHORE	2026-07-28 07:00:00+00	2026-07-28 16:00:00+00	2026-07-28 22:00:00+00	2026-07-28 22:30:00+00	2026-07-29 03:30:00+00	2026-07-29 05:40:00+00	2026-07-30 14:40:00+00	2800.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
12	TRP-2026-00862	SI-2026-00862	M03	B-07	CLOSED	PUMP_ASHORE	2026-07-29 11:00:00+00	2026-07-30 01:00:00+00	2026-07-30 08:00:00+00	2026-07-30 08:30:00+00	2026-07-30 14:30:00+00	2026-07-30 16:40:00+00	2026-08-01 01:40:00+00	5400.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
13	TRP-2026-00863	SI-2026-00863	SL09	B-04	CLOSED	PUMP_ASHORE	2026-07-29 11:00:00+00	2026-07-30 01:00:00+00	2026-07-30 07:30:00+00	2026-07-30 08:00:00+00	2026-07-30 14:00:00+00	2026-07-30 16:10:00+00	2026-07-31 18:10:00+00	5400.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
14	TRP-2026-00864	SI-2026-00864	SL07	B-04	CLOSED	PUMP_ASHORE	2026-07-30 13:00:00+00	2026-07-31 03:00:00+00	2026-07-31 09:30:00+00	2026-07-31 10:00:00+00	2026-07-31 16:00:00+00	2026-07-31 18:10:00+00	2026-08-02 10:10:00+00	5400.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
15	TRP-2026-00865	SI-2026-00865	B07	B-04	CLOSED	BOTTOM_DUMP	2026-07-31 17:00:00+00	2026-08-01 08:00:00+00	2026-08-01 15:00:00+00	2026-08-01 15:30:00+00	2026-08-01 22:00:00+00	2026-08-02 00:10:00+00	2026-08-03 16:10:00+00	4900.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
16	TRP-2026-00866	SI-2026-00866	B12	B-04	CLOSED	BOTTOM_DUMP	2026-08-01 21:00:00+00	2026-08-02 12:00:00+00	2026-08-02 19:00:00+00	2026-08-02 19:30:00+00	2026-08-03 02:00:00+00	2026-08-03 04:10:00+00	2026-08-04 20:10:00+00	4900.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
17	TRP-2026-00867	SI-2026-00867	LI02	B-04	CLOSED	BOTTOM_DUMP	2026-08-02 01:00:00+00	2026-08-02 10:00:00+00	2026-08-02 16:00:00+00	2026-08-02 16:30:00+00	2026-08-02 21:30:00+00	2026-08-02 23:40:00+00	2026-08-04 15:40:00+00	2800.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
18	TRP-2026-00868	SI-2026-00868	M03	B-04	CLOSED	BOTTOM_DUMP	2026-08-03 05:00:00+00	2026-08-03 19:00:00+00	2026-08-04 02:00:00+00	2026-08-04 02:30:00+00	2026-08-04 08:30:00+00	2026-08-04 10:40:00+00	2026-08-06 02:40:00+00	5400.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
19	TRP-2026-00869	SI-2026-00869	SL07	B-07	CLOSED	PUMP_ASHORE	2026-08-04 07:00:00+00	2026-08-04 21:00:00+00	2026-08-05 03:30:00+00	2026-08-05 04:00:00+00	2026-08-05 10:00:00+00	2026-08-05 12:10:00+00	2026-08-07 11:10:00+00	5400.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
20	TRP-2026-00870	SI-2026-00870	SL09	B-07	CLOSED	BOTTOM_DUMP	2026-08-04 19:00:00+00	2026-08-05 09:00:00+00	2026-08-05 15:30:00+00	2026-08-05 16:00:00+00	2026-08-05 22:00:00+00	2026-08-06 00:10:00+00	2026-08-07 09:10:00+00	5400.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
21	TRP-2026-00871	SI-2026-00871	B07	B-07	CLOSED	BOTTOM_DUMP	2026-08-05 11:00:00+00	2026-08-06 02:00:00+00	2026-08-06 09:00:00+00	2026-08-06 09:30:00+00	2026-08-06 16:00:00+00	2026-08-06 18:10:00+00	2026-08-08 17:10:00+00	4900.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
22	TRP-2026-00872	SI-2026-00872	SL02	B-04	CLOSED	PUMP_ASHORE	2026-08-06 09:00:00+00	2026-08-06 23:00:00+00	2026-08-07 05:30:00+00	2026-08-07 06:00:00+00	2026-08-07 12:00:00+00	2026-08-07 14:10:00+00	2026-08-08 16:10:00+00	5400.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
23	TRP-2026-00873	SI-2026-00873	B12	B-07	CLOSED	BOTTOM_DUMP	2026-08-06 15:00:00+00	2026-08-07 06:00:00+00	2026-08-07 13:00:00+00	2026-08-07 13:30:00+00	2026-08-07 20:00:00+00	2026-08-07 22:10:00+00	2026-08-09 21:10:00+00	4900.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
24	TRP-2026-00874	SI-2026-00874	LI02	B-07	CLOSED	BOTTOM_DUMP	2026-08-07 19:00:00+00	2026-08-08 04:00:00+00	2026-08-08 10:00:00+00	2026-08-08 10:30:00+00	2026-08-08 15:30:00+00	2026-08-08 17:40:00+00	2026-08-10 16:40:00+00	2800.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
25	TRP-2026-00875	SI-2026-00875	M03	B-07	CLOSED	BOTTOM_DUMP	2026-08-08 23:00:00+00	2026-08-09 13:00:00+00	2026-08-09 20:00:00+00	2026-08-09 20:30:00+00	2026-08-10 02:30:00+00	2026-08-10 04:40:00+00	2026-08-12 03:40:00+00	5400.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
26	TRP-2026-00876	SI-2026-00876	SL07	B-04	CLOSED	BOTTOM_DUMP	2026-08-09 21:00:00+00	2026-08-10 11:00:00+00	2026-08-10 17:30:00+00	2026-08-10 18:00:00+00	2026-08-11 00:00:00+00	2026-08-11 02:10:00+00	2026-08-12 10:10:00+00	5400.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
27	TRP-2026-00877	SI-2026-00877	SL09	B-04	CLOSED	PUMP_ASHORE	2026-08-10 05:00:00+00	2026-08-10 19:00:00+00	2026-08-11 01:30:00+00	2026-08-11 02:00:00+00	2026-08-11 08:00:00+00	2026-08-11 10:10:00+00	2026-08-13 02:10:00+00	5400.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
28	TRP-2026-00878	SI-2026-00878	SL02	B-07	CLOSED	BOTTOM_DUMP	2026-08-12 17:00:00+00	2026-08-13 07:00:00+00	2026-08-13 13:30:00+00	2026-08-13 14:00:00+00	2026-08-13 20:00:00+00	2026-08-13 22:10:00+00	2026-08-15 07:10:00+00	5400.000	\N	\N	t	\N	2026-09-11 04:37:38.716843+00	2026-09-11 04:37:38.716843+00	\N	\N
912	TRP-2026-DEMO-STRIP	SI-2026-DEMO-STRIP	M03	B-04	LOADING	\N	2026-09-21 05:18:37.674007+00	\N	\N	\N	\N	\N	\N	3200.000	\N	\N	f	\N	2026-09-21 07:18:37.674007+00	2026-09-21 07:18:37.674007+00	1	\N
\.


--
-- Data for Name: trip_doc_check; Type: TABLE DATA; Schema: operational; Owner: -
--

COPY operational.trip_doc_check (check_id, trip_id, result, catatan, verified_by, verified_at) FROM stdin;
\.


--
-- Data for Name: voyage_doc; Type: TABLE DATA; Schema: operational; Owner: -
--

COPY operational.voyage_doc (doc_id, doc_no, qr_token, doc_type, trip_id, payload, nor_id, status, submitted_by, submitted_at, decided_at, is_locked, tenant_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: voyage_plan; Type: TABLE DATA; Schema: operational; Owner: -
--

COPY operational.voyage_plan (plan_id, trip_id, plan_no, qr_token, do_seq, route_note, etd_plan, eta_plan, discharge_window, discharge_method_plan, volume_plan_m3, nav_note, status, created_by, submitted_by, submitted_at, decided_at, is_locked, tenant_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: waiting_log; Type: TABLE DATA; Schema: operational; Owner: -
--

COPY operational.waiting_log (waiting_id, trip_id, start_at, end_at, cause, note, tenant_id, created_at, updated_at) FROM stdin;
9a000000-0000-0000-0000-000000000911	907	2026-09-05 21:30:00+00	2026-09-06 11:00:00+00	PASUT	menunggu pasang sore untuk keberangkatan	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
9a000000-0000-0000-0000-000000000912	907	2026-09-06 19:00:00+00	2026-09-07 02:30:00+00	ANTRIAN_KAPAL	slot bongkar site G — 1 kapal di depan	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
\.


--
-- Data for Name: work_area; Type: TABLE DATA; Schema: operational; Owner: -
--

COPY operational.work_area (area_code, area_name, area_type, status, permit_no, quota_m3, quota_used_m3, zone_code, geom, fence_code) FROM stdin;
B-04	Blok Pengerukan B-04	BLOK_KERUK	AKTIF	IPPL-2026-014-B04	1200000.000	876000.000	WK-01	0103000020E61000000100000005000000EC51B81E857B5A4048E17A14AE4717C066666666667E5A401283C0CAA14517C03BDF4F8D977E5A40E17A14AE476117C0C1CAA145B67B5A4017D9CEF7536317C0EC51B81E857B5A4048E17A14AE4717C0	F-B04
B-07	Blok Pengerukan B-07	BLOK_KERUK	AKTIF	IPPL-2026-014-B07	800000.000	259950.000	WK-01	0103000020E6100000010000001900000048E17A14AE875A407B14AE47E17A17C0CDCCCCCCCC7C5A40F6285C8FC27517C03762C711A47C5A40F332D2E4AA6217C0B5A3548D977E5A40CCC5C8B4476117C062566A8D977E5A40C87695B4476117C059EE7E8D977E5A4008AE1CB4476117C09E8F918D977E5A40CC7563B3476117C02F73A18D977E5A40A18871B2476117C051EFAD8D977E5A40D9FE50B1476117C0A67EB68D977E5A40ADE20DB0476117C0BEC5BA8D977E5A40A6AFB5AE476117C0E696BA8D977E5A4095C256AD476117C0111ED166667E5A40C6CA02CAA14517C0D004CD66667E5A4015E7C6C8A14517C01B4DC566667E5A4013D89CC7A14517C0A03CBA66667E5A40A4208FC6A14517C04237AC66667E5A40CF43A7C5A14517C097BB9B66667E5A40D96EEDC4A14517C06D5E8966667E5A40772F68C4A14517C090C57566667E5A40A1381CC4A14517C0ECA16166667E5A4027380CC4A14517C04195FF24697C5A40081F2AE70B4717C05C8FC2F5287C5A40295C8FC2F52817C0D7A3703D0A875A40AE47E17A142E17C048E17A14AE875A407B14AE47E17A17C0	F-B07
\.


--
-- Data for Name: work_zone; Type: TABLE DATA; Schema: operational; Owner: -
--

COPY operational.work_zone (zone_code, zone_name, permit_no, status, geom, quota_m3, quota_used_m3, created_at, updated_at) FROM stdin;
WK-01	Wilayah Kerja IPPL-2026-014	IPPL-2026-014	AKTIF	0106000020E6100000020000000103000000010000000500000066666666667E5A401283C0CAA14517C03BDF4F8D977E5A40E17A14AE476117C0C1CAA145B67B5A4017D9CEF7536317C0EC51B81E857B5A4048E17A14AE4717C066666666667E5A401283C0CAA14517C001030000000100000019000000CDCCCCCCCC7C5A40F6285C8FC27517C03762C711A47C5A40F332D2E4AA6217C0B5A3548D977E5A40CCC5C8B4476117C062566A8D977E5A40C87695B4476117C059EE7E8D977E5A4008AE1CB4476117C09E8F918D977E5A40CC7563B3476117C02F73A18D977E5A40A18871B2476117C051EFAD8D977E5A40D9FE50B1476117C0A67EB68D977E5A40ADE20DB0476117C0BEC5BA8D977E5A40A6AFB5AE476117C0E696BA8D977E5A4095C256AD476117C0111ED166667E5A40C6CA02CAA14517C0D004CD66667E5A4015E7C6C8A14517C01B4DC566667E5A4013D89CC7A14517C0A03CBA66667E5A40A4208FC6A14517C04237AC66667E5A40CF43A7C5A14517C097BB9B66667E5A40D96EEDC4A14517C06D5E8966667E5A40772F68C4A14517C090C57566667E5A40A1381CC4A14517C0ECA16166667E5A4027380CC4A14517C04195FF24697C5A40081F2AE70B4717C05C8FC2F5287C5A40295C8FC2F52817C0D7A3703D0A875A40AE47E17A142E17C048E17A14AE875A407B14AE47E17A17C0CDCCCCCCCC7C5A40F6285C8FC27517C0	2000000.000	1135950.000	2026-09-21 07:18:37.395001+00	2026-09-21 07:18:37.395001+00
\.


--
-- Data for Name: audit_log; Type: TABLE DATA; Schema: param; Owner: -
--

COPY param.audit_log (audit_id, tabel, record_key, kolom, nilai_lama, nilai_baru, diubah_oleh, diubah_pada) FROM stdin;
1	param.system_parameter	ews_warning_pct	nilai	90	85	uat-rbac	2026-09-11 04:37:39.012586+00
2	param.system_parameter	ews_warning_pct	nilai	85	90	uat-rbac	2026-09-11 04:37:39.0144+00
\.


--
-- Data for Name: audit_log_arch; Type: TABLE DATA; Schema: param; Owner: -
--

COPY param.audit_log_arch (audit_id, tabel, record_key, kolom, nilai_lama, nilai_baru, diubah_oleh, diubah_pada, diarsip_pada) FROM stdin;
\.


--
-- Data for Name: currency; Type: TABLE DATA; Schema: param; Owner: -
--

COPY param.currency (currency_code, currency_name) FROM stdin;
IDR	Rupiah
USD	US Dollar
\.


--
-- Data for Name: doc_code; Type: TABLE DATA; Schema: param; Owner: -
--

COPY param.doc_code (code_kind, code, label, ref_table, ref_key, created_at) FROM stdin;
KAPAL	SL07	MV Sinar Laut 07	fleet.info	SL07	2026-09-21 07:18:37.338378+00
KAPAL	SL09	MV Sinar Laut 09	fleet.info	SL09	2026-09-21 07:18:37.338378+00
KAPAL	LI02	TB Laut Indah 02	fleet.info	LI02	2026-09-21 07:18:37.338378+00
KAPAL	M03	TB Mulya 03	fleet.info	M03	2026-09-21 07:18:37.338378+00
KAPAL	B07	TB Bahari 07	fleet.info	B07	2026-09-21 07:18:37.338378+00
KAPAL	SL02	MV Sinar Laut 02	fleet.info	SL02	2026-09-21 07:18:37.338378+00
KAPAL	SL05	MV Sinar Laut 05	fleet.info	SL05	2026-09-21 07:18:37.338378+00
KAPAL	B12	TB Bahari 12	fleet.info	B12	2026-09-21 07:18:37.338378+00
RUTE	B04	Blok Pengerukan B-04	operational.work_area	B-04	2026-09-21 07:18:37.338378+00
RUTE	B07	Blok Pengerukan B-07	operational.work_area	B-07	2026-09-21 07:18:37.338378+00
LOKASI	B04	Site B-04	operational.work_area	B-04	2026-09-21 07:18:37.45904+00
LOKASI	B07	Site B-07	operational.work_area	B-07	2026-09-21 07:18:37.45904+00
LOKASI	WK1	Wilayah WK-01	operational.work_zone	WK-01	2026-09-21 07:18:37.45904+00
\.


--
-- Data for Name: doc_seq; Type: TABLE DATA; Schema: param; Owner: -
--

COPY param.doc_seq (jenis, scope, thbl, last_no) FROM stdin;
\.


--
-- Data for Name: module_acl; Type: TABLE DATA; Schema: param; Owner: -
--

COPY param.module_acl (modul_key, peran, updated_at) FROM stdin;
dashboard	ADMIN	2026-09-21 07:18:37.64931+00
dashboard	OPS	2026-09-21 07:18:37.64931+00
dashboard	KEU	2026-09-21 07:18:37.64931+00
dashboard	HSE	2026-09-21 07:18:37.64931+00
trips	ADMIN	2026-09-21 07:18:37.64931+00
trips	OPS	2026-09-21 07:18:37.64931+00
trips	KEU	2026-09-21 07:18:37.64931+00
pelayaran	ADMIN	2026-09-21 07:18:37.64931+00
pelayaran	OPS	2026-09-21 07:18:37.64931+00
wilayah	ADMIN	2026-09-21 07:18:37.64931+00
wilayah	OPS	2026-09-21 07:18:37.64931+00
misi	ADMIN	2026-09-21 07:18:37.64931+00
misi	OPS	2026-09-21 07:18:37.64931+00
misi	SURVEYOR	2026-09-21 07:18:37.64931+00
misi_rekap	ADMIN	2026-09-21 07:18:37.64931+00
misi_rekap	KEU	2026-09-21 07:18:37.64931+00
misi_rekap	OPS	2026-09-21 07:18:37.64931+00
deposit	ADMIN	2026-09-21 07:18:37.64931+00
deposit	KEU	2026-09-21 07:18:37.64931+00
armada	ADMIN	2026-09-21 07:18:37.64931+00
armada	OPS	2026-09-21 07:18:37.64931+00
kapal	ADMIN	2026-09-21 07:18:37.64931+00
kapal	OPS	2026-09-21 07:18:37.64931+00
survey	ADMIN	2026-09-21 07:18:37.64931+00
survey	OPS	2026-09-21 07:18:37.64931+00
keu	ADMIN	2026-09-21 07:18:37.64931+00
keu	KEU	2026-09-21 07:18:37.64931+00
enviro	ADMIN	2026-09-21 07:18:37.64931+00
enviro	OPS	2026-09-21 07:18:37.64931+00
enviro	HSE	2026-09-21 07:18:37.64931+00
hse	ADMIN	2026-09-21 07:18:37.64931+00
hse	HSE	2026-09-21 07:18:37.64931+00
laporan	ADMIN	2026-09-21 07:18:37.64931+00
laporan	OPS	2026-09-21 07:18:37.64931+00
laporan	KEU	2026-09-21 07:18:37.64931+00
laporan	HSE	2026-09-21 07:18:37.64931+00
notifikasi	ADMIN	2026-09-21 07:18:37.64931+00
analitik	ADMIN	2026-09-21 07:18:37.64931+00
analitik	OPS	2026-09-21 07:18:37.64931+00
analitik	KEU	2026-09-21 07:18:37.64931+00
analitik	HSE	2026-09-21 07:18:37.64931+00
formulir	ADMIN	2026-09-21 07:18:37.64931+00
formulir	OPS	2026-09-21 07:18:37.64931+00
formulir	HSE	2026-09-21 07:18:37.64931+00
pengaturan	ADMIN	2026-09-21 07:18:37.64931+00
indeks	ADMIN	2026-09-21 07:18:37.64931+00
indeks	OPS	2026-09-21 07:18:37.64931+00
indeks	KEU	2026-09-21 07:18:37.64931+00
indeks	HSE	2026-09-21 07:18:37.64931+00
indeks	SURVEYOR	2026-09-21 07:18:37.64931+00
\.


--
-- Data for Name: status; Type: TABLE DATA; Schema: param; Owner: -
--

COPY param.status (status_group, status_code, status_name) FROM stdin;
TRIP_STATUS	LOADING	Sedang muat di blok
TRIP_STATUS	SURVEY_SETTLING	Survey penyelesaian muat
TRIP_STATUS	DEPARTED	Berangkat ke site bongkar
TRIP_STATUS	ARRIVED	Tiba di site (geofence otomatis)
TRIP_STATUS	SURVEY_DISCHARGE	Survey awal bongkar
TRIP_STATUS	DISCHARGING	Bongkar berjalan
TRIP_STATUS	BAP_RETURN	Menunggu / proses BAP
TRIP_STATUS	INVOICED	Tagihan terbit
TRIP_STATUS	SETTLED	Settled (deposit/AR diproses)
TRIP_STATUS	CLOSED	Trip selesai & terkunci
TRIP_STATUS	CANCELLED	Dibatalkan
TRIP_STATUS	PARTIAL	Bongkar parsial (multi-site)
TRIP_STATUS	CLAIM	Klaim / sanggahan
BAP_STATUS	DRAFT	Draft BAP
BAP_STATUS	SIGNED	BAP sah (TTD 3 pihak lengkap)
BAP_STATUS	DISPUTED	Disangkal customer (objection)
BAP_STATUS	CORRECTED	Dikoreksi (dokumen koreksi bernomor)
PAYABLE_STATUS	WAITING	Menunggu pemicu pencairan
PAYABLE_STATUS	TRIGGERED	Terpicu — siap ditagih/dibayar
PAYABLE_STATUS	PAID	Terbayar
\.


--
-- Data for Name: system_parameter; Type: TABLE DATA; Schema: param; Owner: -
--

COPY param.system_parameter (param_key, label, nilai, satuan, keterangan, updated_at, updated_by) FROM stdin;
shrinkage_tol_pct	Toleransi shrinkage QA	2	%	Di atas ambang → flag QA review	2026-09-11 04:37:39.006193+00	seed
free_time_default	Free time bongkar default (R12)	24	jam	Default; nilai per kontrak dapat berbeda	2026-09-11 04:37:39.006193+00	seed
hs_waspada_bongkar	Ambang Hs waspada bongkar di site	1.0	m	Kebijakan internal ops (bukan regulasi)	2026-09-11 04:37:39.006193+00	seed
hs_tunda_ops	Ambang Hs tunda pengerukan/bongkar	1.5	m	Kebijakan internal ops (bukan regulasi)	2026-09-11 04:37:39.006193+00	seed
ews_warning_pct	Ambang EWS warning (dari baku mutu)	90	%	Pemicu warning pemantauan kualitas air	2026-09-11 04:37:39.0144+00	uat-rbac
ais_tarik_terakhir	Tarik AIS terakhir	—	waktu	Command tarik_ais (ops-v2 W2.1): simulator default, provider nyata via env AIS_MODE=api	2026-09-21 07:18:37.257334+00	sistem
notif_kirim_terakhir	Kirim notif instan terakhir	—	waktu	Command kirim_notif (cron): outbox default, kirim nyata via env TELEGRAM_BOT_TOKEN/WA_API_URL	2026-09-21 07:18:37.257334+00	sistem
email_jadwal_terakhir	Kirim email terjadwal terakhir	—	waktu	Command kirim_email_jadwal (cron): mode arsip/outbox default, SMTP nyata via env	2026-09-21 07:18:37.257334+00	sistem
wajib_2fa_peran	Peran wajib 2FA (JSON)	[]	json	ops-v2 W2.6: daftar peran (JSON) yang wajib 2FA — kosong = semua opsional	2026-09-21 07:18:37.257334+00	seed
wajib_2fa_tenggat	Tenggat wajib 2FA		tanggal	ops-v2 W2.6: sebelum tanggal ini = masa tenggang (banner pengingat); setelah = wajib mutlak	2026-09-21 07:18:37.257334+00	seed
pelayaran_gate_rpl	Gate berlayar: RPL disetujui	1	\N	Berlayar wajib RPL disetujui (0 = lunak)	2026-09-21 07:18:37.338378+00	seed
pelayaran_gate_bak	Gate berlayar: BA Keberangkatan disetujui	1	\N	Berlayar wajib BAK disetujui (0 = lunak)	2026-09-21 07:18:37.338378+00	seed
pelayaran_gate_verif	Gate berlayar: LULUS VERIFIKASI	1	\N	Berlayar wajib lulus verifikasi kelengkapan (0 = lunak)	2026-09-21 07:18:37.338378+00	seed
pelayaran_doc_wajib	Item checklist wajib	RPL,BAK,BAT,BAP	\N	EKSTERNAL = opsional terverifikasi	2026-09-21 07:18:37.338378+00	seed
pelayaran_sla_jam	SLA persetujuan dokumen (jam)	24	\N	Pengingat aging persetujuan	2026-09-21 07:18:37.338378+00	seed
mission_kind_survei	Jenis misi family SURVEI	BATHY,SAMP,ENV,BUOY		feat-v8 FR-4-02 — bathymetri/sampling/lingkungan/buoy (dikelola ADMIN)	2026-09-21 07:18:37.45904+00	ddl-14
mission_kind_dukungan	Jenis misi family DUKUNGAN	ANGKUT,MAINT,PATROLI		feat-v8 FR-4-02 — angkutan/maintenance/patroli (naratif + foto)	2026-09-21 07:18:37.45904+00	ddl-14
mission_check_wajib	Item checklist kelayakan misi	CUACA,PPE,KOMUNIKASI,ABK,ALAT		feat-v8 FR-4-09 — gate berangkat: seluruh item wajib OK	2026-09-21 07:18:37.45904+00	ddl-14
mission_off_lokasi	Kode [LOKASI] fallback nomor MSV	OFF		feat-v8 FR-4-17 — bila target di luar site/wilayah terdaftar	2026-09-21 07:18:37.45904+00	ddl-14
mission_laporan_x_hari	Batas hari PULANG tanpa laporan	3	hari	feat-v8 FR-4-24 — notifikasi misi PULANG tanpa laporan melewati X hari	2026-09-21 07:18:37.45904+00	ddl-14
mission_file_max_mb	Ukuran maksimum file hasil misi	10	MB	feat-v8 NFR-4-06 — PDF/CSV/XYZ/JPG (Supabase Storage / DB)	2026-09-21 07:18:37.45904+00	ddl-14
mission_wo_autolink	Tandai WO terpenuhi otomatis saat misi SELESAI	1		feat-v8 FR-4-11 — 1=aktif: station×parameter terjangkau misi ditandai	2026-09-21 07:18:37.45904+00	ddl-14
misi_rutin_aktif	Generator misi rutin	1	flag	0/1 — command misi_rutin (cron) membuat draft misi RENCANA dari enviro.mon_schedule untuk review OPS/ADMIN	2026-09-21 07:18:37.526143+00	seed
misi_rutin_horizon_hari	Horizon misi rutin	7	hari	Jadwal monitoring dengan next_due <= hari ini + horizon dibuatkan draft misi (feat-v8.1)	2026-09-21 07:18:37.526143+00	seed
misi_rutin_terakhir	Generator misi rutin terakhir		waktu	Diisi command misi_rutin (cron 05:30) — dipantau halaman Status Sistem (feat-v8.1)	2026-09-21 07:18:37.526143+00	seed
\.


--
-- Data for Name: charter_contract; Type: TABLE DATA; Schema: partner; Owner: -
--

COPY partner.charter_contract (charter_contract_id, contract_no, partner_code, fleet_code, date_start, date_end, scheme, billing_schedule, gps_starlink_clause, status, tenant_id, created_at, updated_at) FROM stdin;
3	CC-2026-003	P-SMI	SL02	2026-01-01	2026-12-31	PER_M3	PER_TRIP_BAP	§7.1 GPS/AIS: transponder AIS wajib aktif sepanjang operasi; interval transmisi posisi maks. 5 menit. §7.2 Starlink: koneksi wajib aktif untuk pelaporan real-time (telemetry, BAP digital); gangguan > 24 jam wajib dilaporkan ke dispatcher. §7.3 Sanksi: pelanggaran berulang dikenakan potongan maks. 5% nilai invoice trip terkait.	AKTIF	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
4	CC-2026-004	P-SMI	SL05	2026-01-01	2026-12-31	PER_M3	PER_TRIP_BAP	§8.1 GPS/AIS: transponder AIS wajib aktif; interval transmisi maks. 5 menit; kehilangan sinyal > 24 jam = pelanggaran. §8.2 Starlink: koneksi wajib aktif untuk telemetry; gangguan > 24 jam wajib dilaporkan. §8.3 Sanksi: potongan maks. 5% nilai invoice trip terkait + hak penghentian charter.	AKTIF	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
5	CC-2026-005	P-BHL	SL09	2026-01-01	2026-12-31	PER_TRIP	PER_TRIP_BAP	§9.1 GPS/AIS: transponder AIS wajib aktif sepanjang operasi (interval maks. 5 menit). §9.2 Starlink: koneksi wajib aktif; gangguan > 24 jam wajib dilaporkan ke dispatcher. §9.3 Sanksi: potongan maks. 2,5% nilai invoice trip terkait.	AKTIF	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
7	CC-2026-007	P-MLT	M03	2026-01-01	2026-12-31	TC	BULANAN	§12.1 GPS/AIS: unit TC wajib melapor posisi otomatis via AIS (interval maks. 5 menit). §12.2 Starlink: koneksi wajib aktif untuk laporan harian; gangguan > 24 jam wajib dilaporkan. §12.3 Sanksi: potongan maks. 5% tagihan bulanan TC terkait.	AKTIF	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
8	CC-2026-008	P-DLM	B07	2026-06-01	2026-12-31	PER_M3	PER_TRIP_BAP	§6.1 GPS/AIS: transponder AIS wajib aktif sepanjang operasi (interval maks. 5 menit). §6.2 Starlink: koneksi wajib aktif untuk telemetry & BAP digital; gangguan > 24 jam wajib dilaporkan. §6.3 Sanksi: potongan maks. 5% nilai invoice trip terkait.	AKTIF	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
\.


--
-- Data for Name: info; Type: TABLE DATA; Schema: partner; Owner: -
--

COPY partner.info (partner_code, partner_name, partner_type, contact, created_at) FROM stdin;
P-SMI	PT Samudra Mitra	CHARTER	ops@samudramitra.co.id	2026-09-11 04:37:38.232279+00
P-BHL	PT Bahari Lines	CHARTER	ops@baharilines.co.id	2026-09-11 04:37:38.232279+00
P-MLT	PT Mulya Trans	CHARTER_TC	finance@mulyatrans.co.id	2026-09-11 04:37:38.232279+00
P-DLM	PT Delta Marine	LAB_ENVIRO	lab@deltamarine.co.id	2026-09-11 04:37:38.232279+00
\.


--
-- Data for Name: invoice; Type: TABLE DATA; Schema: partner; Owner: -
--

COPY partner.invoice (partner_invoice_id, partner_code, charter_contract_id, invoice_no, received_at, claimed_amount, matching_result, diff_note, matched_by, matched_at, tenant_id, created_at, updated_at) FROM stdin;
89	P-SMI	4	INV-P-2026-089	2026-09-07	63000000.00	MATCH	\N	finance	2026-09-07 09:00:00+00	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
91	P-MLT	7	INV-P-2026-091	2026-09-07	869550000.00	DIFF	TC Sep 2026: klaim +2,3% di atas hitungan sistem (Rp 850.000.000) — klarifikasi dulu, bayar yang cocok (FR-06-04)	\N	\N	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
92	P-BHL	5	INV-P-2026-093	2026-09-08	38000000.00	MATCH	\N	finance	2026-09-09 03:00:00+00	\N	2026-09-11 04:37:38.492939+00	2026-09-11 04:37:38.492939+00
\.


--
-- Data for Name: payment; Type: TABLE DATA; Schema: partner; Owner: -
--

COPY partner.payment (payment_id, partner_code, paid_at, amount, method, approved_by, tenant_id, created_at, updated_at) FROM stdin;
1	P-SMI	2026-09-07	63000000.00	TRANSFER	finance	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
\.


--
-- Data for Name: payment_allocation; Type: TABLE DATA; Schema: partner; Owner: -
--

COPY partner.payment_allocation (payment_allocation_id, payment_id, statement_line_id, amount) FROM stdin;
1	1	259	63000000.00
\.


--
-- Data for Name: rate_card; Type: TABLE DATA; Schema: partner; Owner: -
--

COPY partner.rate_card (rate_card_id, charter_contract_id, rate_per_m3, rate_per_trip, tc_monthly_fee, effective_from, tenant_id, created_at, updated_at) FROM stdin;
5	5	\N	38000000.00	\N	2026-01-01	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
8	8	11500.0000	\N	\N	2026-06-01	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
4	4	12000.0000	\N	\N	2026-01-01	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
3	3	12000.0000	\N	\N	2026-01-01	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
7	7	\N	\N	850000000.00	2026-01-01	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
\.


--
-- Data for Name: statement_line; Type: TABLE DATA; Schema: partner; Owner: -
--

COPY partner.statement_line (statement_line_id, trip_id, charter_contract_id, rate_card_id, scheme, volume_basis_m3, rate, amount, payable_status, trigger_event, triggered_at, tenant_id, created_at, updated_at) FROM stdin;
259	899	4	4	PER_M3	5250.000	12000.0000	63000000.00	PAID	PO_COMPLETED	2026-09-03 02:00:00+00	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
260	903	5	5	PER_TRIP	4982.558	38000000.0000	38000000.00	TRIGGERED	DEPOSIT_DEDUCTED	2026-09-04 01:00:00+00	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
261	907	3	3	PER_M3	5371.800	12000.0000	64461600.00	TRIGGERED	DEPOSIT_DEDUCTED	2026-09-07 07:36:00+00	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
262	910	4	4	PER_M3	3950.000	12000.0000	47400000.00	TRIGGERED	DEPOSIT_DEDUCTED	2026-09-09 19:16:00+00	\N	2026-09-11 04:37:38.489882+00	2026-09-11 04:37:38.489882+00
\.


--
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text) FROM stdin;
\.


--
-- Data for Name: info; Type: TABLE DATA; Schema: site; Owner: -
--

COPY site.info (site_code, site_name, owner_buyer_code, location, polygon) FROM stdin;
MARINA-JAYA	Marina Jaya	B-WKR	0101000020E6100000CDCCCCCCCC8C5A403333333333B317C0	\N
SITE-G	Reklamasi G (Dumping Site)	B-PRN	0101000020E6100000D7A3703D0A975A40E17A14AE47E117C0	0103000020E61000000100000005000000AE47E17A14965A40D7A3703D0AD717C0D578E92631985A40A245B6F3FDD417C0B81E85EB51985A4021B0726891ED17C091ED7C3F35965A40560E2DB29DEF17C0AE47E17A14965A40D7A3703D0AD717C0
ETAP-2	Reklamasi Etap 2	B-PRN	0101000020E6100000E17A14AE47995A407B14AE47E1FA17C0	0103000020E610000001000000050000009CC420B072985A40713D0AD7A3F017C00AD7A3703D9A5A403BDF4F8D97EE17C0EE7C3F355E9A5A40BA490C022B0718C07F6ABC7493985A40F0A7C64B370918C09CC420B072985A40713D0AD7A3F017C0
SITE-JRG	Reclamation Area Jurong — Singapura	B-XPD	0101000020E6100000AE47E17A14EE5940A4703D0AD7A3F43F	\N
\.


--
-- Data for Name: draft_survey; Type: TABLE DATA; Schema: survey; Owner: -
--

COPY survey.draft_survey (draft_survey_id, trip_id, tipe, surveyor_name, surveyor_company, surveyor_license, surveyed_at, draft_readings, soundings, water_density, material_density, displacement_t, corrections_t, tonnage_t, volume_m3, witnesses, signed_at, doc_ref, is_locked, tenant_id, created_at, updated_at) FROM stdin;
1	899	MUAT	Budi Santoso	PT Surveyor Laut Nusantara	SLN-0451	2026-09-01 07:00:00+00	{"titik": [{"m": 4.50, "sumber": "DEPAN-KIRI"}, {"m": 4.48, "sumber": "DEPAN-KANAN"}, {"m": 4.52, "sumber": "TENGAH-KIRI"}, {"m": 4.51, "sumber": "TENGAH-KANAN"}, {"m": 4.49, "sumber": "BELAKANG-KIRI"}, {"m": 4.50, "sumber": "BELAKANG-KANAN"}]}	\N	1.02460	2.65000	13801.250	-15.750	13785.500	5250.000	{"buyer": "Ir. Rahmat", "kapal": "H. Andi"}	2026-09-01 07:40:00+00	101	t	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
2	903	MUAT	Budi Santoso	PT Surveyor Laut Nusantara	SLN-0451	2026-09-03 00:30:00+00	{"titik": [{"m": 4.41, "sumber": "DEPAN-KIRI"}, {"m": 4.40, "sumber": "DEPAN-KANAN"}, {"m": 4.43, "sumber": "TENGAH-KIRI"}, {"m": 4.42, "sumber": "TENGAH-KANAN"}, {"m": 4.40, "sumber": "BELAKANG-KIRI"}, {"m": 4.41, "sumber": "BELAKANG-KANAN"}]}	\N	1.02480	2.65000	13154.800	-12.400	13142.400	5001.120	{"buyer": "Ir. Rahmat", "kapal": "Capt. Dedi"}	2026-09-03 01:10:00+00	103	t	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
3	907	MUAT	Budi Santoso	PT Surveyor Laut Nusantara	SLN-0451	2026-09-05 21:00:00+00	{"titik": [{"m": 4.62, "sumber": "DEPAN-KIRI"}, {"m": 4.61, "sumber": "DEPAN-KANAN"}, {"m": 4.63, "sumber": "TENGAH-KIRI"}, {"m": 4.63, "sumber": "TENGAH-KANAN"}, {"m": 4.60, "sumber": "BELAKANG-KIRI"}, {"m": 4.61, "sumber": "BELAKANG-KANAN"}]}	\N	1.02470	2.65000	14250.300	-18.400	14231.900	5420.500	{"buyer": "Ir. Rahmat", "kapal": "H. Bakti"}	2026-09-05 21:45:00+00	111	t	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
4	907	AWAL_BONGKAR	Budi Santoso	PT Surveyor Laut Nusantara	SLN-0451	2026-09-06 19:30:00+00	{"titik": [{"m": 4.59, "sumber": "DEPAN-KIRI"}, {"m": 4.58, "sumber": "DEPAN-KANAN"}, {"m": 4.60, "sumber": "TENGAH-KIRI"}, {"m": 4.60, "sumber": "TENGAH-KANAN"}, {"m": 4.57, "sumber": "BELAKANG-KIRI"}, {"m": 4.58, "sumber": "BELAKANG-KANAN"}]}	\N	1.02150	2.65000	14190.600	-17.200	14173.400	5398.200	{"buyer": "Ir. Rahmat", "kapal": "H. Bakti"}	2026-09-06 20:10:00+00	112	t	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
5	907	AKHIR_BONGKAR	Budi Santoso	PT Surveyor Laut Nusantara	SLN-0451	2026-09-07 06:20:00+00	{"titik": [{"m": 3.02, "sumber": "DEPAN-KIRI"}, {"m": 3.01, "sumber": "DEPAN-KANAN"}, {"m": 3.03, "sumber": "TENGAH-KIRI"}, {"m": 3.02, "sumber": "TENGAH-KANAN"}, {"m": 3.00, "sumber": "BELAKANG-KIRI"}, {"m": 3.01, "sumber": "BELAKANG-KANAN"}]}	\N	1.02150	2.65000	69.500	-0.300	69.200	26.400	{"buyer": "Ir. Rahmat", "kapal": "H. Bakti"}	2026-09-07 06:45:00+00	113	t	\N	2026-09-11 04:37:38.232279+00	2026-09-11 04:37:38.232279+00
6	910	MUAT	Budi Santoso	PT Surveyor Laut Nusantara	SLN-0451	2026-09-08 02:00:00+00	{"titik": [{"m": 4.44, "sumber": "DEPAN-KIRI"}, {"m": 4.43, "sumber": "DEPAN-KANAN"}, {"m": 4.45, "sumber": "TENGAH-KIRI"}, {"m": 4.44, "sumber": "TENGAH-KANAN"}, {"m": 4.42, "sumber": "BELAKANG-KIRI"}, {"m": 4.43, "sumber": "BELAKANG-KANAN"}]}	\N	1.02470	2.65000	10498.600	-11.200	10487.400	4000.000	{"buyer": "Ir. Sinta Wijaya", "kapal": "H. Andi"}	2026-09-08 02:40:00+00	\N	t	\N	2026-09-11 04:37:38.479597+00	2026-09-11 04:37:38.479597+00
7	910	AWAL_BONGKAR	Budi Santoso	PT Surveyor Laut Nusantara	SLN-0451	2026-09-09 13:30:00+00	{"titik": [{"m": 3.52, "sumber": "DEPAN-KIRI"}, {"m": 3.51, "sumber": "DEPAN-KANAN"}, {"m": 3.53, "sumber": "TENGAH-KIRI"}, {"m": 3.52, "sumber": "TENGAH-KANAN"}, {"m": 3.50, "sumber": "BELAKANG-KIRI"}, {"m": 3.51, "sumber": "BELAKANG-KANAN"}]}	\N	1.02500	2.65000	10421.300	-9.900	10411.400	3970.000	{"buyer": "Ir. Sinta Wijaya", "kapal": "H. Andi"}	2026-09-09 14:10:00+00	\N	t	\N	2026-09-11 04:37:38.479597+00	2026-09-11 04:37:38.479597+00
8	910	AKHIR_BONGKAR	Budi Santoso	PT Surveyor Laut Nusantara	SLN-0451	2026-09-09 18:30:00+00	{"titik": [{"m": 0.10, "sumber": "DEPAN-KIRI"}, {"m": 0.09, "sumber": "DEPAN-KANAN"}, {"m": 0.11, "sumber": "TENGAH-KIRI"}, {"m": 0.10, "sumber": "TENGAH-KANAN"}, {"m": 0.08, "sumber": "BELAKANG-KIRI"}, {"m": 0.09, "sumber": "BELAKANG-KANAN"}]}	\N	1.02500	2.65000	52.700	-0.500	52.200	20.000	{"buyer": "Ir. Sinta Wijaya", "kapal": "H. Andi"}	2026-09-09 18:50:00+00	\N	t	\N	2026-09-11 04:37:38.479597+00	2026-09-11 04:37:38.479597+00
\.


--
-- Data for Name: instrument; Type: TABLE DATA; Schema: survey; Owner: -
--

COPY survey.instrument (instrument_code, nama, tipe, status, cert_no, issuer, issued_at, expires_at, created_at, updated_at) FROM stdin;
EC-01	Echosounder Singlebeam Hi-Target	ECHOSOUNDER	AKTIF	KAL-EC-2026-014	Balai Uji Terakreditasi	2026-02-10	2027-02-10	2026-09-21 07:18:37.45904+00	2026-09-21 07:18:37.45904+00
GP-01	GPS RTK Geodetik	GPS	AKTIF	KAL-GP-2026-021	Badan Geodesi Nasional	2026-03-01	2027-03-01	2026-09-21 07:18:37.45904+00	2026-09-21 07:18:37.45904+00
SN-01	Sonde Kualitas Air Multiparameter	SONDE	AKTIF	KAL-SN-2026-008	Laboratorium Kalibrasi Instrumentasi	2026-01-20	2027-01-20	2026-09-21 07:18:37.45904+00	2026-09-21 07:18:37.45904+00
\.


--
-- Data for Name: mission; Type: TABLE DATA; Schema: survey; Owner: -
--

COPY survey.mission (mission_id, mission_no, fleet_code, mission_kind, target_type, target_code, lat, lng, purpose, planned_start, planned_end, ts_departed, ts_returned, engine_hours, status, leader_name, crew, mon_wo_id, is_locked, tenant_id, created_at, updated_at, source, schedule_id, incident_id) FROM stdin;
\.


--
-- Data for Name: mission_check; Type: TABLE DATA; Schema: survey; Owner: -
--

COPY survey.mission_check (check_id, mission_id, item_key, status, catatan, verified_by, verified_at, created_at) FROM stdin;
\.


--
-- Data for Name: mission_cost; Type: TABLE DATA; Schema: survey; Owner: -
--

COPY survey.mission_cost (cost_id, mission_id, category, amount, qty_liter, engine_meter, source, description, created_by, created_at) FROM stdin;
\.


--
-- Data for Name: mission_log; Type: TABLE DATA; Schema: survey; Owner: -
--

COPY survey.mission_log (log_id, mission_id, logged_at, log_type, payload, created_by, created_at) FROM stdin;
\.


--
-- Data for Name: mission_result; Type: TABLE DATA; Schema: survey; Owner: -
--

COPY survey.mission_result (result_id, mission_id, kind, summary, station_code, doc_ref, instrument_code, created_by, created_at) FROM stdin;
\.


--
-- Data for Name: ais_position; Type: TABLE DATA; Schema: telemetry; Owner: -
--

COPY telemetry.ais_position (position_id, fleet_code, mmsi, lat, lng, speed_kn, course_deg, position_at) FROM stdin;
2	SL05	\N	-5.73	106.16	9.60	94.0	2026-09-07 07:30:00+00
1	SL02	\N	-5.97	106.36	0.00	0.0	2026-09-07 07:30:00+00
3	B12	\N	-5.925	106.2	0.00	0.0	2026-09-07 07:30:00+00
4	B12	\N	-5.9	106.245	0.00	92.0	2026-09-07 07:40:00+00
5	M03		-5.8325	105.953	0.40	90.0	2026-09-07 08:30:00+00
\.


--
-- Data for Name: geofence; Type: TABLE DATA; Schema: telemetry; Owner: -
--

COPY telemetry.geofence (geofence_id, fence_code, fence_name, fence_type, geom, radius_m) FROM stdin;
2	F-SITEG	Polygon Site G	SITE_BONGKAR	0103000020E61000000100000005000000AE47E17A14965A40D7A3703D0AD717C0D578E92631985A40A245B6F3FDD417C0B81E85EB51985A4021B0726891ED17C091ED7C3F35965A40560E2DB29DEF17C0AE47E17A14965A40D7A3703D0AD717C0	\N
3	F-ETAP2	Polygon Etap 2	SITE_BONGKAR	0103000020E610000001000000050000009CC420B072985A40713D0AD7A3F017C00AD7A3703D9A5A403BDF4F8D97EE17C0EE7C3F355E9A5A40BA490C022B0718C07F6ABC7493985A40F0A7C64B370918C09CC420B072985A40713D0AD7A3F017C0	\N
5	F-MARJAYA	Zona Dok Marina Jaya	DOK	0103000020E6100000010000000500000079E92631088C5A4008AC1C5A64BB17C079E92631088C5A405EBA490C02AB17C021B07268918D5A405EBA490C02AB17C021B07268918D5A4008AC1C5A64BB17C079E92631088C5A4008AC1C5A64BB17C0	\N
1	F-B04	Polygon Blok B-04	PENGERUKAN	0103000020E61000000100000005000000EC51B81E857B5A4048E17A14AE4717C066666666667E5A401283C0CAA14517C03BDF4F8D977E5A40E17A14AE476117C0C1CAA145B67B5A4017D9CEF7536317C0EC51B81E857B5A4048E17A14AE4717C0	\N
4	F-B07	Polygon Blok B-07	PENGERUKAN	0103000020E6100000010000001900000048E17A14AE875A407B14AE47E17A17C0CDCCCCCCCC7C5A40F6285C8FC27517C03762C711A47C5A40F332D2E4AA6217C0B5A3548D977E5A40CCC5C8B4476117C062566A8D977E5A40C87695B4476117C059EE7E8D977E5A4008AE1CB4476117C09E8F918D977E5A40CC7563B3476117C02F73A18D977E5A40A18871B2476117C051EFAD8D977E5A40D9FE50B1476117C0A67EB68D977E5A40ADE20DB0476117C0BEC5BA8D977E5A40A6AFB5AE476117C0E696BA8D977E5A4095C256AD476117C0111ED166667E5A40C6CA02CAA14517C0D004CD66667E5A4015E7C6C8A14517C01B4DC566667E5A4013D89CC7A14517C0A03CBA66667E5A40A4208FC6A14517C04237AC66667E5A40CF43A7C5A14517C097BB9B66667E5A40D96EEDC4A14517C06D5E8966667E5A40772F68C4A14517C090C57566667E5A40A1381CC4A14517C0ECA16166667E5A4027380CC4A14517C04195FF24697C5A40081F2AE70B4717C05C8FC2F5287C5A40295C8FC2F52817C0D7A3703D0A875A40AE47E17A142E17C048E17A14AE875A407B14AE47E17A17C0	\N
\.


--
-- Data for Name: geofence_event; Type: TABLE DATA; Schema: telemetry; Owner: -
--

COPY telemetry.geofence_event (event_id, fleet_code, geofence_id, event, event_at) FROM stdin;
1	SL05	2	EXIT	2026-09-07 07:32:00+00
2	SL02	2	ENTRY	2026-09-06 19:00:00+00
3	B12	5	EXIT	2026-09-07 07:35:00+00
4	M03	5	ENTRY	2026-09-06 11:20:00+00
5	LI02	5	ENTRY	2026-09-06 10:05:00+00
6	B12	5	ENTRY	2026-09-04 16:00:00+00
7	B07	5	ENTRY	2026-09-05 08:40:00+00
8	SL07	5	ENTRY	2026-09-05 09:10:00+00
\.


--
-- Data for Name: vessel_device; Type: TABLE DATA; Schema: telemetry; Owner: -
--

COPY telemetry.vessel_device (device_id, fleet_code, device_type, serial_no, installed_at, last_ping_at, status, catatan) FROM stdin;
13	LI02	AIS	AIS-LI02-236360	2026-03-03	\N	MAINTENANCE	\N
1	SL02	AIS	AIS-SL02-236194	2025-11-04	2026-09-21 01:37:37.712888+00	ONLINE	\N
2	SL02	STARLINK	STX-SL02-7781	2025-11-04	2026-09-21 01:41:37.712888+00	ONLINE	\N
3	SL05	AIS	AIS-SL05-236210	2025-12-18	2026-09-21 01:28:37.712888+00	ONLINE	\N
4	SL05	STARLINK	STX-SL05-7812	2025-12-18	2026-09-18 01:45:37.712888+00	OFFLINE	\N
5	SL09	AIS	AIS-SL09-236241	2026-01-22	2026-09-19 23:45:37.712888+00	ONLINE	\N
6	SL09	STARLINK	STX-SL09-7844	2026-01-22	2026-09-21 01:34:37.712888+00	ONLINE	\N
7	M03	AIS	AIS-M03-236288	2025-10-09	2026-09-21 01:24:37.712888+00	ONLINE	\N
8	M03	STARLINK	STX-M03-7860	2025-10-09	2026-09-21 01:36:37.712888+00	ONLINE	\N
9	B07	AIS	AIS-B07-236301	2026-05-27	2026-09-21 01:31:37.712888+00	ONLINE	\N
10	B07	STARLINK	STX-B07-7877	2026-05-27	2026-09-21 01:39:37.712888+00	ONLINE	\N
11	B12	AIS	AIS-B12-236333	2026-02-14	2026-09-19 01:45:37.712888+00	ONLINE	\N
12	SL07	AIS	AIS-SL07-236352	2026-03-03	2026-09-21 01:14:37.712888+00	ONLINE	\N
\.


--
-- Data for Name: voyage; Type: TABLE DATA; Schema: voyage; Owner: -
--

COPY voyage.voyage (voyage_id, fleet_code, trip_ref, lat, lng, speed_kn, heading_deg, recorded_at) FROM stdin;
2	SL02	TRP-2026-0907	-5.86	106.02	9.30	97.0	2026-09-06 13:00:00+00
5	SL02	TRP-2026-0907	-5.96	106.3	9.60	94.0	2026-09-06 18:00:00+00
6	SL02	TRP-2026-0907	-5.97	106.36	4.20	92.0	2026-09-06 19:00:00+00
4	SL02	TRP-2026-0907	-5.93	106.22	9.60	95.0	2026-09-06 17:00:00+00
1	SL02	TRP-2026-0907	-5.83	105.95	9.10	95.0	2026-09-06 11:00:00+00
3	SL02	TRP-2026-0907	-5.9	106.12	9.50	96.0	2026-09-06 15:00:00+00
\.


--
-- Name: deposit_deposit_id_seq; Type: SEQUENCE SET; Schema: buyer; Owner: -
--

SELECT pg_catalog.setval('buyer.deposit_deposit_id_seq', 1, false);


--
-- Name: deposit_transaction_dep_trans_id_seq; Type: SEQUENCE SET; Schema: buyer; Owner: -
--

SELECT pg_catalog.setval('buyer.deposit_transaction_dep_trans_id_seq', 1, false);


--
-- Name: ledger_hist_id_seq; Type: SEQUENCE SET; Schema: buyer; Owner: -
--

SELECT pg_catalog.setval('buyer.ledger_hist_id_seq', 1, false);


--
-- Name: site_buyer_site_id_seq; Type: SEQUENCE SET; Schema: buyer; Owner: -
--

SELECT pg_catalog.setval('buyer.site_buyer_site_id_seq', 3, true);


--
-- Name: bap_bap_id_seq; Type: SEQUENCE SET; Schema: commercial; Owner: -
--

SELECT pg_catalog.setval('commercial.bap_bap_id_seq', 1, false);


--
-- Name: bap_correction_bap_correction_id_seq; Type: SEQUENCE SET; Schema: commercial; Owner: -
--

SELECT pg_catalog.setval('commercial.bap_correction_bap_correction_id_seq', 1, false);


--
-- Name: bap_objection_bap_objection_id_seq; Type: SEQUENCE SET; Schema: commercial; Owner: -
--

SELECT pg_catalog.setval('commercial.bap_objection_bap_objection_id_seq', 1, true);


--
-- Name: delivery_order_do_id_seq; Type: SEQUENCE SET; Schema: commercial; Owner: -
--

SELECT pg_catalog.setval('commercial.delivery_order_do_id_seq', 355, true);


--
-- Name: purchase_order_po_id_seq; Type: SEQUENCE SET; Schema: commercial; Owner: -
--

SELECT pg_catalog.setval('commercial.purchase_order_po_id_seq', 1, false);


--
-- Name: sales_contract_sales_contract_id_seq; Type: SEQUENCE SET; Schema: commercial; Owner: -
--

SELECT pg_catalog.setval('commercial.sales_contract_sales_contract_id_seq', 1, false);


--
-- Name: sand_spec_sand_spec_id_seq; Type: SEQUENCE SET; Schema: commercial; Owner: -
--

SELECT pg_catalog.setval('commercial.sand_spec_sand_spec_id_seq', 1, false);


--
-- Name: standby_claim_standby_claim_id_seq; Type: SEQUENCE SET; Schema: commercial; Owner: -
--

SELECT pg_catalog.setval('commercial.standby_claim_standby_claim_id_seq', 1, false);


--
-- Name: doc_verification_verification_id_seq; Type: SEQUENCE SET; Schema: document; Owner: -
--

SELECT pg_catalog.setval('document.doc_verification_verification_id_seq', 1, false);


--
-- Name: document_document_id_seq; Type: SEQUENCE SET; Schema: document; Owner: -
--

SELECT pg_catalog.setval('document.document_document_id_seq', 1, false);


--
-- Name: form_foto_foto_id_seq; Type: SEQUENCE SET; Schema: document; Owner: -
--

SELECT pg_catalog.setval('document.form_foto_foto_id_seq', 1, false);


--
-- Name: ews_event_ews_event_id_seq; Type: SEQUENCE SET; Schema: enviro; Owner: -
--

SELECT pg_catalog.setval('enviro.ews_event_ews_event_id_seq', 4, true);


--
-- Name: mon_report_mon_report_id_seq; Type: SEQUENCE SET; Schema: enviro; Owner: -
--

SELECT pg_catalog.setval('enviro.mon_report_mon_report_id_seq', 1, false);


--
-- Name: mon_schedule_schedule_id_seq; Type: SEQUENCE SET; Schema: enviro; Owner: -
--

SELECT pg_catalog.setval('enviro.mon_schedule_schedule_id_seq', 1, false);


--
-- Name: mon_work_order_wo_id_seq; Type: SEQUENCE SET; Schema: enviro; Owner: -
--

SELECT pg_catalog.setval('enviro.mon_work_order_wo_id_seq', 1, false);


--
-- Name: reading_detail_reading_detail_id_seq; Type: SEQUENCE SET; Schema: enviro; Owner: -
--

SELECT pg_catalog.setval('enviro.reading_detail_reading_detail_id_seq', 117, true);


--
-- Name: remediation_remediation_id_seq; Type: SEQUENCE SET; Schema: enviro; Owner: -
--

SELECT pg_catalog.setval('enviro.remediation_remediation_id_seq', 1, false);


--
-- Name: cost_entry_cost_entry_id_seq; Type: SEQUENCE SET; Schema: financial; Owner: -
--

SELECT pg_catalog.setval('financial.cost_entry_cost_entry_id_seq', 1, false);


--
-- Name: invoice_invoice_id_seq; Type: SEQUENCE SET; Schema: financial; Owner: -
--

SELECT pg_catalog.setval('financial.invoice_invoice_id_seq', 1, false);


--
-- Name: journal_journal_id_seq; Type: SEQUENCE SET; Schema: financial; Owner: -
--

SELECT pg_catalog.setval('financial.journal_journal_id_seq', 1, false);


--
-- Name: journal_line_journal_line_id_seq; Type: SEQUENCE SET; Schema: financial; Owner: -
--

SELECT pg_catalog.setval('financial.journal_line_journal_line_id_seq', 22, true);


--
-- Name: pnbp_charge_pnbp_charge_id_seq; Type: SEQUENCE SET; Schema: financial; Owner: -
--

SELECT pg_catalog.setval('financial.pnbp_charge_pnbp_charge_id_seq', 1, false);


--
-- Name: pnbp_kode_map_map_id_seq; Type: SEQUENCE SET; Schema: financial; Owner: -
--

SELECT pg_catalog.setval('financial.pnbp_kode_map_map_id_seq', 3, true);


--
-- Name: pnbp_tahap_awal_tahap_id_seq; Type: SEQUENCE SET; Schema: financial; Owner: -
--

SELECT pg_catalog.setval('financial.pnbp_tahap_awal_tahap_id_seq', 2, true);


--
-- Name: pnbp_tarif_tarif_id_seq; Type: SEQUENCE SET; Schema: financial; Owner: -
--

SELECT pg_catalog.setval('financial.pnbp_tarif_tarif_id_seq', 3, true);


--
-- Name: vessel_maintenance_maintenance_id_seq; Type: SEQUENCE SET; Schema: fleet; Owner: -
--

SELECT pg_catalog.setval('fleet.vessel_maintenance_maintenance_id_seq', 3, true);


--
-- Name: capa_capa_id_seq; Type: SEQUENCE SET; Schema: hse; Owner: -
--

SELECT pg_catalog.setval('hse.capa_capa_id_seq', 3, true);


--
-- Name: certificate_certificate_id_seq; Type: SEQUENCE SET; Schema: hse; Owner: -
--

SELECT pg_catalog.setval('hse.certificate_certificate_id_seq', 16, true);


--
-- Name: incident_incident_id_seq; Type: SEQUENCE SET; Schema: hse; Owner: -
--

SELECT pg_catalog.setval('hse.incident_incident_id_seq', 4, true);


--
-- Name: induction_induction_id_seq; Type: SEQUENCE SET; Schema: hse; Owner: -
--

SELECT pg_catalog.setval('hse.induction_induction_id_seq', 6, true);


--
-- Name: inspection_inspection_id_seq; Type: SEQUENCE SET; Schema: hse; Owner: -
--

SELECT pg_catalog.setval('hse.inspection_inspection_id_seq', 20, true);


--
-- Name: toolbox_meeting_ttm_id_seq; Type: SEQUENCE SET; Schema: hse; Owner: -
--

SELECT pg_catalog.setval('hse.toolbox_meeting_ttm_id_seq', 24, true);


--
-- Name: email_outbox_outbox_id_seq; Type: SEQUENCE SET; Schema: notification; Owner: -
--

SELECT pg_catalog.setval('notification.email_outbox_outbox_id_seq', 3, true);


--
-- Name: log_notif_id_seq; Type: SEQUENCE SET; Schema: notification; Owner: -
--

SELECT pg_catalog.setval('notification.log_notif_id_seq', 12, true);


--
-- Name: notif_inapp_inapp_id_seq; Type: SEQUENCE SET; Schema: notification; Owner: -
--

SELECT pg_catalog.setval('notification.notif_inapp_inapp_id_seq', 1, false);


--
-- Name: notif_outbox_outbox_id_seq; Type: SEQUENCE SET; Schema: notification; Owner: -
--

SELECT pg_catalog.setval('notification.notif_outbox_outbox_id_seq', 1, false);


--
-- Name: notif_penerima_penerima_id_seq; Type: SEQUENCE SET; Schema: notification; Owner: -
--

SELECT pg_catalog.setval('notification.notif_penerima_penerima_id_seq', 2, true);


--
-- Name: report_schedule_schedule_id_seq; Type: SEQUENCE SET; Schema: notification; Owner: -
--

SELECT pg_catalog.setval('notification.report_schedule_schedule_id_seq', 1, true);


--
-- Name: rule_rule_id_seq; Type: SEQUENCE SET; Schema: notification; Owner: -
--

SELECT pg_catalog.setval('notification.rule_rule_id_seq', 7, true);


--
-- Name: doc_approval_approval_id_seq; Type: SEQUENCE SET; Schema: operational; Owner: -
--

SELECT pg_catalog.setval('operational.doc_approval_approval_id_seq', 1, false);


--
-- Name: line_compliance_compliance_id_seq; Type: SEQUENCE SET; Schema: operational; Owner: -
--

SELECT pg_catalog.setval('operational.line_compliance_compliance_id_seq', 1, false);


--
-- Name: schedule_plan_plan_id_seq; Type: SEQUENCE SET; Schema: operational; Owner: -
--

SELECT pg_catalog.setval('operational.schedule_plan_plan_id_seq', 4, true);


--
-- Name: schedule_proposal_proposal_id_seq; Type: SEQUENCE SET; Schema: operational; Owner: -
--

SELECT pg_catalog.setval('operational.schedule_proposal_proposal_id_seq', 2, true);


--
-- Name: shipment_instruction_si_id_seq; Type: SEQUENCE SET; Schema: operational; Owner: -
--

SELECT pg_catalog.setval('operational.shipment_instruction_si_id_seq', 912, true);


--
-- Name: site_contract_site_contract_id_seq; Type: SEQUENCE SET; Schema: operational; Owner: -
--

SELECT pg_catalog.setval('operational.site_contract_site_contract_id_seq', 1, false);


--
-- Name: site_line_line_id_seq; Type: SEQUENCE SET; Schema: operational; Owner: -
--

SELECT pg_catalog.setval('operational.site_line_line_id_seq', 2, true);


--
-- Name: site_permit_site_permit_id_seq; Type: SEQUENCE SET; Schema: operational; Owner: -
--

SELECT pg_catalog.setval('operational.site_permit_site_permit_id_seq', 1, false);


--
-- Name: trip_doc_check_check_id_seq; Type: SEQUENCE SET; Schema: operational; Owner: -
--

SELECT pg_catalog.setval('operational.trip_doc_check_check_id_seq', 1, false);


--
-- Name: trip_trip_id_seq; Type: SEQUENCE SET; Schema: operational; Owner: -
--

SELECT pg_catalog.setval('operational.trip_trip_id_seq', 912, true);


--
-- Name: voyage_doc_doc_id_seq; Type: SEQUENCE SET; Schema: operational; Owner: -
--

SELECT pg_catalog.setval('operational.voyage_doc_doc_id_seq', 1, false);


--
-- Name: voyage_plan_plan_id_seq; Type: SEQUENCE SET; Schema: operational; Owner: -
--

SELECT pg_catalog.setval('operational.voyage_plan_plan_id_seq', 1, false);


--
-- Name: audit_log_audit_id_seq; Type: SEQUENCE SET; Schema: param; Owner: -
--

SELECT pg_catalog.setval('param.audit_log_audit_id_seq', 2, true);


--
-- Name: charter_contract_charter_contract_id_seq; Type: SEQUENCE SET; Schema: partner; Owner: -
--

SELECT pg_catalog.setval('partner.charter_contract_charter_contract_id_seq', 1, false);


--
-- Name: invoice_partner_invoice_id_seq; Type: SEQUENCE SET; Schema: partner; Owner: -
--

SELECT pg_catalog.setval('partner.invoice_partner_invoice_id_seq', 1, false);


--
-- Name: payment_allocation_payment_allocation_id_seq; Type: SEQUENCE SET; Schema: partner; Owner: -
--

SELECT pg_catalog.setval('partner.payment_allocation_payment_allocation_id_seq', 1, false);


--
-- Name: payment_payment_id_seq; Type: SEQUENCE SET; Schema: partner; Owner: -
--

SELECT pg_catalog.setval('partner.payment_payment_id_seq', 1, false);


--
-- Name: rate_card_rate_card_id_seq; Type: SEQUENCE SET; Schema: partner; Owner: -
--

SELECT pg_catalog.setval('partner.rate_card_rate_card_id_seq', 1, false);


--
-- Name: statement_line_statement_line_id_seq; Type: SEQUENCE SET; Schema: partner; Owner: -
--

SELECT pg_catalog.setval('partner.statement_line_statement_line_id_seq', 1, false);


--
-- Name: draft_survey_draft_survey_id_seq; Type: SEQUENCE SET; Schema: survey; Owner: -
--

SELECT pg_catalog.setval('survey.draft_survey_draft_survey_id_seq', 9, true);


--
-- Name: mission_check_check_id_seq; Type: SEQUENCE SET; Schema: survey; Owner: -
--

SELECT pg_catalog.setval('survey.mission_check_check_id_seq', 1, false);


--
-- Name: mission_cost_cost_id_seq; Type: SEQUENCE SET; Schema: survey; Owner: -
--

SELECT pg_catalog.setval('survey.mission_cost_cost_id_seq', 1, false);


--
-- Name: mission_log_log_id_seq; Type: SEQUENCE SET; Schema: survey; Owner: -
--

SELECT pg_catalog.setval('survey.mission_log_log_id_seq', 1, false);


--
-- Name: mission_mission_id_seq; Type: SEQUENCE SET; Schema: survey; Owner: -
--

SELECT pg_catalog.setval('survey.mission_mission_id_seq', 1, false);


--
-- Name: mission_result_result_id_seq; Type: SEQUENCE SET; Schema: survey; Owner: -
--

SELECT pg_catalog.setval('survey.mission_result_result_id_seq', 1, false);


--
-- Name: ais_position_position_id_seq; Type: SEQUENCE SET; Schema: telemetry; Owner: -
--

SELECT pg_catalog.setval('telemetry.ais_position_position_id_seq', 5, true);


--
-- Name: geofence_event_event_id_seq; Type: SEQUENCE SET; Schema: telemetry; Owner: -
--

SELECT pg_catalog.setval('telemetry.geofence_event_event_id_seq', 8, true);


--
-- Name: geofence_geofence_id_seq; Type: SEQUENCE SET; Schema: telemetry; Owner: -
--

SELECT pg_catalog.setval('telemetry.geofence_geofence_id_seq', 5, true);


--
-- Name: vessel_device_device_id_seq; Type: SEQUENCE SET; Schema: telemetry; Owner: -
--

SELECT pg_catalog.setval('telemetry.vessel_device_device_id_seq', 13, true);


--
-- Name: voyage_voyage_id_seq; Type: SEQUENCE SET; Schema: voyage; Owner: -
--

SELECT pg_catalog.setval('voyage.voyage_voyage_id_seq', 1, false);


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
-- Name: shipment_monthly shipment_monthly_pk; Type: CONSTRAINT; Schema: commercial; Owner: -
--

ALTER TABLE ONLY commercial.shipment_monthly
    ADD CONSTRAINT shipment_monthly_pk PRIMARY KEY (bulan, buyer_code);


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
-- Name: doc_verification doc_verification_pkey; Type: CONSTRAINT; Schema: document; Owner: -
--

ALTER TABLE ONLY document.doc_verification
    ADD CONSTRAINT doc_verification_pkey PRIMARY KEY (verification_id);


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
-- Name: form_foto form_foto_pkey; Type: CONSTRAINT; Schema: document; Owner: -
--

ALTER TABLE ONLY document.form_foto
    ADD CONSTRAINT form_foto_pkey PRIMARY KEY (foto_id);


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
-- Name: reading_daily reading_daily_pkey; Type: CONSTRAINT; Schema: enviro; Owner: -
--

ALTER TABLE ONLY enviro.reading_daily
    ADD CONSTRAINT reading_daily_pkey PRIMARY KEY (station_code, parameter_code, hari);


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
-- Name: reading reading_pkey; Type: CONSTRAINT; Schema: enviro_raw; Owner: -
--

ALTER TABLE ONLY enviro_raw.reading
    ADD CONSTRAINT reading_pkey PRIMARY KEY (station_code, parameter_code, ts);


--
-- Name: reading_default reading_default_pkey; Type: CONSTRAINT; Schema: enviro_raw; Owner: -
--

ALTER TABLE ONLY enviro_raw.reading_default
    ADD CONSTRAINT reading_default_pkey PRIMARY KEY (station_code, parameter_code, ts);


--
-- Name: reading_p2026_09 reading_p2026_09_pkey; Type: CONSTRAINT; Schema: enviro_raw; Owner: -
--

ALTER TABLE ONLY enviro_raw.reading_p2026_09
    ADD CONSTRAINT reading_p2026_09_pkey PRIMARY KEY (station_code, parameter_code, ts);


--
-- Name: reading_p2026_10 reading_p2026_10_pkey; Type: CONSTRAINT; Schema: enviro_raw; Owner: -
--

ALTER TABLE ONLY enviro_raw.reading_p2026_10
    ADD CONSTRAINT reading_p2026_10_pkey PRIMARY KEY (station_code, parameter_code, ts);


--
-- Name: reading_p2026_11 reading_p2026_11_pkey; Type: CONSTRAINT; Schema: enviro_raw; Owner: -
--

ALTER TABLE ONLY enviro_raw.reading_p2026_11
    ADD CONSTRAINT reading_p2026_11_pkey PRIMARY KEY (station_code, parameter_code, ts);


--
-- Name: sensor_threshold sensor_threshold_pkey; Type: CONSTRAINT; Schema: enviro_raw; Owner: -
--

ALTER TABLE ONLY enviro_raw.sensor_threshold
    ADD CONSTRAINT sensor_threshold_pkey PRIMARY KEY (parameter_code);


--
-- Name: station_token station_token_pkey; Type: CONSTRAINT; Schema: enviro_raw; Owner: -
--

ALTER TABLE ONLY enviro_raw.station_token
    ADD CONSTRAINT station_token_pkey PRIMARY KEY (station_code);


--
-- Name: station_token station_token_token_key; Type: CONSTRAINT; Schema: enviro_raw; Owner: -
--

ALTER TABLE ONLY enviro_raw.station_token
    ADD CONSTRAINT station_token_token_key UNIQUE (token);


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
-- Name: pnbp_kode_map pnbp_kode_map_jenis_key; Type: CONSTRAINT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.pnbp_kode_map
    ADD CONSTRAINT pnbp_kode_map_jenis_key UNIQUE (jenis);


--
-- Name: pnbp_kode_map pnbp_kode_map_pkey; Type: CONSTRAINT; Schema: financial; Owner: -
--

ALTER TABLE ONLY financial.pnbp_kode_map
    ADD CONSTRAINT pnbp_kode_map_pkey PRIMARY KEY (map_id);


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
-- Name: vessel_maintenance vessel_maintenance_pkey; Type: CONSTRAINT; Schema: fleet; Owner: -
--

ALTER TABLE ONLY fleet.vessel_maintenance
    ADD CONSTRAINT vessel_maintenance_pkey PRIMARY KEY (maintenance_id);


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
-- Name: notif_inapp notif_inapp_pkey; Type: CONSTRAINT; Schema: notification; Owner: -
--

ALTER TABLE ONLY notification.notif_inapp
    ADD CONSTRAINT notif_inapp_pkey PRIMARY KEY (inapp_id);


--
-- Name: notif_outbox notif_outbox_pkey; Type: CONSTRAINT; Schema: notification; Owner: -
--

ALTER TABLE ONLY notification.notif_outbox
    ADD CONSTRAINT notif_outbox_pkey PRIMARY KEY (outbox_id);


--
-- Name: notif_penerima notif_penerima_pkey; Type: CONSTRAINT; Schema: notification; Owner: -
--

ALTER TABLE ONLY notification.notif_penerima
    ADD CONSTRAINT notif_penerima_pkey PRIMARY KEY (penerima_id);


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
-- Name: doc_approval doc_approval_pkey; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.doc_approval
    ADD CONSTRAINT doc_approval_pkey PRIMARY KEY (approval_id);


--
-- Name: line_compliance line_compliance_pkey; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.line_compliance
    ADD CONSTRAINT line_compliance_pkey PRIMARY KEY (compliance_id);


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
-- Name: site_contract site_contract_pkey; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.site_contract
    ADD CONSTRAINT site_contract_pkey PRIMARY KEY (site_contract_id);


--
-- Name: site_line site_line_pkey; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.site_line
    ADD CONSTRAINT site_line_pkey PRIMARY KEY (line_id);


--
-- Name: site_permit site_permit_pkey; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.site_permit
    ADD CONSTRAINT site_permit_pkey PRIMARY KEY (site_permit_id);


--
-- Name: trip_doc_check trip_doc_check_pkey; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.trip_doc_check
    ADD CONSTRAINT trip_doc_check_pkey PRIMARY KEY (check_id);


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
-- Name: doc_approval uq_ap_doc_level; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.doc_approval
    ADD CONSTRAINT uq_ap_doc_level UNIQUE (doc_kind, doc_id, level);


--
-- Name: site_contract uq_site_contract; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.site_contract
    ADD CONSTRAINT uq_site_contract UNIQUE (area_code, sales_contract_id, valid_from);


--
-- Name: site_line uq_sl_area_no; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.site_line
    ADD CONSTRAINT uq_sl_area_no UNIQUE (area_code, line_no);


--
-- Name: site_line uq_sl_code; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.site_line
    ADD CONSTRAINT uq_sl_code UNIQUE (line_code);


--
-- Name: voyage_doc uq_vd_no; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.voyage_doc
    ADD CONSTRAINT uq_vd_no UNIQUE (doc_no);


--
-- Name: voyage_doc uq_vd_qr; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.voyage_doc
    ADD CONSTRAINT uq_vd_qr UNIQUE (qr_token);


--
-- Name: voyage_doc uq_vd_trip_type; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.voyage_doc
    ADD CONSTRAINT uq_vd_trip_type UNIQUE (trip_id, doc_type);


--
-- Name: voyage_plan uq_vp_no; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.voyage_plan
    ADD CONSTRAINT uq_vp_no UNIQUE (plan_no);


--
-- Name: voyage_plan uq_vp_qr; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.voyage_plan
    ADD CONSTRAINT uq_vp_qr UNIQUE (qr_token);


--
-- Name: voyage_plan uq_vp_trip; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.voyage_plan
    ADD CONSTRAINT uq_vp_trip UNIQUE (trip_id);


--
-- Name: voyage_doc voyage_doc_pkey; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.voyage_doc
    ADD CONSTRAINT voyage_doc_pkey PRIMARY KEY (doc_id);


--
-- Name: voyage_plan voyage_plan_pkey; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.voyage_plan
    ADD CONSTRAINT voyage_plan_pkey PRIMARY KEY (plan_id);


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
-- Name: work_zone work_zone_pkey; Type: CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.work_zone
    ADD CONSTRAINT work_zone_pkey PRIMARY KEY (zone_code);


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
-- Name: audit_log_arch pk_audit_log_arch; Type: CONSTRAINT; Schema: param; Owner: -
--

ALTER TABLE ONLY param.audit_log_arch
    ADD CONSTRAINT pk_audit_log_arch PRIMARY KEY (audit_id, diarsip_pada);


--
-- Name: doc_code pk_doc_code; Type: CONSTRAINT; Schema: param; Owner: -
--

ALTER TABLE ONLY param.doc_code
    ADD CONSTRAINT pk_doc_code PRIMARY KEY (code_kind, code);


--
-- Name: doc_seq pk_doc_seq; Type: CONSTRAINT; Schema: param; Owner: -
--

ALTER TABLE ONLY param.doc_seq
    ADD CONSTRAINT pk_doc_seq PRIMARY KEY (jenis, scope, thbl);


--
-- Name: module_acl pk_module_acl; Type: CONSTRAINT; Schema: param; Owner: -
--

ALTER TABLE ONLY param.module_acl
    ADD CONSTRAINT pk_module_acl PRIMARY KEY (modul_key, peran);


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
-- Name: instrument instrument_pkey; Type: CONSTRAINT; Schema: survey; Owner: -
--

ALTER TABLE ONLY survey.instrument
    ADD CONSTRAINT instrument_pkey PRIMARY KEY (instrument_code);


--
-- Name: mission_check mission_check_pkey; Type: CONSTRAINT; Schema: survey; Owner: -
--

ALTER TABLE ONLY survey.mission_check
    ADD CONSTRAINT mission_check_pkey PRIMARY KEY (check_id);


--
-- Name: mission_cost mission_cost_pkey; Type: CONSTRAINT; Schema: survey; Owner: -
--

ALTER TABLE ONLY survey.mission_cost
    ADD CONSTRAINT mission_cost_pkey PRIMARY KEY (cost_id);


--
-- Name: mission_log mission_log_pkey; Type: CONSTRAINT; Schema: survey; Owner: -
--

ALTER TABLE ONLY survey.mission_log
    ADD CONSTRAINT mission_log_pkey PRIMARY KEY (log_id);


--
-- Name: mission mission_mission_no_key; Type: CONSTRAINT; Schema: survey; Owner: -
--

ALTER TABLE ONLY survey.mission
    ADD CONSTRAINT mission_mission_no_key UNIQUE (mission_no);


--
-- Name: mission mission_pkey; Type: CONSTRAINT; Schema: survey; Owner: -
--

ALTER TABLE ONLY survey.mission
    ADD CONSTRAINT mission_pkey PRIMARY KEY (mission_id);


--
-- Name: mission_result mission_result_pkey; Type: CONSTRAINT; Schema: survey; Owner: -
--

ALTER TABLE ONLY survey.mission_result
    ADD CONSTRAINT mission_result_pkey PRIMARY KEY (result_id);


--
-- Name: mission_check uq_mck; Type: CONSTRAINT; Schema: survey; Owner: -
--

ALTER TABLE ONLY survey.mission_check
    ADD CONSTRAINT uq_mck UNIQUE (mission_id, item_key);


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
-- Name: idx_dv_doc; Type: INDEX; Schema: document; Owner: -
--

CREATE INDEX idx_dv_doc ON document.doc_verification USING btree (document_id);


--
-- Name: idx_form_foto_record; Type: INDEX; Schema: document; Owner: -
--

CREATE INDEX idx_form_foto_record ON document.form_foto USING btree (form_jenis, record_id);


--
-- Name: idx_form_foto_waktu; Type: INDEX; Schema: document; Owner: -
--

CREATE INDEX idx_form_foto_waktu ON document.form_foto USING btree (created_at DESC);


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
-- Name: idx_reading_daily_param_hari; Type: INDEX; Schema: enviro; Owner: -
--

CREATE INDEX idx_reading_daily_param_hari ON enviro.reading_daily USING btree (parameter_code, hari);


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
-- Name: idx_raw_ts; Type: INDEX; Schema: enviro_raw; Owner: -
--

CREATE INDEX idx_raw_ts ON ONLY enviro_raw.reading USING btree (ts);


--
-- Name: reading_default_ts_idx; Type: INDEX; Schema: enviro_raw; Owner: -
--

CREATE INDEX reading_default_ts_idx ON enviro_raw.reading_default USING btree (ts);


--
-- Name: reading_p2026_09_ts_idx; Type: INDEX; Schema: enviro_raw; Owner: -
--

CREATE INDEX reading_p2026_09_ts_idx ON enviro_raw.reading_p2026_09 USING btree (ts);


--
-- Name: reading_p2026_10_ts_idx; Type: INDEX; Schema: enviro_raw; Owner: -
--

CREATE INDEX reading_p2026_10_ts_idx ON enviro_raw.reading_p2026_10 USING btree (ts);


--
-- Name: reading_p2026_11_ts_idx; Type: INDEX; Schema: enviro_raw; Owner: -
--

CREATE INDEX reading_p2026_11_ts_idx ON enviro_raw.reading_p2026_11 USING btree (ts);


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
-- Name: idx_maintenance_window; Type: INDEX; Schema: fleet; Owner: -
--

CREATE INDEX idx_maintenance_window ON fleet.vessel_maintenance USING btree (fleet_code, window_start);


--
-- Name: idx_notif_inbox; Type: INDEX; Schema: notification; Owner: -
--

CREATE INDEX idx_notif_inbox ON notification.notif_inapp USING btree (username, dibaca);


--
-- Name: idx_notif_outbox_status; Type: INDEX; Schema: notification; Owner: -
--

CREATE INDEX idx_notif_outbox_status ON notification.notif_outbox USING btree (status, outbox_id);


--
-- Name: idx_notif_penerima_aktif; Type: INDEX; Schema: notification; Owner: -
--

CREATE INDEX idx_notif_penerima_aktif ON notification.notif_penerima USING btree (aktif);


--
-- Name: idx_notiflog_rule; Type: INDEX; Schema: notification; Owner: -
--

CREATE INDEX idx_notiflog_rule ON notification.log USING btree (rule_id);


--
-- Name: idx_notiflog_status; Type: INDEX; Schema: notification; Owner: -
--

CREATE INDEX idx_notiflog_status ON notification.log USING btree (status);


--
-- Name: idx_ap_doc; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX idx_ap_doc ON operational.doc_approval USING btree (doc_kind, doc_id);


--
-- Name: idx_de_trip; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX idx_de_trip ON operational.discharge_event USING btree (trip_id, event_at);


--
-- Name: idx_lc_created; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX idx_lc_created ON operational.line_compliance USING btree (created_at);


--
-- Name: idx_lc_line; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX idx_lc_line ON operational.line_compliance USING btree (line_id);


--
-- Name: idx_lc_trip; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX idx_lc_trip ON operational.line_compliance USING btree (trip_id);


--
-- Name: idx_mr_trip; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX idx_mr_trip ON operational.manual_report USING btree (trip_id, reported_at);


--
-- Name: idx_site_contract_area; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX idx_site_contract_area ON operational.site_contract USING btree (area_code);


--
-- Name: idx_sl_area; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX idx_sl_area ON operational.site_line USING btree (area_code, line_no);


--
-- Name: idx_sl_geom; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX idx_sl_geom ON operational.site_line USING gist (geom);


--
-- Name: idx_tdc_trip; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX idx_tdc_trip ON operational.trip_doc_check USING btree (trip_id, verified_at DESC);


--
-- Name: idx_trip_fleet; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX idx_trip_fleet ON operational.trip USING btree (fleet_code);


--
-- Name: idx_trip_status; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX idx_trip_status ON operational.trip USING btree (status) WHERE ((status)::text <> ALL (ARRAY[('CLOSED'::character varying)::text, ('CANCELLED'::character varying)::text]));


--
-- Name: idx_vd_status; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX idx_vd_status ON operational.voyage_doc USING btree (status);


--
-- Name: idx_vp_status; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX idx_vp_status ON operational.voyage_plan USING btree (status);


--
-- Name: idx_wa_geom; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX idx_wa_geom ON operational.work_area USING gist (geom);


--
-- Name: idx_wa_zone; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX idx_wa_zone ON operational.work_area USING btree (zone_code);


--
-- Name: idx_wl_trip; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX idx_wl_trip ON operational.waiting_log USING btree (trip_id, start_at);


--
-- Name: idx_work_area_permit; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX idx_work_area_permit ON operational.work_area USING btree (permit_no);


--
-- Name: idx_wz_geom; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX idx_wz_geom ON operational.work_zone USING gist (geom);


--
-- Name: ix_plan_trip; Type: INDEX; Schema: operational; Owner: -
--

CREATE INDEX ix_plan_trip ON operational.schedule_plan USING btree (trip_id);


--
-- Name: uq_plan_aktif_per_trip; Type: INDEX; Schema: operational; Owner: -
--

CREATE UNIQUE INDEX uq_plan_aktif_per_trip ON operational.schedule_plan USING btree (trip_id) WHERE is_active;


--
-- Name: idx_audit_arch_tabel; Type: INDEX; Schema: param; Owner: -
--

CREATE INDEX idx_audit_arch_tabel ON param.audit_log_arch USING btree (tabel);


--
-- Name: idx_audit_arch_waktu; Type: INDEX; Schema: param; Owner: -
--

CREATE INDEX idx_audit_arch_waktu ON param.audit_log_arch USING btree (diubah_pada);


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
-- Name: idx_mcs_mission; Type: INDEX; Schema: survey; Owner: -
--

CREATE INDEX idx_mcs_mission ON survey.mission_cost USING btree (mission_id);


--
-- Name: idx_mlg_mission; Type: INDEX; Schema: survey; Owner: -
--

CREATE INDEX idx_mlg_mission ON survey.mission_log USING btree (mission_id, logged_at);


--
-- Name: idx_mrs_mission; Type: INDEX; Schema: survey; Owner: -
--

CREATE INDEX idx_mrs_mission ON survey.mission_result USING btree (mission_id);


--
-- Name: idx_msn_incident; Type: INDEX; Schema: survey; Owner: -
--

CREATE INDEX idx_msn_incident ON survey.mission USING btree (incident_id);


--
-- Name: idx_msn_jendela; Type: INDEX; Schema: survey; Owner: -
--

CREATE INDEX idx_msn_jendela ON survey.mission USING btree (fleet_code, planned_start);


--
-- Name: idx_msn_schedule; Type: INDEX; Schema: survey; Owner: -
--

CREATE INDEX idx_msn_schedule ON survey.mission USING btree (schedule_id);


--
-- Name: idx_msn_status; Type: INDEX; Schema: survey; Owner: -
--

CREATE INDEX idx_msn_status ON survey.mission USING btree (status);


--
-- Name: idx_msn_wo; Type: INDEX; Schema: survey; Owner: -
--

CREATE INDEX idx_msn_wo ON survey.mission USING btree (mon_wo_id);


--
-- Name: idx_ais_pos_fleet_waktu; Type: INDEX; Schema: telemetry; Owner: -
--

CREATE INDEX idx_ais_pos_fleet_waktu ON telemetry.ais_position USING btree (fleet_code, position_at DESC);


--
-- Name: reading_default_pkey; Type: INDEX ATTACH; Schema: enviro_raw; Owner: -
--

ALTER INDEX enviro_raw.reading_pkey ATTACH PARTITION enviro_raw.reading_default_pkey;


--
-- Name: reading_default_ts_idx; Type: INDEX ATTACH; Schema: enviro_raw; Owner: -
--

ALTER INDEX enviro_raw.idx_raw_ts ATTACH PARTITION enviro_raw.reading_default_ts_idx;


--
-- Name: reading_p2026_09_pkey; Type: INDEX ATTACH; Schema: enviro_raw; Owner: -
--

ALTER INDEX enviro_raw.reading_pkey ATTACH PARTITION enviro_raw.reading_p2026_09_pkey;


--
-- Name: reading_p2026_09_ts_idx; Type: INDEX ATTACH; Schema: enviro_raw; Owner: -
--

ALTER INDEX enviro_raw.idx_raw_ts ATTACH PARTITION enviro_raw.reading_p2026_09_ts_idx;


--
-- Name: reading_p2026_10_pkey; Type: INDEX ATTACH; Schema: enviro_raw; Owner: -
--

ALTER INDEX enviro_raw.reading_pkey ATTACH PARTITION enviro_raw.reading_p2026_10_pkey;


--
-- Name: reading_p2026_10_ts_idx; Type: INDEX ATTACH; Schema: enviro_raw; Owner: -
--

ALTER INDEX enviro_raw.idx_raw_ts ATTACH PARTITION enviro_raw.reading_p2026_10_ts_idx;


--
-- Name: reading_p2026_11_pkey; Type: INDEX ATTACH; Schema: enviro_raw; Owner: -
--

ALTER INDEX enviro_raw.reading_pkey ATTACH PARTITION enviro_raw.reading_p2026_11_pkey;


--
-- Name: reading_p2026_11_ts_idx; Type: INDEX ATTACH; Schema: enviro_raw; Owner: -
--

ALTER INDEX enviro_raw.idx_raw_ts ATTACH PARTITION enviro_raw.reading_p2026_11_ts_idx;


--
-- Name: deposit_transaction trg_deposit_balance_sync; Type: TRIGGER; Schema: buyer; Owner: -
--

CREATE TRIGGER trg_deposit_balance_sync AFTER INSERT OR DELETE OR UPDATE ON buyer.deposit_transaction FOR EACH ROW EXECUTE FUNCTION buyer.fn_deposit_balance_sync();


--
-- Name: bap_correction trg_bap_koreksi_kuota; Type: TRIGGER; Schema: commercial; Owner: -
--

CREATE TRIGGER trg_bap_koreksi_kuota AFTER INSERT ON commercial.bap_correction FOR EACH ROW EXECUTE FUNCTION operational.fn_bap_koreksi_kuota();


--
-- Name: bap trg_bap_sah_kuota; Type: TRIGGER; Schema: commercial; Owner: -
--

CREATE TRIGGER trg_bap_sah_kuota AFTER UPDATE OF status ON commercial.bap FOR EACH ROW WHEN ((((new.status)::text = 'SIGNED'::text) AND ((old.status)::text IS DISTINCT FROM 'SIGNED'::text))) EXECUTE FUNCTION operational.fn_bap_sah_kuota();


--
-- Name: bap trg_po_delivered_sync; Type: TRIGGER; Schema: commercial; Owner: -
--

CREATE TRIGGER trg_po_delivered_sync AFTER INSERT OR UPDATE OF volume_m3, status ON commercial.bap FOR EACH ROW WHEN (((new.status)::text = ANY (ARRAY[('SIGNED'::character varying)::text, ('CORRECTED'::character varying)::text]))) EXECUTE FUNCTION commercial.fn_po_delivered_sync();


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
-- Name: doc_verification doc_verification_document_id_fkey; Type: FK CONSTRAINT; Schema: document; Owner: -
--

ALTER TABLE ONLY document.doc_verification
    ADD CONSTRAINT doc_verification_document_id_fkey FOREIGN KEY (document_id) REFERENCES document.document(document_id) ON DELETE CASCADE;


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
-- Name: sensor_threshold sensor_threshold_parameter_code_fkey; Type: FK CONSTRAINT; Schema: enviro_raw; Owner: -
--

ALTER TABLE ONLY enviro_raw.sensor_threshold
    ADD CONSTRAINT sensor_threshold_parameter_code_fkey FOREIGN KEY (parameter_code) REFERENCES enviro.mon_parameter(parameter_code);


--
-- Name: station_token station_token_station_code_fkey; Type: FK CONSTRAINT; Schema: enviro_raw; Owner: -
--

ALTER TABLE ONLY enviro_raw.station_token
    ADD CONSTRAINT station_token_station_code_fkey FOREIGN KEY (station_code) REFERENCES enviro.station(station_code) ON DELETE CASCADE;


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
-- Name: vessel_maintenance vessel_maintenance_fleet_code_fkey; Type: FK CONSTRAINT; Schema: fleet; Owner: -
--

ALTER TABLE ONLY fleet.vessel_maintenance
    ADD CONSTRAINT vessel_maintenance_fleet_code_fkey FOREIGN KEY (fleet_code) REFERENCES fleet.info(fleet_code);


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
-- Name: notif_outbox notif_outbox_penerima_id_fkey; Type: FK CONSTRAINT; Schema: notification; Owner: -
--

ALTER TABLE ONLY notification.notif_outbox
    ADD CONSTRAINT notif_outbox_penerima_id_fkey FOREIGN KEY (penerima_id) REFERENCES notification.notif_penerima(penerima_id);


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
-- Name: line_compliance line_compliance_line_id_fkey; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.line_compliance
    ADD CONSTRAINT line_compliance_line_id_fkey FOREIGN KEY (line_id) REFERENCES operational.site_line(line_id);


--
-- Name: line_compliance line_compliance_trip_id_fkey; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.line_compliance
    ADD CONSTRAINT line_compliance_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES operational.trip(trip_id);


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
-- Name: site_contract site_contract_area_code_fkey; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.site_contract
    ADD CONSTRAINT site_contract_area_code_fkey FOREIGN KEY (area_code) REFERENCES operational.work_area(area_code);


--
-- Name: site_contract site_contract_sales_contract_id_fkey; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.site_contract
    ADD CONSTRAINT site_contract_sales_contract_id_fkey FOREIGN KEY (sales_contract_id) REFERENCES commercial.sales_contract(sales_contract_id);


--
-- Name: site_line site_line_area_code_fkey; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.site_line
    ADD CONSTRAINT site_line_area_code_fkey FOREIGN KEY (area_code) REFERENCES operational.work_area(area_code);


--
-- Name: site_permit site_permit_trip_id_fkey; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.site_permit
    ADD CONSTRAINT site_permit_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES operational.trip(trip_id);


--
-- Name: trip trip_discharge_fence_code_fkey; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.trip
    ADD CONSTRAINT trip_discharge_fence_code_fkey FOREIGN KEY (discharge_fence_code) REFERENCES telemetry.geofence(fence_code);


--
-- Name: trip_doc_check trip_doc_check_trip_id_fkey; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.trip_doc_check
    ADD CONSTRAINT trip_doc_check_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES operational.trip(trip_id);


--
-- Name: trip trip_fleet_code_fkey; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.trip
    ADD CONSTRAINT trip_fleet_code_fkey FOREIGN KEY (fleet_code) REFERENCES fleet.info(fleet_code);


--
-- Name: trip trip_line_id_fkey; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.trip
    ADD CONSTRAINT trip_line_id_fkey FOREIGN KEY (line_id) REFERENCES operational.site_line(line_id);


--
-- Name: voyage_doc voyage_doc_nor_id_fkey; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.voyage_doc
    ADD CONSTRAINT voyage_doc_nor_id_fkey FOREIGN KEY (nor_id) REFERENCES operational.nor(nor_id);


--
-- Name: voyage_doc voyage_doc_trip_id_fkey; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.voyage_doc
    ADD CONSTRAINT voyage_doc_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES operational.trip(trip_id);


--
-- Name: voyage_plan voyage_plan_trip_id_fkey; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.voyage_plan
    ADD CONSTRAINT voyage_plan_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES operational.trip(trip_id);


--
-- Name: waiting_log waiting_log_trip_id_fkey; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.waiting_log
    ADD CONSTRAINT waiting_log_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES operational.trip(trip_id);


--
-- Name: work_area work_area_fence_code_fkey; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.work_area
    ADD CONSTRAINT work_area_fence_code_fkey FOREIGN KEY (fence_code) REFERENCES telemetry.geofence(fence_code);


--
-- Name: work_area work_area_zone_code_fkey; Type: FK CONSTRAINT; Schema: operational; Owner: -
--

ALTER TABLE ONLY operational.work_area
    ADD CONSTRAINT work_area_zone_code_fkey FOREIGN KEY (zone_code) REFERENCES operational.work_zone(zone_code);


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
-- Name: mission_check mission_check_mission_id_fkey; Type: FK CONSTRAINT; Schema: survey; Owner: -
--

ALTER TABLE ONLY survey.mission_check
    ADD CONSTRAINT mission_check_mission_id_fkey FOREIGN KEY (mission_id) REFERENCES survey.mission(mission_id) ON DELETE CASCADE;


--
-- Name: mission_cost mission_cost_mission_id_fkey; Type: FK CONSTRAINT; Schema: survey; Owner: -
--

ALTER TABLE ONLY survey.mission_cost
    ADD CONSTRAINT mission_cost_mission_id_fkey FOREIGN KEY (mission_id) REFERENCES survey.mission(mission_id) ON DELETE CASCADE;


--
-- Name: mission mission_fleet_code_fkey; Type: FK CONSTRAINT; Schema: survey; Owner: -
--

ALTER TABLE ONLY survey.mission
    ADD CONSTRAINT mission_fleet_code_fkey FOREIGN KEY (fleet_code) REFERENCES fleet.info(fleet_code);


--
-- Name: mission mission_incident_id_fkey; Type: FK CONSTRAINT; Schema: survey; Owner: -
--

ALTER TABLE ONLY survey.mission
    ADD CONSTRAINT mission_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES hse.incident(incident_id);


--
-- Name: mission_log mission_log_mission_id_fkey; Type: FK CONSTRAINT; Schema: survey; Owner: -
--

ALTER TABLE ONLY survey.mission_log
    ADD CONSTRAINT mission_log_mission_id_fkey FOREIGN KEY (mission_id) REFERENCES survey.mission(mission_id) ON DELETE CASCADE;


--
-- Name: mission mission_mon_wo_id_fkey; Type: FK CONSTRAINT; Schema: survey; Owner: -
--

ALTER TABLE ONLY survey.mission
    ADD CONSTRAINT mission_mon_wo_id_fkey FOREIGN KEY (mon_wo_id) REFERENCES enviro.mon_work_order(wo_id);


--
-- Name: mission_result mission_result_doc_ref_fkey; Type: FK CONSTRAINT; Schema: survey; Owner: -
--

ALTER TABLE ONLY survey.mission_result
    ADD CONSTRAINT mission_result_doc_ref_fkey FOREIGN KEY (doc_ref) REFERENCES document.document(document_id);


--
-- Name: mission_result mission_result_instrument_code_fkey; Type: FK CONSTRAINT; Schema: survey; Owner: -
--

ALTER TABLE ONLY survey.mission_result
    ADD CONSTRAINT mission_result_instrument_code_fkey FOREIGN KEY (instrument_code) REFERENCES survey.instrument(instrument_code);


--
-- Name: mission_result mission_result_mission_id_fkey; Type: FK CONSTRAINT; Schema: survey; Owner: -
--

ALTER TABLE ONLY survey.mission_result
    ADD CONSTRAINT mission_result_mission_id_fkey FOREIGN KEY (mission_id) REFERENCES survey.mission(mission_id) ON DELETE CASCADE;


--
-- Name: mission_result mission_result_station_code_fkey; Type: FK CONSTRAINT; Schema: survey; Owner: -
--

ALTER TABLE ONLY survey.mission_result
    ADD CONSTRAINT mission_result_station_code_fkey FOREIGN KEY (station_code) REFERENCES enviro.station(station_code);


--
-- Name: mission mission_schedule_id_fkey; Type: FK CONSTRAINT; Schema: survey; Owner: -
--

ALTER TABLE ONLY survey.mission
    ADD CONSTRAINT mission_schedule_id_fkey FOREIGN KEY (schedule_id) REFERENCES enviro.mon_schedule(schedule_id);


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

\unrestrict bB2osQFCA9sbuqZh0fI34EwLBAqRH4nqE1sXvDZpupNtLgSfTcANJdpXxgh4s0b

