-- ============================================================
-- DUMMY SEED DATA - 1 TAHUN KE DEPAN
-- Periode: CURRENT_DATE s/d CURRENT_DATE + INTERVAL '1 year'
-- ============================================================

BEGIN;

SET LOCAL TIME ZONE 'Asia/Jakarta';

-- ============================================================
-- OPTIONAL CLEANUP
-- Hapus/comment blok ini kalau tidak ingin menghapus data lama
-- ============================================================

TRUNCATE TABLE
    voyage.voyage_hist,
    voyage.voyage,

    operational.dredging_records,
    operational.work_activity,
    operational.shipment_instruction,
    operational.work_area,

    commercial.delivery_order,
    commercial.purchase_order,

    enviro.water_quality,
    enviro.tide_reading,
    enviro.buoy_reading,
    enviro.maintenance,
    enviro.station,

    laboratory.result,
    laboratory.info,

    survey.measurement,
    survey.water_sampling,

    form.measurement,
    form.sample,
    form.water_sampling,

    fleet.assignment_leg,
    fleet.maintenance,
    fleet.info,
    fleet.type,

    buyer.ledger_hist,
    buyer.site,
    buyer.info,

    partner.info,
    partner.type,

    "user".detail,
    "user".info,

    site.info,
    site.type,

    param.threshold,
    param.unit_conversion,
    param.unit_of_measure,
    param.status,
    param.currency,
    param.country
RESTART IDENTITY CASCADE;


-- ============================================================
-- PARAM MASTER DATA
-- ============================================================

INSERT INTO param.country
    (iso_alpha2, iso_alpha3, iso_name, iso_numeric, name)
VALUES
    ('ID', 'IDN', 'Indonesia', 360, 'Indonesia'),
    ('SG', 'SGP', 'Singapore', 702, 'Singapore'),
    ('MY', 'MYS', 'Malaysia', 458, 'Malaysia'),
    ('AU', 'AUS', 'Australia', 36, 'Australia'),
    ('JP', 'JPN', 'Japan', 392, 'Japan'),
    ('CN', 'CHN', 'China', 156, 'China'),
    ('KR', 'KOR', 'Korea, Republic of', 410, 'South Korea');

INSERT INTO param.currency
    (currency_code, name, symbol)
VALUES
    ('IDR', 'Indonesian Rupiah', 'Rp'),
    ('USD', 'United States Dollar', '$'),
    ('SGD', 'Singapore Dollar', 'S$');

INSERT INTO param.unit_of_measure
    (uom_code, name, category, symbol)
VALUES
    ('M3',       'Cubic Meter',             'VOLUME',      'm3'),
    ('TON',      'Metric Ton',              'MASS',        'ton'),
    ('KG',       'Kilogram',                'MASS',        'kg'),
    ('M',        'Meter',                   'LENGTH',      'm'),
    ('KM',       'Kilometer',               'LENGTH',      'km'),
    ('DAY',      'Day',                     'TIME',        'day'),
    ('HOUR',     'Hour',                    'TIME',        'hour'),
    ('CELSIUS',  'Celsius',                 'TEMPERATURE', 'degC'),
    ('NTU',      'Nephelometric Turbidity', 'OTHER',       'NTU'),
    ('MG_L',     'Milligram per Liter',     'OTHER',       'mg/L'),
    ('PSU',      'Practical Salinity Unit', 'OTHER',       'PSU'),
    ('PH',       'Potential of Hydrogen',   'OTHER',       'pH'),
    ('M_S',      'Meter per Second',        'OTHER',       'm/s'),
    ('KG_M3',    'Kilogram per Cubic Meter','OTHER',       'kg/m3');

INSERT INTO param.unit_conversion
    (uc_code, uom_from, uom_to, conv_value)
VALUES
    ('UC-M-KM',       'M',    'KM',   0.00100000),
    ('UC-KM-M',       'KM',   'M',    1000.00000000),
    ('UC-KG-TON',     'KG',   'TON',  0.00100000),
    ('UC-TON-KG',     'TON',  'KG',   1000.00000000),
    ('UC-DAY-HOUR',   'DAY',  'HOUR', 24.00000000),
    ('UC-HOUR-DAY',   'HOUR', 'DAY',  0.04166667);

INSERT INTO param.status
    (status_code, status_group, description)
VALUES
    ('DRAFT',       'DOCUMENT',   'Draft document'),
    ('SUBMITTED',   'DOCUMENT',   'Submitted document'),
    ('APPROVED',    'DOCUMENT',   'Approved document'),

    ('PLANNED',     'OPERATION',  'Planned operation'),
    ('IN_PROGRESS', 'OPERATION',  'Operation in progress'),
    ('COMPLETED',   'OPERATION',  'Completed operation'),
    ('CANCELLED',   'OPERATION',  'Cancelled operation'),

    ('ACTIVE',      'GENERAL',    'Active'),
    ('INACTIVE',    'GENERAL',    'Inactive'),
    ('MAINTENANCE', 'GENERAL',    'Under maintenance'),

    ('NORMAL',      'QUALITY',    'Normal condition'),
    ('WARNING',     'QUALITY',    'Warning condition'),
    ('ALERT',       'QUALITY',    'Alert condition'),

    ('OPEN',        'COMMERCIAL', 'Open transaction'),
    ('CLOSED',      'COMMERCIAL', 'Closed transaction');

INSERT INTO param.threshold
    (threshold_code, parameter_name, parameter_value, uom_code)
VALUES
    ('PH_MIN',       'Minimum Water pH',        6.500000, 'PH'),
    ('PH_MAX',       'Maximum Water pH',        8.500000, 'PH'),
    ('DO_MIN',       'Minimum Dissolved Oxygen',5.000000, 'MG_L'),
    ('TURB_MAX',     'Maximum Turbidity',       50.000000,'NTU'),
    ('SALINITY_MAX', 'Maximum Salinity',        35.000000,'PSU'),
    ('CURR_MAX',     'Maximum Current Speed',   1.500000, 'M_S');


-- ============================================================
-- SITE MASTER DATA
-- ============================================================

INSERT INTO site.type
    (type_code, type_group, description)
VALUES
    ('OFFICE',     'FACILITY', 'Office or administration site'),
    ('PORT',       'MARINE',   'Port or jetty location'),
    ('LAB',        'FACILITY', 'Laboratory site'),
    ('MONITORING', 'ENVIRO',   'Environmental monitoring site'),
    ('DISCHARGE',  'MARINE',   'Discharge destination site'),
    ('WORKSHOP',   'FACILITY', 'Maintenance workshop'),
    ('STOCKPILE',  'OPERATION','Stockpile area');

INSERT INTO site.info
    (site_code, type_code, name, address, city, lat, "long")
VALUES
    ('SITE-HQ-JKT',  'OFFICE',     'Jakarta Head Office',       'Jl. Dummy Sudirman No. 1',       'Jakarta',     -6.2088000, 106.8456000),
    ('SITE-PRT-BPN', 'PORT',       'Balikpapan Marine Port',    'Pelabuhan Dummy Balikpapan',    'Balikpapan',  -1.2654000, 116.8312000),
    ('SITE-PRT-SMR', 'PORT',       'Samarinda Jetty',           'Jetty Dummy Samarinda',         'Samarinda',   -0.5022000, 117.1536000),
    ('SITE-DSG-SBY', 'DISCHARGE',  'Surabaya Discharge Point',  'Terminal Dummy Surabaya',       'Surabaya',    -7.2575000, 112.7521000),
    ('SITE-DSG-MKS', 'DISCHARGE',  'Makassar Discharge Point',  'Terminal Dummy Makassar',       'Makassar',    -5.1477000, 119.4327000),
    ('SITE-LAB-SBY', 'LAB',        'Surabaya Water Laboratory', 'Jl. Dummy Lab No. 10',          'Surabaya',    -7.2900000, 112.7280000),
    ('SITE-MON-MBR', 'MONITORING', 'Muara Berau Monitoring',    'Muara Berau Offshore Area',     'Kutai',       -0.6000000, 117.4500000),
    ('SITE-WRK-BPN', 'WORKSHOP',   'Balikpapan Workshop',       'Kawasan Industri Dummy',        'Balikpapan',  -1.2345000, 116.8700000),
    ('SITE-STK-KTN', 'STOCKPILE',  'Kutai Stockpile Area',      'Area Stockpile Dummy Kutai',    'Kutai',       -0.2500000, 117.5500000);


-- ============================================================
-- USER DATA
-- ============================================================

INSERT INTO "user".info
    (user_code, name, role)
VALUES
    ('USR-ADM-01', 'Ayu Pratiwi',       'ADMIN'),
    ('USR-OPS-01', 'Budi Santoso',      'OPERATOR'),
    ('USR-SRV-01', 'Citra Lestari',     'SURVEYOR'),
    ('USR-LAB-01', 'Dewi Anggraini',    'LAB_ANALYST'),
    ('USR-MGR-01', 'Eka Wijaya',        'MANAGER'),
    ('USR-COM-01', 'Fajar Ramadhan',    'COMMERCIAL'),
    ('USR-FIN-01', 'Gina Sari',         'FINANCE');

INSERT INTO "user".detail
    (user_code, contact_type, contact_value, is_primary)
VALUES
    ('USR-ADM-01', 'EMAIL', 'ayu.pratiwi@example.test',    TRUE),
    ('USR-OPS-01', 'EMAIL', 'budi.santoso@example.test',   TRUE),
    ('USR-SRV-01', 'EMAIL', 'citra.lestari@example.test',  TRUE),
    ('USR-LAB-01', 'EMAIL', 'dewi.lab@example.test',       TRUE),
    ('USR-MGR-01', 'EMAIL', 'eka.wijaya@example.test',     TRUE),
    ('USR-COM-01', 'EMAIL', 'fajar.com@example.test',      TRUE),
    ('USR-FIN-01', 'EMAIL', 'gina.finance@example.test',   TRUE),

    ('USR-ADM-01', 'PHONE', '+628110000001', FALSE),
    ('USR-OPS-01', 'PHONE', '+628110000002', FALSE),
    ('USR-SRV-01', 'PHONE', '+628110000003', FALSE),
    ('USR-LAB-01', 'PHONE', '+628110000004', FALSE),
    ('USR-MGR-01', 'PHONE', '+628110000005', FALSE),
    ('USR-COM-01', 'PHONE', '+628110000006', FALSE),
    ('USR-FIN-01', 'PHONE', '+628110000007', FALSE);


-- ============================================================
-- PARTNER, BUYER
-- ============================================================

INSERT INTO partner.type
    (type_code, description)
VALUES
    ('OWNER',       'Fleet owner'),
    ('CONTRACTOR',  'Operational contractor'),
    ('AGENCY',      'Shipping agency'),
    ('LAB_VENDOR',  'Laboratory vendor'),
    ('MAINTENANCE', 'Maintenance service partner');

INSERT INTO partner.info
    (partner_code, type_code, name, site_code)
VALUES
    ('PRT-FLEET-01', 'OWNER',       'PT Armada Laut Dummy',          'SITE-PRT-BPN'),
    ('PRT-FLEET-02', 'OWNER',       'PT Samudera Angkut Dummy',      'SITE-PRT-SMR'),
    ('PRT-AGENT-01', 'AGENCY',      'PT Agen Pelayaran Dummy',       'SITE-HQ-JKT'),
    ('PRT-LAB-01',   'LAB_VENDOR',  'PT Laboratorium Lingkungan',    'SITE-LAB-SBY'),
    ('PRT-MTC-01',   'MAINTENANCE', 'PT Dockyard Maintenance Dummy', 'SITE-WRK-BPN');

INSERT INTO buyer.info
    (buyer_code, name, site_code)
VALUES
    ('BYR-001', 'PT Nusantara Power Dummy',     'SITE-DSG-SBY'),
    ('BYR-002', 'PT Industri Semen Dummy',      'SITE-DSG-MKS'),
    ('BYR-003', 'PT Mineral Trading Dummy',     'SITE-DSG-SBY');

INSERT INTO buyer.site
    (buyer_code, name, site_code)
VALUES
    ('BYR-001', 'Surabaya Receiving Terminal', 'SITE-DSG-SBY'),
    ('BYR-001', 'Makassar Backup Terminal',    'SITE-DSG-MKS'),
    ('BYR-002', 'Makassar Main Terminal',      'SITE-DSG-MKS'),
    ('BYR-003', 'Surabaya Main Terminal',      'SITE-DSG-SBY');


-- ============================================================
-- FLEET DATA
-- ============================================================

INSERT INTO fleet.type
    (type_code, description)
VALUES
    ('TUG',     'Tug boat'),
    ('BARGE',   'Barge vessel'),
    ('DREDGER', 'Dredging vessel'),
    ('SURVEY',  'Survey boat'),
    ('SUPPORT', 'Support vessel');

WITH c AS (
    SELECT country_id
    FROM param.country
    WHERE iso_alpha2 = 'ID'
)
INSERT INTO fleet.info
    (
        fleet_code,
        partner_code,
        type_code,
        name,
        imo_number,
        mmsi_number,
        call_sign,
        flag_country_id,
        grt,
        dwt
    )
SELECT
    v.fleet_code,
    v.partner_code,
    v.type_code,
    v.name,
    v.imo_number,
    v.mmsi_number,
    v.call_sign,
    c.country_id,
    v.grt,
    v.dwt
FROM (
    VALUES
        ('FL-DRED-01', 'PRT-FLEET-01', 'DREDGER', 'Dredger Garuda',       '9350001', '525001001', 'YBGA', 6200,  9800),
        ('FL-DRED-02', 'PRT-FLEET-01', 'DREDGER', 'Dredger Mahakam',      '9350002', '525001002', 'YBGM', 5800,  9200),
        ('FL-BRG-01',  'PRT-FLEET-02', 'BARGE',   'Barge Kapuas 3001',    '9350003', '525001003', 'YBGK', 3500, 12000),
        ('FL-BRG-02',  'PRT-FLEET-02', 'BARGE',   'Barge Barito 3002',    '9350004', '525001004', 'YBGB', 3600, 12500),
        ('FL-TUG-01',  'PRT-FLEET-02', 'TUG',     'Tug Samudera 01',      '9350005', '525001005', 'YBTS', 1200,  1500),
        ('FL-TUG-02',  'PRT-FLEET-02', 'TUG',     'Tug Samudera 02',      '9350006', '525001006', 'YBTT', 1180,  1450),
        ('FL-SURV-01', 'PRT-FLEET-01', 'SURVEY',  'Survey Boat Lestari',  '9350007', '525001007', 'YBSL',  450,   300),
        ('FL-SUP-01',  'PRT-FLEET-01', 'SUPPORT', 'Support Boat Nusantara','9350008','525001008', 'YBSN',  700,   850)
) AS v(
    fleet_code,
    partner_code,
    type_code,
    name,
    imo_number,
    mmsi_number,
    call_sign,
    grt,
    dwt
)
CROSS JOIN c;

INSERT INTO fleet.assignment_leg
    (fleet_code, site_code, est_start_date, est_end_date)
SELECT
    fleet_code,
    CASE
        WHEN type_code = 'SURVEY'  THEN 'SITE-MON-MBR'
        WHEN type_code = 'SUPPORT' THEN 'SITE-WRK-BPN'
        ELSE 'SITE-PRT-BPN'
    END AS site_code,
    CURRENT_DATE,
    (CURRENT_DATE + INTERVAL '1 year')::date
FROM fleet.info;

WITH fl AS (
    SELECT
        fleet_code,
        (row_number() OVER (ORDER BY fleet_code))::int AS rn
    FROM fleet.info
),
mtc(slot_no, base_day, duration_days) AS (
    VALUES
        (1, 60, 3),
        (2, 240, 4)
)
INSERT INTO fleet.maintenance
    (fleet_code, description, start_date, end_date)
SELECT
    fl.fleet_code,
    format('Preventive maintenance slot %s', mtc.slot_no),
    CURRENT_DATE + (mtc.base_day + fl.rn),
    CURRENT_DATE + (mtc.base_day + fl.rn + mtc.duration_days)
FROM fl
CROSS JOIN mtc;


-- ============================================================
-- LABORATORY MASTER
-- ============================================================

INSERT INTO laboratory.info
    (lab_code, site_code)
VALUES
    ('LAB-SBY-01', 'SITE-LAB-SBY'),
    ('LAB-BPN-01', 'SITE-PRT-BPN');


-- ============================================================
-- FORM WATER SAMPLING DUMMY
-- Monthly data selama 1 tahun ke depan
-- ============================================================

WITH d AS (
    SELECT
        g.gs::date AS sampling_date,
        (row_number() OVER (ORDER BY g.gs))::int AS rn
    FROM generate_series(
        CURRENT_DATE::timestamp,
        ((CURRENT_DATE + INTERVAL '1 year')::date)::timestamp,
        INTERVAL '1 month'
    ) AS g(gs)
)
INSERT INTO form.water_sampling
    (
        form_no,
        sampling_date,
        total_sample,
        recorder_by,
        received_by,
        status,
        location_desc,
        weather
    )
SELECT
    'FWS-' || to_char(sampling_date, 'YYYYMMDD') AS form_no,
    sampling_date,
    3 AS total_sample,
    'USR-SRV-01',
    'USR-LAB-01',
    'SUBMITTED',
    'Dummy monthly water sampling at Muara Berau and discharge area',
    CASE rn % 4
        WHEN 0 THEN 'Hujan ringan'
        WHEN 1 THEN 'Cerah'
        WHEN 2 THEN 'Berawan'
        ELSE 'Panas'
    END
FROM d;

INSERT INTO form.sample
    (form_no, sample_no, type_sample, description, status)
SELECT
    f.form_no,
    s.sample_no,
    CASE s.sample_no
        WHEN 1 THEN 'SURFACE_WATER'
        WHEN 2 THEN 'MID_WATER'
        ELSE 'BOTTOM_WATER'
    END,
    format('Dummy sample %s for %s', s.sample_no, f.form_no),
    'SUBMITTED'
FROM form.water_sampling f
CROSS JOIN generate_series(1, 3) AS s(sample_no)
WHERE f.form_no LIKE 'FWS-%';

WITH params(parameter_name, uom_code, method) AS (
    VALUES
        ('pH',               'PH',      'APHA 4500-H+ B'),
        ('Temperature',      'CELSIUS', 'APHA 2550 B'),
        ('Turbidity',        'NTU',     'APHA 2130 B'),
        ('Dissolved Oxygen', 'MG_L',    'APHA 4500-O G'),
        ('Salinity',         'PSU',     'Refractometer')
)
INSERT INTO form.measurement
    (
        form_no,
        sample_id,
        parameter_name,
        parameter_value,
        uom_code,
        method,
        status
    )
SELECT
    s.form_no,
    s.sample_id,
    p.parameter_name,
    CASE p.parameter_name
        WHEN 'pH'
            THEN ROUND((7.10::double precision + (((s.sample_id % 7) - 3)::double precision * 0.03) + random() * 0.05)::numeric, 6)
        WHEN 'Temperature'
            THEN ROUND((28.20::double precision + (((s.sample_id % 5) - 2)::double precision * 0.20) + random() * 0.30)::numeric, 6)
        WHEN 'Turbidity'
            THEN ROUND((14.00::double precision + ((s.sample_id % 8)::double precision * 1.40) + random() * 5.00)::numeric, 6)
        WHEN 'Dissolved Oxygen'
            THEN ROUND((5.60::double precision + ((s.sample_id % 5)::double precision * 0.20) + random() * 0.20)::numeric, 6)
        WHEN 'Salinity'
            THEN ROUND((29.00::double precision + ((s.sample_id % 6)::double precision * 0.50) + random() * 0.80)::numeric, 6)
    END AS parameter_value,
    p.uom_code,
    p.method,
    CASE
        WHEN p.parameter_name = 'Turbidity' AND s.sample_id % 11 = 0 THEN 'WARNING'
        ELSE 'NORMAL'
    END
FROM form.sample s
CROSS JOIN params p
WHERE s.form_no LIKE 'FWS-%';

INSERT INTO laboratory.result
    (doc_no, lab_code, sample_id)
SELECT
    'LR-' || replace(s.form_no, 'FWS-', '') || '-' || lpad(s.sample_no::text, 2, '0'),
    CASE WHEN s.sample_id % 2 = 0 THEN 'LAB-SBY-01' ELSE 'LAB-BPN-01' END,
    s.sample_id
FROM form.sample s
WHERE s.form_no LIKE 'FWS-%';


-- ============================================================
-- SURVEY WATER SAMPLING DUMMY
-- Weekly data selama 1 tahun ke depan
-- ============================================================

WITH d AS (
    SELECT
        g.gs::date AS sampling_date,
        (row_number() OVER (ORDER BY g.gs))::int AS rn
    FROM generate_series(
        CURRENT_DATE::timestamp,
        ((CURRENT_DATE + INTERVAL '1 year')::date)::timestamp,
        INTERVAL '1 week'
    ) AS g(gs)
)
INSERT INTO survey.water_sampling
    (
        form_no,
        sampling_date,
        total_sample,
        recorder_by,
        received_by,
        status
    )
SELECT
    'SWS-' || to_char(sampling_date, 'YYYYMMDD') AS form_no,
    sampling_date,
    1,
    'USR-SRV-01',
    'USR-OPS-01',
    CASE WHEN rn % 8 = 0 THEN 'APPROVED' ELSE 'SUBMITTED' END
FROM d;

WITH f AS (
    SELECT
        form_no,
        sampling_date,
        (row_number() OVER (ORDER BY sampling_date))::int AS rn
    FROM survey.water_sampling
),
params(parameter_name, uom_code, method) AS (
    VALUES
        ('pH',               'PH',      'Portable pH meter'),
        ('Temperature',      'CELSIUS', 'Portable thermometer'),
        ('Turbidity',        'NTU',     'Portable turbidity meter'),
        ('Dissolved Oxygen', 'MG_L',    'DO meter'),
        ('Salinity',         'PSU',     'Portable salinity meter')
)
INSERT INTO survey.measurement
    (
        form_no,
        parameter_name,
        parameter_value,
        uom_code,
        method
    )
SELECT
    f.form_no,
    p.parameter_name,
    CASE p.parameter_name
        WHEN 'pH'
            THEN ROUND((7.05::double precision + SIN(f.rn::double precision / 6.0) * 0.20 + random() * 0.04)::numeric, 6)
        WHEN 'Temperature'
            THEN ROUND((28.10::double precision + SIN(f.rn::double precision / 10.0) * 0.80 + random() * 0.20)::numeric, 6)
        WHEN 'Turbidity'
            THEN ROUND((17.00::double precision + ABS(SIN(f.rn::double precision / 5.0)) * 15.00 + random() * 4.00)::numeric, 6)
        WHEN 'Dissolved Oxygen'
            THEN ROUND((5.70::double precision + COS(f.rn::double precision / 9.0) * 0.50 + random() * 0.20)::numeric, 6)
        WHEN 'Salinity'
            THEN ROUND((29.50::double precision + SIN(f.rn::double precision / 11.0) * 1.00 + random() * 0.50)::numeric, 6)
    END,
    p.uom_code,
    p.method
FROM f
CROSS JOIN params p;


-- ============================================================
-- ENVIRO STATION DAN SENSOR READINGS
-- Daily dan 6-hourly data selama 1 tahun ke depan
-- ============================================================

INSERT INTO enviro.station
    (station_code, site_code, station_type, status)
VALUES
    ('WQ-ST-01',   'SITE-MON-MBR', 'WATER_QUALITY', 'ACTIVE'),
    ('WQ-ST-02',   'SITE-DSG-SBY', 'WATER_QUALITY', 'ACTIVE'),
    ('TIDE-ST-01', 'SITE-MON-MBR', 'TIDE',          'ACTIVE'),
    ('BUOY-ST-01', 'SITE-MON-MBR', 'BUOY',          'ACTIVE'),
    ('BUOY-ST-02', 'SITE-DSG-MKS', 'BUOY',          'ACTIVE');

WITH days AS (
    SELECT g.gs::date AS d
    FROM generate_series(
        CURRENT_DATE::timestamp,
        ((CURRENT_DATE + INTERVAL '1 year')::date)::timestamp,
        INTERVAL '1 day'
    ) AS g(gs)
),
st AS (
    SELECT
        station_code,
        (row_number() OVER (ORDER BY station_code))::int AS rn
    FROM enviro.station
    WHERE station_type = 'WATER_QUALITY'
),
calc AS (
    SELECT
        st.station_code,
        days.d,
        ROUND((6.00::double precision + st.rn::double precision * 0.60 + random() * 2.50)::numeric, 2) AS depth,
        ROUND((1.00::double precision + random() * 1.50)::numeric, 2) AS brightness,
        ROUND((28.00::double precision + SIN(EXTRACT(DOY FROM days.d)::double precision / 365.0 * 2.0 * PI()) * 1.50 + random() * 0.40)::numeric, 2) AS temperature,
        ROUND((15.00::double precision + ABS(SIN(EXTRACT(DOY FROM days.d)::double precision / 45.0)) * 20.00 + random() * 8.00)::numeric, 2) AS turbidity,
        ROUND((5.80::double precision + COS(EXTRACT(DOY FROM days.d)::double precision / 365.0 * 2.0 * PI()) * 0.60 + random() * 0.30)::numeric, 2) AS dissolved_oxygen,
        ROUND((7.10::double precision + random() * 0.35)::numeric, 2) AS ph_level,
        ROUND((29.00::double precision + st.rn::double precision * 0.70 + random() * 3.00)::numeric, 2) AS salt
    FROM st
    CROSS JOIN days
)
INSERT INTO enviro.water_quality
    (
        station_code,
        record_time,
        depth,
        brightness,
        temperature,
        turbidity,
        dissolved_oxygen,
        ph_level,
        salt,
        condition
    )
SELECT
    station_code,
    d + TIME '08:00',
    depth,
    brightness,
    temperature,
    turbidity,
    dissolved_oxygen,
    ph_level,
    salt,
    CASE WHEN turbidity > 38 THEN 'WASPADA' ELSE 'NORMAL' END
FROM calc;

WITH times AS (
    SELECT g.gs AS ts
    FROM generate_series(
        CURRENT_DATE::timestamp,
        ((CURRENT_DATE + INTERVAL '1 year')::date)::timestamp,
        INTERVAL '6 hour'
    ) AS g(gs)
),
st AS (
    SELECT station_code
    FROM enviro.station
    WHERE station_type = 'TIDE'
)
INSERT INTO enviro.tide_reading
    (
        station_code,
        record_time,
        salinity,
        turbidity,
        current_speed,
        dissolved_oxygen,
        water_density,
        tide_level
    )
SELECT
    st.station_code,
    times.ts,
    ROUND((30.00::double precision + random() * 3.00)::numeric, 2),
    ROUND((10.00::double precision + ABS(SIN(EXTRACT(EPOCH FROM times.ts)::double precision / 86400.0)) * 20.00 + random() * 5.00)::numeric, 2),
    ROUND((0.15::double precision + ABS(SIN(EXTRACT(EPOCH FROM times.ts)::double precision / 43200.0)) * 0.85 + random() * 0.10)::numeric, 2),
    ROUND((5.50::double precision + random() * 1.20)::numeric, 2),
    ROUND((1.0180::double precision + random() * 0.0120)::numeric, 4),
    ROUND((1.20::double precision + SIN(EXTRACT(EPOCH FROM times.ts)::double precision / 43200.0 * PI()) * 0.90 + random() * 0.10)::numeric, 2)
FROM st
CROSS JOIN times;

WITH times AS (
    SELECT g.gs AS ts
    FROM generate_series(
        CURRENT_DATE::timestamp,
        ((CURRENT_DATE + INTERVAL '1 year')::date)::timestamp,
        INTERVAL '6 hour'
    ) AS g(gs)
),
st AS (
    SELECT
        station_code,
        (row_number() OVER (ORDER BY station_code))::int AS rn
    FROM enviro.station
    WHERE station_type = 'BUOY'
)
INSERT INTO enviro.buoy_reading
    (
        station_code,
        record_time,
        salinity,
        turbidity,
        current_speed,
        dissolved_oxygen,
        water_density,
        tide_level
    )
SELECT
    st.station_code,
    times.ts,
    ROUND((29.50::double precision + st.rn::double precision * 0.30 + random() * 3.00)::numeric, 2),
    ROUND((12.00::double precision + ABS(SIN(EXTRACT(EPOCH FROM times.ts)::double precision / 90000.0 + st.rn)) * 18.00 + random() * 6.00)::numeric, 2),
    ROUND((0.10::double precision + ABS(COS(EXTRACT(EPOCH FROM times.ts)::double precision / 50000.0 + st.rn)) * 0.75 + random() * 0.12)::numeric, 2),
    ROUND((5.40::double precision + random() * 1.10)::numeric, 2),
    ROUND((1.0170::double precision + random() * 0.0130)::numeric, 4),
    ROUND((1.00::double precision + SIN(EXTRACT(EPOCH FROM times.ts)::double precision / 43200.0 * PI() + st.rn) * 0.75 + random() * 0.15)::numeric, 2)
FROM st
CROSS JOIN times;

WITH st AS (
    SELECT
        station_code,
        (row_number() OVER (ORDER BY station_code))::int AS rn
    FROM enviro.station
),
m(slot_no, base_day, duration_days) AS (
    VALUES
        (1, 45, 2),
        (2, 225, 3)
)
INSERT INTO enviro.maintenance
    (station_code, description, start_date, end_date)
SELECT
    st.station_code,
    format('Preventive calibration #%s for %s', m.slot_no, st.station_code),
    CURRENT_DATE + (m.base_day + st.rn),
    CURRENT_DATE + (m.base_day + st.rn + m.duration_days)
FROM st
CROSS JOIN m;


-- ============================================================
-- COMMERCIAL DATA
-- Purchase Order dan Delivery Order 1 tahun ke depan
-- ============================================================

WITH seq AS (
    SELECT g.n
    FROM generate_series(1, 12) AS g(n)
)
INSERT INTO commercial.purchase_order
    (
        po_num,
        buyer_code,
        contract_number,
        po_date,
        uom_code,
        total_volume,
        unit_price,
        currency_code,
        incoterm,
        target_start_date,
        target_end_date,
        status,
        description,
        created_by,
        approved_by
    )
SELECT
    'PO-' || to_char(CURRENT_DATE + ((n - 1) * 30), 'YYYYMM') || '-' || lpad(n::text, 2, '0') AS po_num,
    CASE n % 3
        WHEN 1 THEN 'BYR-001'
        WHEN 2 THEN 'BYR-002'
        ELSE 'BYR-003'
    END AS buyer_code,
    'CTR-DUMMY-' || lpad(n::text, 2, '0') AS contract_number,
    CURRENT_DATE + ((n - 1) * 30) AS po_date,
    'M3' AS uom_code,
    (30000 + n * 2500)::numeric(18,4) AS total_volume,
    (120000 + (n % 4) * 7500)::numeric(18,4) AS unit_price,
    'IDR' AS currency_code,
    'CIF' AS incoterm,
    CURRENT_DATE + ((n - 1) * 30 + 3) AS target_start_date,
    CURRENT_DATE + ((n - 1) * 30 + 29) AS target_end_date,
    CASE WHEN n = 1 THEN 'APPROVED' ELSE 'PLANNED' END AS status,
    'Dummy PO untuk rencana pengiriman material selama 1 tahun ke depan',
    'USR-COM-01',
    'USR-MGR-01'
FROM seq;

WITH po AS (
    SELECT
        po_num,
        total_volume,
        uom_code,
        target_start_date,
        target_end_date,
        (row_number() OVER (ORDER BY target_start_date, po_num))::int AS rn
    FROM commercial.purchase_order
),
legs AS (
    SELECT g.leg
    FROM generate_series(1, 2) AS g(leg)
)
INSERT INTO commercial.delivery_order
    (
        do_num,
        po_num,
        discharge_site,
        uom_code,
        target_volume,
        target_start_date,
        target_end_date,
        status
    )
SELECT
    'DO-' || substring(po.po_num from 4) || '-' || lpad(legs.leg::text, 2, '0') AS do_num,
    po.po_num,
    CASE
        WHEN (po.rn + legs.leg) % 3 = 0 THEN 'SITE-DSG-MKS'
        ELSE 'SITE-DSG-SBY'
    END AS discharge_site,
    po.uom_code,
    ROUND((po.total_volume / 2.0)::numeric, 4) AS target_volume,
    po.target_start_date + ((legs.leg - 1) * 14) AS target_start_date,
    LEAST(
        po.target_start_date + ((legs.leg * 14) - 1),
        po.target_end_date
    ) AS target_end_date,
    'PLANNED'
FROM po
CROSS JOIN legs;

INSERT INTO buyer.ledger_hist
    (
        buyer_code,
        transaction_date,
        transaction_type,
        amount,
        ref_doc,
        description
    )
SELECT
    buyer_code,
    po_date,
    'CREDIT',
    ROUND(total_amount * 0.30, 2),
    po_num || '-ADV',
    'Dummy advance payment for ' || po_num
FROM commercial.purchase_order

UNION ALL

SELECT
    buyer_code,
    target_end_date,
    'DEBIT',
    ROUND(total_amount * 0.70, 2),
    po_num || '-INV',
    'Dummy invoice accrual for ' || po_num
FROM commercial.purchase_order;


-- ============================================================
-- OPERATIONAL DATA
-- Work area, SI, activity, dredging records
-- ============================================================

INSERT INTO operational.work_area
    (area_code, name, geom)
VALUES
    (
        'AREA-MBR-01',
        'Muara Berau Dredging Block A',
        ST_GeomFromText(
            'POLYGON((117.4000 -0.6600, 117.4800 -0.6600, 117.4800 -0.5800, 117.4000 -0.5800, 117.4000 -0.6600))',
            4326
        )
    ),
    (
        'AREA-MBR-02',
        'Muara Berau Dredging Block B',
        ST_GeomFromText(
            'POLYGON((117.4900 -0.6700, 117.5700 -0.6700, 117.5700 -0.5900, 117.4900 -0.5900, 117.4900 -0.6700))',
            4326
        )
    ),
    (
        'AREA-SBY-01',
        'Surabaya Approach Channel',
        ST_GeomFromText(
            'POLYGON((112.7000 -7.3200, 112.8000 -7.3200, 112.8000 -7.2300, 112.7000 -7.2300, 112.7000 -7.3200))',
            4326
        )
    );

WITH d AS (
    SELECT
        d_o.*,
        (row_number() OVER (ORDER BY d_o.target_start_date, d_o.do_num))::int AS rn
    FROM commercial.delivery_order d_o
)
INSERT INTO operational.shipment_instruction
    (
        si_num,
        do_num,
        fleet_main_code,
        fleet_assist_code,
        working_site,
        discharge_site,
        status
    )
SELECT
    'SI-' || substring(d.do_num from 4) AS si_num,
    d.do_num,
    CASE WHEN d.rn % 2 = 1 THEN 'FL-DRED-01' ELSE 'FL-DRED-02' END AS fleet_main_code,
    CASE WHEN d.rn % 2 = 1 THEN 'FL-TUG-01' ELSE 'FL-TUG-02' END AS fleet_assist_code,
    CASE (d.rn - 1) % 3
        WHEN 0 THEN 'AREA-MBR-01'
        WHEN 1 THEN 'AREA-MBR-02'
        ELSE 'AREA-SBY-01'
    END AS working_site,
    d.discharge_site,
    'PLANNED'
FROM d;

INSERT INTO operational.work_activity
    (
        si_num,
        fleet_code,
        area_code,
        activity_type,
        planned_start,
        planned_end,
        status
    )
SELECT
    si.si_num,
    CASE
        WHEN a.activity_type IN ('MOBILIZATION', 'SAILING')
            THEN COALESCE(si.fleet_assist_code, si.fleet_main_code)
        ELSE si.fleet_main_code
    END AS fleet_code,
    si.working_site,
    a.activity_type,
    (d.target_start_date + a.start_offset) + a.start_time AS planned_start,
    (d.target_start_date + a.end_offset) + a.end_time AS planned_end,
    'PLANNED'
FROM operational.shipment_instruction si
JOIN commercial.delivery_order d
    ON d.do_num = si.do_num
CROSS JOIN (
    VALUES
        (1, 'MOBILIZATION', -1, TIME '08:00',  0, TIME '06:00'),
        (2, 'DREDGING',      0, TIME '08:00', 10, TIME '18:00'),
        (3, 'SAILING',      11, TIME '06:00', 12, TIME '18:00'),
        (4, 'DISCHARGE',    13, TIME '08:00', 13, TIME '18:00')
) AS a(seq, activity_type, start_offset, start_time, end_offset, end_time);

INSERT INTO operational.dredging_records
    (
        si_num,
        activity_num,
        record_date,
        dredging_volume,
        uom_code,
        created_by,
        notes
    )
SELECT
    wa.si_num,
    wa.activity_num,
    wa.planned_start::date + g.day_offset AS record_date,
    ROUND((d.target_volume * 0.80 / 10)::numeric, 4) AS dredging_volume,
    d.uom_code,
    'USR-OPS-01',
    'Dummy daily dredging progress, 80 percent of DO target spread over 10 days'
FROM operational.work_activity wa
JOIN operational.shipment_instruction si
    ON si.si_num = wa.si_num
JOIN commercial.delivery_order d
    ON d.do_num = si.do_num
CROSS JOIN generate_series(0, 9) AS g(day_offset)
WHERE wa.activity_type = 'DREDGING';


-- ============================================================
-- VOYAGE DATA
-- Future voyage position dan voyage history
-- ============================================================

WITH fl AS (
    SELECT
        fleet_code,
        (row_number() OVER (ORDER BY fleet_code))::int AS rn
    FROM fleet.info
),
times AS (
    SELECT
        g.gs AS ts,
        (row_number() OVER (ORDER BY g.gs))::int AS seq
    FROM generate_series(
        CURRENT_DATE::timestamp,
        ((CURRENT_DATE + INTERVAL '1 year')::date)::timestamp,
        INTERVAL '7 day'
    ) AS g(gs)
)
INSERT INTO voyage.voyage
    (
        fleet_code,
        do_num,
        lat,
        "long",
        record_time,
        status
    )
SELECT
    fl.fleet_code,
    m.do_num,
    ROUND((-0.85::double precision + fl.rn::double precision * 0.035 + SIN(times.seq::double precision / 3.0 + fl.rn::double precision) * 0.12)::numeric, 7) AS lat,
    ROUND((117.05::double precision + fl.rn::double precision * 0.025 + COS(times.seq::double precision / 4.0 + fl.rn::double precision) * 0.18)::numeric, 7) AS "long",
    times.ts + INTERVAL '12 hour',
    CASE WHEN m.do_num IS NULL THEN 'ACTIVE' ELSE 'IN_PROGRESS' END
FROM fl
CROSS JOIN times
LEFT JOIN LATERAL (
    SELECT si.do_num
    FROM operational.shipment_instruction si
    JOIN commercial.delivery_order d
        ON d.do_num = si.do_num
    WHERE
        (
            si.fleet_main_code = fl.fleet_code
            OR si.fleet_assist_code = fl.fleet_code
        )
        AND times.ts::date BETWEEN d.target_start_date AND d.target_end_date
    ORDER BY d.target_start_date
    LIMIT 1
) m ON TRUE;

WITH fl AS (
    SELECT
        fleet_code,
        (row_number() OVER (ORDER BY fleet_code))::int AS rn
    FROM fleet.info
),
times AS (
    SELECT
        g.gs AS ts,
        (row_number() OVER (ORDER BY g.gs))::int AS seq
    FROM generate_series(
        CURRENT_DATE::timestamp,
        ((CURRENT_DATE + INTERVAL '1 year')::date)::timestamp,
        INTERVAL '1 day'
    ) AS g(gs)
)
INSERT INTO voyage.voyage_hist
    (
        fleet_code,
        lat,
        "long",
        record_time
    )
SELECT
    fl.fleet_code,
    ROUND((-0.90::double precision + fl.rn::double precision * 0.040 + SIN(times.seq::double precision / 10.0 + fl.rn::double precision) * 0.18)::numeric, 7) AS lat,
    ROUND((116.85::double precision + fl.rn::double precision * 0.035 + COS(times.seq::double precision / 11.0 + fl.rn::double precision) * 0.25)::numeric, 7) AS "long",
    times.ts + INTERVAL '12 hour'
FROM fl
CROSS JOIN times;

COMMIT;


-- ============================================================
-- QUICK CHECK
-- ============================================================

SELECT *
FROM (
    SELECT 'commercial.purchase_order' AS tabel, COUNT(*) AS jumlah FROM commercial.purchase_order
    UNION ALL
    SELECT 'commercial.delivery_order', COUNT(*) FROM commercial.delivery_order
    UNION ALL
    SELECT 'operational.shipment_instruction', COUNT(*) FROM operational.shipment_instruction
    UNION ALL
    SELECT 'operational.work_activity', COUNT(*) FROM operational.work_activity
    UNION ALL
    SELECT 'operational.dredging_records', COUNT(*) FROM operational.dredging_records
    UNION ALL
    SELECT 'enviro.water_quality', COUNT(*) FROM enviro.water_quality
    UNION ALL
    SELECT 'enviro.tide_reading', COUNT(*) FROM enviro.tide_reading
    UNION ALL
    SELECT 'enviro.buoy_reading', COUNT(*) FROM enviro.buoy_reading
    UNION ALL
    SELECT 'voyage.voyage', COUNT(*) FROM voyage.voyage
    UNION ALL
    SELECT 'voyage.voyage_hist', COUNT(*) FROM voyage.voyage_hist
    UNION ALL
    SELECT 'form.water_sampling', COUNT(*) FROM form.water_sampling
    UNION ALL
    SELECT 'survey.water_sampling', COUNT(*) FROM survey.water_sampling
) x
ORDER BY tabel;