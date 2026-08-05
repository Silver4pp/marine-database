BEGIN;

-- ============================================================
-- 0. PERIODE DUMMY DATA
-- ============================================================
-- Default: 1 tahun terakhir hingga hari ini.
-- Untuk 1 tahun ke depan:
-- ganti v_start_date := CURRENT_DATE;
-- ganti v_end_date   := CURRENT_DATE + INTERVAL '1 year';

CREATE TEMP TABLE tmp_dummy_period (
    start_date DATE NOT NULL,
    end_date   DATE NOT NULL
) ON COMMIT DROP;

INSERT INTO tmp_dummy_period (start_date, end_date)
VALUES (
    (CURRENT_DATE - INTERVAL '1 year')::DATE,
    CURRENT_DATE
);


-- ============================================================
-- 1. MASTER PARAMETER
-- ============================================================

INSERT INTO param.country (
    iso_alpha2,
    iso_alpha3,
    iso_name,
    iso_numeric,
    name
)
VALUES
    ('ID', 'IDN', 'Indonesia', 360, 'Indonesia'),
    ('SG', 'SGP', 'Singapore', 702, 'Singapore'),
    ('MY', 'MYS', 'Malaysia', 458, 'Malaysia')
ON CONFLICT DO NOTHING;


INSERT INTO param.currency (
    currency_code,
    name,
    symbol
)
VALUES
    ('IDR', 'Indonesian Rupiah', 'Rp'),
    ('USD', 'United States Dollar', '$')
ON CONFLICT DO NOTHING;


INSERT INTO param.unit_of_measure (
    uom_code,
    name,
    category,
    symbol
)
VALUES
    ('M3', 'Cubic Meter', 'VOLUME', 'm3'),
    ('MT', 'Metric Ton', 'MASS', 'MT'),
    ('M', 'Meter', 'LENGTH', 'm'),
    ('CEL', 'Celsius', 'TEMPERATURE', '°C'),
    ('NTU', 'Nephelometric Turbidity Unit', 'OTHER', 'NTU'),
    ('MG_L', 'Milligram per Liter', 'OTHER', 'mg/L'),
    ('PSU', 'Practical Salinity Unit', 'OTHER', 'PSU'),
    ('MPS', 'Meter per Second', 'OTHER', 'm/s')
ON CONFLICT DO NOTHING;


INSERT INTO param.unit_conversion (
    uc_code,
    uom_from,
    uom_to,
    conv_value
)
VALUES
    ('M3_TO_MT', 'M3', 'MT', 1.25)
ON CONFLICT DO NOTHING;


INSERT INTO param.status (
    status_code,
    status_group,
    description
)
VALUES
    ('DRAFT', 'DOCUMENT', 'Draft document'),
    ('SUBMITTED', 'DOCUMENT', 'Submitted document'),
    ('APPROVED', 'DOCUMENT', 'Approved document'),
    ('REJECTED', 'DOCUMENT', 'Rejected document'),
    ('OPEN', 'OPERATIONAL', 'Open activity'),
    ('IN_PROGRESS', 'OPERATIONAL', 'Activity in progress'),
    ('COMPLETED', 'OPERATIONAL', 'Completed activity'),
    ('CANCELLED', 'OPERATIONAL', 'Cancelled activity'),
    ('ACTIVE', 'GENERAL', 'Active'),
    ('INACTIVE', 'GENERAL', 'Inactive'),
    ('VALID', 'LABORATORY', 'Valid result')
ON CONFLICT DO NOTHING;


-- ============================================================
-- 2. SITE, USER, PARTNER, BUYER, FLEET MASTER
-- ============================================================

INSERT INTO site.type (
    type_code,
    type_group,
    description
)
VALUES
    ('PORT', 'MARITIME', 'Port'),
    ('JETTY', 'MARITIME', 'Jetty'),
    ('WORKSITE', 'OPERATIONAL', 'Operational work site'),
    ('WAREHOUSE', 'LOGISTIC', 'Warehouse')
ON CONFLICT DO NOTHING;


INSERT INTO site.info (
    site_code,
    type_code,
    name,
    address,
    city,
    lat,
    long
)
VALUES
    (
        'SITE-JKT',
        'PORT',
        'Jakarta Port',
        'Tanjung Priok',
        'Jakarta',
        -6.1045000,
        106.8801000
    ),
    (
        'SITE-SBY',
        'PORT',
        'Surabaya Port',
        'Tanjung Perak',
        'Surabaya',
        -7.2050000,
        112.7360000
    ),
    (
        'SITE-BPN',
        'JETTY',
        'Balikpapan Jetty',
        'Kariangau',
        'Balikpapan',
        -1.2350000,
        116.8270000
    ),
    (
        'SITE-BAT',
        'JETTY',
        'Batam Jetty',
        'Batu Ampar',
        'Batam',
        1.1450000,
        104.0100000
    )
ON CONFLICT DO NOTHING;


INSERT INTO "user".info (
    user_code,
    name,
    role
)
VALUES
    ('USR-ADMIN', 'System Administrator', 'ADMIN'),
    ('USR-OPS01', 'Operations Officer', 'OPERATION'),
    ('USR-SURV01', 'Survey Officer', 'SURVEYOR'),
    ('USR-LAB01', 'Laboratory Analyst', 'LAB_ANALYST')
ON CONFLICT DO NOTHING;


INSERT INTO "user".detail (
    user_code,
    contact_type,
    contact_value,
    is_primary
)
VALUES
    ('USR-ADMIN', 'EMAIL', 'admin@dummy.local', TRUE),
    ('USR-OPS01', 'EMAIL', 'ops01@dummy.local', TRUE),
    ('USR-SURV01', 'EMAIL', 'surveyor@dummy.local', TRUE),
    ('USR-LAB01', 'EMAIL', 'lab@dummy.local', TRUE)
ON CONFLICT DO NOTHING;


INSERT INTO partner.type (
    type_code,
    description
)
VALUES
    ('VESSEL_OWNER', 'Vessel owner'),
    ('VESSEL_OPERATOR', 'Vessel operator')
ON CONFLICT DO NOTHING;


INSERT INTO partner.info (
    partner_code,
    type_code,
    name,
    site_code
)
VALUES
    ('PTR-001', 'VESSEL_OWNER', 'PT Ocean Marine Indonesia', 'SITE-JKT'),
    ('PTR-002', 'VESSEL_OPERATOR', 'PT Nusantara Maritime', 'SITE-SBY')
ON CONFLICT DO NOTHING;


INSERT INTO buyer.info (
    buyer_code,
    name,
    site_code
)
VALUES
    ('BUY-001', 'PT Buyer Jakarta', 'SITE-JKT'),
    ('BUY-002', 'PT Buyer Surabaya', 'SITE-SBY')
ON CONFLICT DO NOTHING;


INSERT INTO buyer.site (
    buyer_code,
    name,
    site_code
)
VALUES
    ('BUY-001', 'Buyer Jakarta Discharge Site', 'SITE-JKT'),
    ('BUY-002', 'Buyer Surabaya Discharge Site', 'SITE-SBY')
ON CONFLICT DO NOTHING;


INSERT INTO fleet.type (
    type_code,
    description
)
VALUES
    ('DREDGER', 'Dredger Vessel'),
    ('TUG', 'Tug Boat'),
    ('BARGE', 'Barge')
ON CONFLICT DO NOTHING;


INSERT INTO fleet.info (
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
    x.fleet_code,
    x.partner_code,
    x.type_code,
    x.name,
    x.imo_number,
    x.mmsi_number,
    x.call_sign,
    c.country_id,
    x.grt,
    x.dwt
FROM (
    VALUES
        (
            'FLT-DRG01',
            'PTR-001',
            'DREDGER',
            'Dredger Alpha',
            'IMO9000001',
            '525900001',
            'DRA001',
            3200::NUMERIC,
            5000::NUMERIC
        ),
        (
            'FLT-TUG01',
            'PTR-002',
            'TUG',
            'Tug Boat Bravo',
            'IMO9000002',
            '525900002',
            'TUG001',
            850::NUMERIC,
            2100::NUMERIC
        ),
        (
            'FLT-BRG01',
            'PTR-002',
            'BARGE',
            'Barge Charlie',
            'IMO9000003',
            '525900003',
            'BRG001',
            1500::NUMERIC,
            9000::NUMERIC
        )
) AS x (
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
CROSS JOIN LATERAL (
    SELECT country_id
    FROM param.country
    WHERE iso_alpha2 = 'ID'
    LIMIT 1
) c
ON CONFLICT DO NOTHING;


-- ============================================================
-- 3. OPERATIONAL WORK AREA
-- ============================================================

INSERT INTO operational.work_area (
    area_code,
    name,
    geom
)
VALUES
    (
        'AREA-JKT-01',
        'Jakarta Dredging Area',
        ST_GeomFromText(
            'POLYGON((
                106.8700 -6.1000,
                106.8950 -6.1000,
                106.8950 -6.1200,
                106.8700 -6.1200,
                106.8700 -6.1000
            ))',
            4326
        )
    ),
    (
        'AREA-SBY-01',
        'Surabaya Dredging Area',
        ST_GeomFromText(
            'POLYGON((
                112.7200 -7.1950,
                112.7500 -7.1950,
                112.7500 -7.2150,
                112.7200 -7.2150,
                112.7200 -7.1950
            ))',
            4326
        )
    )
ON CONFLICT DO NOTHING;


-- ============================================================
-- 4. ENVIRONMENT STATION DAN LABORATORY
-- ============================================================

INSERT INTO enviro.station (
    station_code,
    site_code,
    station_type,
    status
)
VALUES
    ('STN-JKT-TIDE', 'SITE-JKT', 'TIDE', 'ACTIVE'),
    ('STN-JKT-BUOY', 'SITE-JKT', 'BUOY', 'ACTIVE'),
    ('STN-SBY-TIDE', 'SITE-SBY', 'TIDE', 'ACTIVE'),
    ('STN-SBY-BUOY', 'SITE-SBY', 'BUOY', 'ACTIVE')
ON CONFLICT DO NOTHING;


INSERT INTO laboratory.info (
    lab_code,
    site_code
)
VALUES
    ('LAB-JKT', 'SITE-JKT'),
    ('LAB-SBY', 'SITE-SBY')
ON CONFLICT DO NOTHING;


-- ============================================================
-- 5. FLEET MAINTENANCE
-- ============================================================

INSERT INTO fleet.maintenance (
    fleet_code,
    description,
    start_date,
    end_date
)
SELECT
    'FLT-DRG01',
    'Annual dredger maintenance',
    p.start_date + INTERVAL '90 days',
    p.start_date + INTERVAL '95 days'
FROM tmp_dummy_period p
WHERE NOT EXISTS (
    SELECT 1
    FROM fleet.maintenance fm
    WHERE fm.fleet_code = 'FLT-DRG01'
      AND fm.description = 'Annual dredger maintenance'
);


-- ============================================================
-- 6. BUYER LEDGER
-- 1 transaksi per bulan per buyer
-- ============================================================

INSERT INTO buyer.ledger_hist (
    buyer_code,
    transaction_date,
    transaction_type,
    amount,
    ref_doc,
    description
)
SELECT
    b.buyer_code,
    m.month_date::DATE,
    CASE
        WHEN EXTRACT(MONTH FROM m.month_date)::INT % 2 = 0 THEN 'DEBIT'
        ELSE 'CREDIT'
    END,
    (
        50000000
        + EXTRACT(MONTH FROM m.month_date)::NUMERIC * 5000000
    )::NUMERIC(18,2),
    'LEDGER-' || b.buyer_code || '-' || TO_CHAR(m.month_date, 'YYYYMM'),
    'Monthly dummy ledger transaction'
FROM buyer.info b
CROSS JOIN LATERAL (
    SELECT generate_series(
        date_trunc('month', p.start_date::TIMESTAMP),
        date_trunc('month', p.end_date::TIMESTAMP),
        INTERVAL '1 month'
    ) AS month_date
    FROM tmp_dummy_period p
) m
ON CONFLICT DO NOTHING;


-- ============================================================
-- 7. PURCHASE ORDER DAN DELIVERY ORDER
-- 1 PO dan 1 DO per bulan
-- ============================================================

INSERT INTO commercial.purchase_order (
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
    created_by,
    approved_by,
    description
)
SELECT
    'PO-OPS-' || TO_CHAR(m.month_date, 'YYYYMM'),
    CASE
        WHEN EXTRACT(MONTH FROM m.month_date)::INT % 2 = 0 THEN 'BUY-002'
        ELSE 'BUY-001'
    END,
    'CTR-' || TO_CHAR(m.month_date, 'YYYY'),
    m.month_date::DATE,
    'M3',
    1500.0000,
    175000.0000,
    'IDR',
    'FOB',
    m.month_date::DATE,
    (m.month_date + INTERVAL '10 days')::DATE,
    CASE
        WHEN m.month_date < date_trunc('month', CURRENT_DATE) THEN 'COMPLETED'
        ELSE 'IN_PROGRESS'
    END,
    'USR-OPS01',
    'USR-ADMIN',
    'Monthly dredging purchase order'
FROM (
    SELECT generate_series(
        date_trunc('month', p.start_date::TIMESTAMP),
        date_trunc('month', p.end_date::TIMESTAMP),
        INTERVAL '1 month'
    ) AS month_date
    FROM tmp_dummy_period p
) m
ON CONFLICT (po_num) DO NOTHING;


INSERT INTO commercial.delivery_order (
    do_num,
    po_num,
    discharge_site,
    target_volume,
    target_start_date,
    target_end_date,
    status,
    actual_start_date,
    actual_end_date
)
SELECT
    'DO-OPS-' || TO_CHAR(po.po_date, 'YYYYMM'),
    po.po_num,
    CASE
        WHEN po.buyer_code = 'BUY-001' THEN 'SITE-JKT'
        ELSE 'SITE-SBY'
    END,
    po.total_volume,
    po.target_start_date,
    po.target_end_date,
    po.status,
    CASE
        WHEN po.status = 'COMPLETED' THEN po.target_start_date
        ELSE NULL
    END,
    CASE
        WHEN po.status = 'COMPLETED' THEN po.target_end_date
        ELSE NULL
    END
FROM commercial.purchase_order po
WHERE po.po_num LIKE 'PO-OPS-%'
ON CONFLICT (do_num) DO NOTHING;


-- ============================================================
-- 8. FLEET ASSIGNMENT
-- Per DO = 1 assignment 10 hari.
-- Tidak overlap karena hanya menggunakan 1 dredger dan tiap bulan.
-- ============================================================

INSERT INTO fleet.assignment_leg (
    fleet_code,
    site_code,
    est_start_date,
    est_end_date,
    act_start_date,
    act_end_date
)
SELECT
    'FLT-DRG01',
    d_o.discharge_site,
    d_o.target_start_date,
    d_o.target_end_date,
    d_o.actual_start_date,
    d_o.actual_end_date
FROM commercial.delivery_order d_o
WHERE d_o.do_num LIKE 'DO-OPS-%'
  AND NOT EXISTS (
      SELECT 1
      FROM fleet.assignment_leg fa
      WHERE fa.fleet_code = 'FLT-DRG01'
        AND fa.est_start_date = d_o.target_start_date
  );


-- ============================================================
-- 9. SHIPMENT INSTRUCTION
-- 1 SI untuk setiap Delivery Order
-- ============================================================

INSERT INTO operational.shipment_instruction (
    si_num,
    do_num,
    fleet_main_code,
    fleet_assist_code,
    working_site,
    discharge_site,
    status
)
SELECT
    'SI-' || d_o.do_num,
    d_o.do_num,
    'FLT-DRG01',
    'FLT-TUG01',
    CASE
        WHEN d_o.discharge_site = 'SITE-JKT' THEN 'AREA-JKT-01'
        ELSE 'AREA-SBY-01'
    END,
    d_o.discharge_site,
    d_o.status
FROM commercial.delivery_order d_o
WHERE d_o.do_num LIKE 'DO-OPS-%'
ON CONFLICT (si_num) DO NOTHING;


-- ============================================================
-- 10. WORK ACTIVITY
-- 10 aktivitas dredging per SI / DO.
-- ============================================================

INSERT INTO operational.work_activity (
    si_num,
    fleet_code,
    area_code,
    activity_type,
    planned_start,
    planned_end,
    status,
    actual_start,
    actual_end
)
SELECT
    si.si_num,
    si.fleet_main_code,
    si.working_site,
    'DREDGING',
    (d_o.target_start_date + (gs.day_no - 1) + TIME '08:00')::TIMESTAMPTZ,
    (d_o.target_start_date + (gs.day_no - 1) + TIME '17:00')::TIMESTAMPTZ,
    CASE
        WHEN d_o.status = 'COMPLETED' THEN 'COMPLETED'
        ELSE 'IN_PROGRESS'
    END,
    CASE
        WHEN d_o.status = 'COMPLETED'
            THEN (d_o.target_start_date + (gs.day_no - 1) + TIME '08:00')::TIMESTAMPTZ
        ELSE NULL
    END,
    CASE
        WHEN d_o.status = 'COMPLETED'
            THEN (d_o.target_start_date + (gs.day_no - 1) + TIME '17:00')::TIMESTAMPTZ
        ELSE NULL
    END
FROM operational.shipment_instruction si
JOIN commercial.delivery_order d_o
    ON d_o.do_num = si.do_num
CROSS JOIN generate_series(1, 10) AS gs(day_no)
WHERE NOT EXISTS (
    SELECT 1
    FROM operational.work_activity wa
    WHERE wa.si_num = si.si_num
      AND wa.activity_type = 'DREDGING'
      AND wa.planned_start =
          (d_o.target_start_date + (gs.day_no - 1) + TIME '08:00')::TIMESTAMPTZ
);


-- ============================================================
-- 11. DREDGING RECORD
-- Volume per activity = 100 M3
-- 10 hari x 100 M3 = 1.000 M3.
-- Target DO = 1.500 M3 sehingga tidak melebihi target.
-- ============================================================

INSERT INTO operational.dredging_records (
    form_no,
    si_num,
    activity_num,
    record_date,
    dredging_volume,
    uom_code,
    created_by,
    notes
)
SELECT
    'DRG-FORM-' || TO_CHAR(wa.planned_start::DATE, 'YYYYMMDD'),
    wa.si_num,
    wa.activity_num,
    wa.planned_start::DATE,
    100.0000,
    'M3',
    'USR-OPS01',
    'Daily dredging production dummy data'
FROM operational.work_activity wa
WHERE wa.activity_type = 'DREDGING'
ON CONFLICT (activity_num, record_date) DO NOTHING;


-- ============================================================
-- 12. FORM: WATER SAMPLING
-- Tabel ini berdiri sendiri.
-- Dibuat setiap hari Senin selama 1 tahun.
-- ============================================================

INSERT INTO form.water_sampling (
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
    'WS-FORM-' || TO_CHAR(d.read_date, 'YYYYMMDD'),
    d.read_date,
    3,
    'USR-SURV01',
    'USR-LAB01',
    CASE
        WHEN d.read_date < CURRENT_DATE - INTERVAL '7 days' THEN 'COMPLETED'
        ELSE 'SUBMITTED'
    END,
    'Operational water sampling area',
    CASE
        WHEN EXTRACT(MONTH FROM d.read_date)::INT IN (11, 12, 1, 2, 3)
            THEN 'RAINY'
        ELSE 'SUNNY'
    END
FROM (
    SELECT gs::DATE AS read_date
    FROM tmp_dummy_period p
    CROSS JOIN generate_series(
        p.start_date,
        p.end_date,
        INTERVAL '1 day'
    ) gs
    WHERE EXTRACT(DOW FROM gs) = 1
) d
ON CONFLICT (form_no) DO NOTHING;


-- ============================================================
-- 13. FORM: SAMPLE
-- Berdiri sendiri; form_no hanya logical reference.
-- Tidak memiliki FK ke form.water_sampling.
-- ============================================================

INSERT INTO form.sample (
    form_no,
    sample_no,
    type_sample,
    description,
    status
)
SELECT
    ws.form_no,
    s.sample_no,
    CASE s.sample_no
        WHEN 1 THEN 'SURFACE'
        WHEN 2 THEN 'MID_DEPTH'
        ELSE 'BOTTOM'
    END,
    'Independent sample record no. ' || s.sample_no,
    ws.status
FROM form.water_sampling ws
CROSS JOIN generate_series(1, 3) AS s(sample_no)
ON CONFLICT (form_no, sample_no) DO NOTHING;


-- ============================================================
-- 14. FORM: MEASUREMENT
-- Berdiri sendiri; form_no dan sample_id bukan FK.
-- ============================================================

INSERT INTO form.measurement (
    form_no,
    sample_id,
    parameter_name,
    parameter_value,
    uom_code,
    method,
    status
)
SELECT
    fs.form_no,
    fs.sample_id,
    prm.parameter_name,
    prm.parameter_value,
    prm.uom_code,
    'FIELD_TEST',
    'VALID'
FROM form.sample fs
CROSS JOIN LATERAL (
    VALUES
        (
            'TEMPERATURE'::VARCHAR,
            ROUND((27.0 + RANDOM() * 5.0)::NUMERIC, 2),
            'CEL'::VARCHAR
        ),
        (
            'TURBIDITY'::VARCHAR,
            ROUND((5.0 + RANDOM() * 30.0)::NUMERIC, 2),
            'NTU'::VARCHAR
        ),
        (
            'DISSOLVED_OXYGEN'::VARCHAR,
            ROUND((4.0 + RANDOM() * 4.0)::NUMERIC, 2),
            'MG_L'::VARCHAR
        )
) AS prm(parameter_name, parameter_value, uom_code)
WHERE fs.form_no LIKE 'WS-FORM-%'
ON CONFLICT (form_no, sample_id, parameter_name) DO NOTHING;


-- ============================================================
-- 15. LABORATORY RESULT
-- ============================================================

INSERT INTO laboratory.result (
    doc_no,
    lab_code,
    sample_id
)
SELECT
    'LAB-RES-' || LPAD(fs.sample_id::TEXT, 8, '0'),
    CASE
        WHEN fs.sample_id % 2 = 0 THEN 'LAB-JKT'
        ELSE 'LAB-SBY'
    END,
    fs.sample_id
FROM form.sample fs
WHERE fs.form_no LIKE 'WS-FORM-%'
  AND NOT EXISTS (
      SELECT 1
      FROM laboratory.result lr
      WHERE lr.doc_no = 'LAB-RES-' || LPAD(fs.sample_id::TEXT, 8, '0')
  );


-- ============================================================
-- 16. ENVIRO WATER QUALITY
-- Harian untuk seluruh station.
-- ============================================================

INSERT INTO enviro.water_quality (
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
    st.station_code,
    (d.read_date + TIME '12:00')::TIMESTAMPTZ,
    ROUND((2 + RANDOM() * 10)::NUMERIC, 2),
    ROUND((3 + RANDOM() * 7)::NUMERIC, 2),
    ROUND((27 + RANDOM() * 5)::NUMERIC, 2),
    ROUND((5 + RANDOM() * 30)::NUMERIC, 2),
    ROUND((4 + RANDOM() * 4)::NUMERIC, 2),
    ROUND((6.8 + RANDOM() * 1.0)::NUMERIC, 2),
    ROUND((25 + RANDOM() * 8)::NUMERIC, 2),
    CASE
        WHEN RANDOM() < 0.85 THEN 'GOOD'
        WHEN RANDOM() < 0.95 THEN 'WARNING'
        ELSE 'BAD'
    END
FROM enviro.station st
CROSS JOIN LATERAL (
    SELECT gs::DATE AS read_date
    FROM tmp_dummy_period p
    CROSS JOIN generate_series(
        p.start_date,
        p.end_date,
        INTERVAL '1 day'
    ) gs
) d
ON CONFLICT (station_code, record_time) DO NOTHING;


-- ============================================================
-- 17. ENVIRONMENT TIDE READING
-- Dibuat setiap 6 jam untuk station TIDE.
-- ============================================================

INSERT INTO enviro.tide_reading (
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
    ts.record_time,
    ROUND((28 + RANDOM() * 5)::NUMERIC, 2),
    ROUND((5 + RANDOM() * 25)::NUMERIC, 2),
    ROUND((0.2 + RANDOM() * 1.8)::NUMERIC, 2),
    ROUND((4 + RANDOM() * 4)::NUMERIC, 2),
    ROUND((1.020 + RANDOM() * 0.010)::NUMERIC, 4),
    ROUND((
        0.5
        + 1.5 * SIN(EXTRACT(EPOCH FROM ts.record_time) / 43200)
        + RANDOM() * 0.2
    )::NUMERIC, 2)
FROM enviro.station st
CROSS JOIN LATERAL (
    SELECT gs::TIMESTAMPTZ AS record_time
    FROM tmp_dummy_period p
    CROSS JOIN generate_series(
        p.start_date::TIMESTAMPTZ,
        p.end_date::TIMESTAMPTZ,
        INTERVAL '6 hours'
    ) gs
) ts
WHERE st.station_type = 'TIDE'
ON CONFLICT (station_code, record_time) DO NOTHING;


-- ============================================================
-- 18. ENVIRONMENT BUOY READING
-- Dibuat setiap 6 jam untuk station BUOY.
-- ============================================================

INSERT INTO enviro.buoy_reading (
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
    ts.record_time,
    ROUND((28 + RANDOM() * 5)::NUMERIC, 2),
    ROUND((5 + RANDOM() * 25)::NUMERIC, 2),
    ROUND((0.2 + RANDOM() * 1.8)::NUMERIC, 2),
    ROUND((4 + RANDOM() * 4)::NUMERIC, 2),
    ROUND((1.020 + RANDOM() * 0.010)::NUMERIC, 4),
    ROUND((
        0.5
        + 1.5 * SIN(EXTRACT(EPOCH FROM ts.record_time) / 43200)
        + RANDOM() * 0.2
    )::NUMERIC, 2)
FROM enviro.station st
CROSS JOIN LATERAL (
    SELECT gs::TIMESTAMPTZ AS record_time
    FROM tmp_dummy_period p
    CROSS JOIN generate_series(
        p.start_date::TIMESTAMPTZ,
        p.end_date::TIMESTAMPTZ,
        INTERVAL '6 hours'
    ) gs
) ts
WHERE st.station_type = 'BUOY'
ON CONFLICT (station_code, record_time) DO NOTHING;


-- ============================================================
-- 19. VOYAGE HISTORY
-- 1 posisi per hari per fleet.
-- ============================================================

INSERT INTO voyage.voyage_hist (
    fleet_code,
    lat,
    long,
    record_time
)
SELECT
    f.fleet_code,
    CASE f.fleet_code
        WHEN 'FLT-DRG01'
            THEN -6.1045 + SIN(EXTRACT(EPOCH FROM d.record_time) / 86400) * 0.020
        WHEN 'FLT-TUG01'
            THEN -7.2050 + SIN(EXTRACT(EPOCH FROM d.record_time) / 86400) * 0.020
        ELSE -1.2350 + SIN(EXTRACT(EPOCH FROM d.record_time) / 86400) * 0.020
    END,
    CASE f.fleet_code
        WHEN 'FLT-DRG01'
            THEN 106.8801 + COS(EXTRACT(EPOCH FROM d.record_time) / 86400) * 0.020
        WHEN 'FLT-TUG01'
            THEN 112.7360 + COS(EXTRACT(EPOCH FROM d.record_time) / 86400) * 0.020
        ELSE 116.8270 + COS(EXTRACT(EPOCH FROM d.record_time) / 86400) * 0.020
    END,
    d.record_time
FROM fleet.info f
CROSS JOIN LATERAL (
    SELECT (gs::DATE + TIME '10:00')::TIMESTAMPTZ AS record_time
    FROM tmp_dummy_period p
    CROSS JOIN generate_series(
        p.start_date,
        p.end_date,
        INTERVAL '1 day'
    ) gs
) d
ON CONFLICT (fleet_code, record_time) DO NOTHING;


-- ============================================================
-- 20. VOYAGE CURRENT
-- Hanya 1 posisi terbaru untuk setiap fleet.
-- ============================================================

INSERT INTO voyage.voyage (
    fleet_code,
    do_num,
    lat,
    long,
    record_time,
    status
)
SELECT
    f.fleet_code,
    NULL,
    CASE f.fleet_code
        WHEN 'FLT-DRG01' THEN -6.1045
        WHEN 'FLT-TUG01' THEN -7.2050
        ELSE -1.2350
    END,
    CASE f.fleet_code
        WHEN 'FLT-DRG01' THEN 106.8801
        WHEN 'FLT-TUG01' THEN 112.7360
        ELSE 116.8270
    END,
    now(),
    'IN_PROGRESS'
FROM fleet.info f
WHERE NOT EXISTS (
    SELECT 1
    FROM voyage.voyage v
    WHERE v.fleet_code = f.fleet_code
);


-- ============================================================
-- 21. UPDATE DATABASE STATISTICS
-- ============================================================

ANALYZE buyer.ledger_hist;
ANALYZE fleet.assignment_leg;
ANALYZE fleet.maintenance;
ANALYZE commercial.purchase_order;
ANALYZE commercial.delivery_order;
ANALYZE operational.shipment_instruction;
ANALYZE operational.work_activity;
ANALYZE operational.dredging_records;
ANALYZE form.water_sampling;
ANALYZE form.sample;
ANALYZE form.measurement;
ANALYZE laboratory.result;
ANALYZE enviro.water_quality;
ANALYZE enviro.tide_reading;
ANALYZE enviro.buoy_reading;
ANALYZE voyage.voyage;
ANALYZE voyage.voyage_hist;

COMMIT;