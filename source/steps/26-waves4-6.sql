BEGIN;
CREATE TABLE IF NOT EXISTS fleet.fuel_log (
 fuel_id uuid PRIMARY KEY,
 fleet_code varchar(30) NOT NULL REFERENCES fleet.info(fleet_code),
 trip_id bigint REFERENCES operational.trip(trip_id),
 filled_at timestamptz NOT NULL,
 liters numeric(14,3) NOT NULL CHECK(liters>0),
 fuel_type varchar(40) NOT NULL,
 unit_price numeric(18,4) CHECK(unit_price>=0),
 currency_code char(3) REFERENCES param.currency(currency_code),
 meter_hours numeric(14,2) CHECK(meter_hours>=0),
 payer text NOT NULL CHECK(payer IN ('COMPANY','PARTNER','INCLUDED_CHARTER','INCLUDED_MISSION','UNKNOWN')),
 payer_note varchar(200) NOT NULL DEFAULT '',
 reference varchar(120) NOT NULL,
 source text NOT NULL DEFAULT 'WEB' CHECK(source IN ('WEB','PWA')),
 payload_hash text NOT NULL CHECK(payload_hash ~ '^[0-9a-f]{64}$'),
 created_by varchar(150) NOT NULL, auth_user_id bigint NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 version integer NOT NULL DEFAULT 1,
 voided_at timestamptz, voided_by varchar(150), void_reason text,
 CHECK((unit_price IS NULL AND currency_code IS NULL) OR (unit_price IS NOT NULL AND currency_code IS NOT NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS fuel_active_reference ON fleet.fuel_log(fleet_code,lower(reference)) WHERE voided_at IS NULL;
CREATE INDEX IF NOT EXISTS fuel_trip ON fleet.fuel_log(trip_id) WHERE voided_at IS NULL;
CREATE OR REPLACE VIEW analytics.v_bbm_efisiensi AS
 WITH filling AS (SELECT trip_id,fleet_code,fuel_type,sum(liters) AS liters_filled,count(*) AS n_fillings
   FROM fleet.fuel_log WHERE voided_at IS NULL AND trip_id IS NOT NULL GROUP BY trip_id,fleet_code,fuel_type),
 bap AS (SELECT trip_id,count(*) AS n_bap,count(*) FILTER(WHERE status='SIGNED') AS n_signed,
   max(volume_m3) AS volume_m3 FROM commercial.bap GROUP BY trip_id)
 SELECT t.trip_id,t.trip_no,t.fleet_code,f.fuel_type,f.liters_filled,f.n_fillings,
   CASE WHEN b.n_bap=1 AND b.n_signed=1 AND t.status<>'CANCELLED' THEN b.volume_m3 END AS volume_bap_m3,
   CASE WHEN b.n_bap=1 AND b.n_signed=1 AND t.status<>'CANCELLED' AND b.volume_m3>0
     THEN f.liters_filled/b.volume_m3 END AS filling_liters_per_m3,
   NULL::numeric AS consumption_liters
 FROM operational.trip t LEFT JOIN filling f ON f.trip_id=t.trip_id AND f.fleet_code=t.fleet_code LEFT JOIN bap b ON b.trip_id=t.trip_id;
COMMENT ON VIEW analytics.v_bbm_efisiensi IS 'Trip x fuel type; recorded fillings, NOT consumption. Only one SIGNED BAP denominator; corrected/multiple/unsigned/cancelled withheld pending reconciliation. No currency aggregation or automatic cost postings.';
INSERT INTO param.system_parameter(param_key,label,nilai,satuan,keterangan,updated_by) VALUES
 ('health_weather_max_minutes','Umur cache cuaca perlu perhatian','360','menit','Umur pengambilan cache, bukan kelengkapan arsip immutable','patch63'),
 ('health_email_max_minutes','Umur antrean email perlu perhatian','60','menit','Antrean tertunda; bukan bukti SMTP terkirim','patch63')
 ON CONFLICT(param_key) DO NOTHING;
COMMIT;
