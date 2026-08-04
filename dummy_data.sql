BEGIN;

-- ============================================================
-- PARAMETER DUMMY
-- ============================================================
CREATE TEMP TABLE tmp_dummy_period (
    start_date DATE NOT NULL,
    end_date   DATE NOT NULL
) ON COMMIT DROP;

INSERT INTO tmp_dummy_period
VALUES (
    CURRENT_DATE - INTERVAL '1 year',
    CURRENT_DATE
);


-- ============================================================
-- 1. PARAMETER / MASTER DATA
-- ============================================================

INSERT INTO param.country (
    iso_alpha2, iso_alpha3, iso_name, iso_numeric, name
)
VALUES
    ('ID', 'IDN', 'Indonesia', 360, 'Indonesia'),
    ('SG', 'SGP', 'Singapore', 702, 'Singapore'),
    ('MY', 'MYS', 'Malaysia', 458, 'Malaysia')
ON CONFLICT DO NOTHING;

INSERT INTO param.currency (
    currency_code, name, symbol
)
VALUES
    ('IDR', 'Indonesian Rupiah', 'Rp'),
    ('USD', 'United States Dollar', '$'),
    ('SGD', 'Singapore Dollar', 'S$')
ON CONFLICT DO NOTHING;

INSERT INTO param.unit_of_measure (
    uom_code, name, category, symbol
)
VALUES
    ('M3', 'Cubic Meter', 'VOLUME', 'm³'),
    ('MT', 'Metric Ton', 'MASS', 'ton'),
    ('M', 'Meter', 'LENGTH', 'm'),
    ('CM', 'Centimeter', 'LENGTH', 'cm'),
    ('CEL', 'Celsius', 'TEMPERATURE', '°C'),
    ('PSU', 'Practical Salinity Unit', 'OTHER', 'PSU'),
    ('NTU', 'Nephelometric Turbidity Unit', 'OTHER', 'NTU'),
    ('MPS', 'Meter Per Second', 'OTHER', 'm/s'),
    ('PPT', 'Parts Per Thousand', 'OTHER', 'ppt'),
    ('MG_L', 'Milligram Per Liter', 'OTHER', 'mg/L')
ON CONFLICT DO NOTHING;

INSERT INTO param.unit_conversion (
    uc_code, uom_from, uom_to, conv_value
)
VALUES
    ('M3_TO_LITER', 'M3', 'M', 1000)
ON CONFLICT DO NOTHING;

INSERT INTO param.status (
    status_code, status_group, description
)
VALUES
    ('ACTIVE', 'GENERAL', 'Active'),
    ('INACTIVE', 'GENERAL', 'Inactive'),
    ('DRAFT', 'DOCUMENT', 'Draft'),
    ('SUBMITTED', 'DOCUMENT', 'Submitted'),
    ('APPROVED', 'DOCUMENT', 'Approved'),
    ('REJECTED', 'DOCUMENT', 'Rejected'),
    ('OPEN', 'OPERATIONAL', 'Open'),
    ('IN_PROGRESS', 'OPERATIONAL', 'In Progress'),
    ('COMPLETED', 'OPERATIONAL', 'Completed'),
    ('CANCELLED', 'OPERATIONAL', 'Cancelled'),
    ('MAINTENANCE', 'FLEET', 'Under Maintenance'),
    ('VALID', 'LABORATORY', 'Valid'),
    ('INVALID', 'LABORATORY', 'Invalid')
ON CONFLICT DO NOTHING;

INSERT INTO param.threshold (
    threshold_code, parameter_name, parameter_value, uom_code
)
VALUES
    ('THR_TEMP_MAX', 'WATER_TEMPERATURE_MAX', 35, 'CEL'),
    ('THR_TURB_MAX', 'WATER_TURBIDITY_MAX', 50, 'NTU'),
    ('THR_PH_MIN', 'WATER_PH_MIN', 6.5, 'M'),
    ('THR_PH_MAX', 'WATER_PH_MAX', 8.5, 'M'),
    ('THR_DO_MIN', 'DISSOLVED_OXYGEN_MIN', 4, 'MG_L')
ON CONFLICT DO NOTHING;


-- ============================================================
-- 2. SITE MASTER
-- ============================================================

INSERT INTO site.type (
    type_code, type_group, description
)
VALUES
    ('PORT', 'MARITIME', 'Port'),
    ('JETTY', 'MARITIME', 'Jetty'),
    ('WAREHOUSE', 'LOGISTICS', 'Warehouse'),
    ('OFFICE', 'GENERAL', 'Office'),
    ('WORKSITE', 'OPERATIONAL', 'Operational Work Site')
ON CONFLICT DO NOTHING;

INSERT INTO site.info (
    site_code, type_code, name, address, city, lat, long
)
VALUES
    ('SITE-JKT', 'PORT', 'Jakarta Port', 'Tanjung Priok', 'Jakarta',
     -6.1045, 106.8801),

    ('SITE-SBY', 'PORT', 'Surabaya Port', 'Tanjung Perak', 'Surabaya',
     -7.2050, 112.7360),

    ('SITE-BPN', 'JETTY', 'Balikpapan Jetty', 'Kariangau', 'Balikpapan',
     -1.2350, 116.8270),

    ('SITE-BAT', 'JETTY', 'Batam Jetty', 'Batu Ampar', 'Batam',
     1.1450, 104.0100),

    ('SITE-WH1', 'WAREHOUSE', 'Main Warehouse', 'Cakung', 'Jakarta',
     -6.1850, 106.9500)
ON CONFLICT DO NOTHING;


-- ============================================================
-- 3. USER MASTER
-- ============================================================

INSERT INTO "user".info (
    user_code, name, role
)
VALUES
    ('USR-ADMIN', 'System Administrator', 'ADMIN'),
    ('USR-OPS01', 'Operations Officer 01', 'OPERATION'),
    ('USR-OPS02', 'Operations Officer 02', 'OPERATION'),
    ('USR-HSE01', 'HSE Officer 01', 'HSE'),
    ('USR-LAB01', 'Laboratory Analyst 01', 'LAB_ANALYST'),
    ('USR-FIN01', 'Finance Officer 01', 'FINANCE')
ON CONFLICT DO NOTHING;

INSERT INTO "user".detail (
    user_code, contact_type, contact_value, is_primary
)
VALUES
    ('USR-ADMIN', 'EMAIL', 'admin@example.com', TRUE),
    ('USR-OPS01', 'EMAIL', 'ops01@example.com', TRUE),
    ('USR-OPS02', 'EMAIL', 'ops02@example.com', TRUE),
    ('USR-HSE01', 'EMAIL', 'hse01@example.com', TRUE),
    ('USR-LAB01', 'EMAIL', 'lab01@example.com', TRUE),
    ('USR-FIN01', 'EMAIL', 'finance01@example.com', TRUE)
ON CONFLICT DO NOTHING;


-- ============================================================
-- 4. PARTNER MASTER
-- ============================================================

INSERT INTO partner.type (
    type_code, description
)
VALUES
    ('SHIP_OWNER', 'Ship Owner'),
    ('SHIP_OPERATOR', 'Ship Operator'),
    ('LOGISTICS', 'Logistics Partner'),
    ('LAB_PARTNER', 'Laboratory Partner')
ON CONFLICT DO NOTHING;

INSERT INTO partner.info (
    partner_code, type_code, name, site_code
)
VALUES
    ('PTR-001', 'SHIP_OWNER', 'PT Maritime Owner A', 'SITE-JKT'),
    ('PTR-002', 'SHIP_OPERATOR', 'PT Ocean Operator B', 'SITE-SBY'),
    ('PTR-003', 'LOGISTICS', 'PT Logistics C', 'SITE-BPN'),
    ('PTR-LAB', 'LAB_PARTNER', 'PT Independent Laboratory', 'SITE-JKT')
ON CONFLICT DO NOTHING;


-- ============================================================
-- 5. BUYER MASTER
-- ============================================================

INSERT INTO buyer.info (
    buyer_code, name, site_code
)
VALUES
    ('BUY-001', 'PT Buyer Jakarta', 'SITE-JKT'),
    ('BUY-002', 'PT Buyer Surabaya', 'SITE-SBY'),
    ('BUY-003', 'PT Buyer Balikpapan', 'SITE-BPN')
ON CONFLICT DO NOTHING;

INSERT INTO buyer.site (
    buyer_code, name, site_code
)
VALUES
    ('BUY-001', 'Jakarta Buyer Site', 'SITE-JKT'),
    ('BUY-001', 'Jakarta Warehouse', 'SITE-WH1'),
    ('BUY-002', 'Surabaya Buyer Site', 'SITE-SBY'),
    ('BUY-003', 'Balikpapan Buyer Site', 'SITE-BPN')
ON CONFLICT DO NOTHING;


-- ============================================================
-- 6. FLEET MASTER
-- ============================================================

INSERT INTO fleet.type (
    type_code, description
)
VALUES
    ('TUG', 'Tug Boat'),
    ('BARGE', 'Barge'),
    ('VESSEL', 'General Vessel')
ON CONFLICT DO NOTHING;

INSERT INTO fleet.info (
    fleet_code, partner_code, type_code, name,
    imo_number, mmsi_number, call_sign,
    flag_country_id, grt, dwt
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
        ('FLT-001', 'PTR-001', 'TUG',   'Tug Boat Alpha',
         'IMO0000001', '525000001', 'CALL001', 500, 2000),

        ('FLT-002', 'PTR-002', 'BARGE', 'Barge Beta',
         'IMO0000002', '525000002', 'CALL002', 800, 8000),

        ('FLT-003', 'PTR-003', 'TUG',   'Tug Boat Gamma',
         'IMO0000003', '525000003', 'CALL003', 450, 1800)
) AS x(
    fleet_code, partner_code, type_code, name,
    imo_number, mmsi_number, call_sign, grt, dwt
)
CROSS JOIN LATERAL (
    SELECT country_id
    FROM param.country
    WHERE iso_alpha2 = 'ID'
    LIMIT 1
) c
ON CONFLICT DO NOTHING;


-- ============================================================
-- 7. FLEET MAINTENANCE
-- ============================================================

INSERT INTO fleet.maintenance (
    fleet_code, description, start_date, end_date
)
VALUES
    (
        'FLT-001',
        'Annual engine maintenance',
        CURRENT_DATE - INTERVAL '250 days',
        CURRENT_DATE - INTERVAL '245 days'
    ),
    (
        'FLT-002',
        'Hull inspection and maintenance',
        CURRENT_DATE - INTERVAL '180 days',
        CURRENT_DATE - INTERVAL '170 days'
    ),
    (
        'FLT-003',
        'Navigation system maintenance',
        CURRENT_DATE - INTERVAL '90 days',
        CURRENT_DATE - INTERVAL '87 days'
    )
ON CONFLICT DO NOTHING;


-- ============================================================
-- 8. WORK AREA
-- ============================================================

INSERT INTO operational.work_area (
    area_code, name, geom
)
VALUES
(
    'AREA-JKT-01',
    'Jakarta Loading Area',
    ST_GeomFromText(
        'POLYGON((
            106.8700 -6.1000,
            106.8900 -6.1000,
            106.8900 -6.1150,
            106.8700 -6.1150,
            106.8700 -6.1000
        ))',
        4326
    )
),
(
    'AREA-SBY-01',
    'Surabaya Loading Area',
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
),
(
    'AREA-BPN-01',
    'Balikpapan Offshore Area',
    ST_GeomFromText(
        'POLYGON((
            116.8100 -1.2200,
            116.8400 -1.2200,
            116.8400 -1.2450,
            116.8100 -1.2450,
            116.8100 -1.2200
        ))',
        4326
    )
)
ON CONFLICT DO NOTHING;


-- ============================================================
-- 9. ENVIRONMENT STATION
-- ============================================================

INSERT INTO enviro.station (
    station_code, site_code, station_type, status
)
VALUES
    ('STN-JKT-01', 'SITE-JKT', 'TIDE', 'ACTIVE'),
    ('STN-JKT-02', 'SITE-JKT', 'BUOY', 'ACTIVE'),
    ('STN-SBY-01', 'SITE-SBY', 'TIDE', 'ACTIVE'),
    ('STN-BPN-01', 'SITE-BPN', 'BUOY', 'ACTIVE')
ON CONFLICT DO NOTHING;


-- ============================================================
-- 10. LABORATORY MASTER
-- ============================================================

INSERT INTO laboratory.info (
    lab_code, site_code
)
VALUES
    ('LAB-001', 'SITE-JKT'),
    ('LAB-002', 'SITE-SBY')
ON CONFLICT DO NOTHING;


-- ============================================================
-- 11. BUYER LEDGER DATA (12 TRANSACTIONS PER BUYER)
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
    (CURRENT_DATE - ((n - 1) * 30))::DATE,
    CASE WHEN n % 2 = 0 THEN 'DEBIT' ELSE 'CREDIT' END,
    (10000000 + (n * 1250000))::NUMERIC(18,2),
    'LEDGER-' || b.buyer_code || '-' || LPAD(n::TEXT, 3, '0'),
    'Dummy ledger transaction ' || n
FROM buyer.info b
CROSS JOIN generate_series(1, 12) n
ON CONFLICT DO NOTHING;


-- ============================================================
-- 12. PURCHASE ORDER (12 PO PER BUYER)
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
    'PO-' || b.buyer_code || '-' || LPAD(n::TEXT, 3, '0'),
    b.buyer_code,
    'CONTRACT-' || b.buyer_code,
    (CURRENT_DATE - ((n - 1) * 30))::DATE,
    'M3',
    (1000 + n * 250)::NUMERIC(18,4),
    (850000 + n * 10000)::NUMERIC(18,4),
    'IDR',
    'FOB',
    (CURRENT_DATE - ((n - 1) * 30))::DATE,
    (CURRENT_DATE - ((n - 1) * 30) + INTERVAL '10 days')::DATE,
    CASE
        WHEN n <= 2 THEN 'DRAFT'
        WHEN n <= 4 THEN 'SUBMITTED'
        WHEN n <= 10 THEN 'APPROVED'
        ELSE 'COMPLETED'
    END,
    'USR-OPS01',
    CASE WHEN n >= 3 THEN 'USR-ADMIN' ELSE NULL END,
    'Dummy purchase order ' || n
FROM buyer.info b
CROSS JOIN generate_series(1, 12) n
ON CONFLICT DO NOTHING;


-- ============================================================
-- 13. DELIVERY ORDER (1 DO UNTUK SETIAP PO)
-- ============================================================

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
    'DO-' || po.po_num,
    po.po_num,
    CASE po.buyer_code
        WHEN 'BUY-001' THEN 'SITE-JKT'
        WHEN 'BUY-002' THEN 'SITE-SBY'
        ELSE 'SITE-BPN'
    END,
    po.total_volume,
    po.target_start_date,
    po.target_end_date,
    CASE
        WHEN po.status = 'COMPLETED' THEN 'COMPLETED'
        WHEN po.status = 'APPROVED' THEN 'IN_PROGRESS'
        ELSE po.status
    END,
    CASE
        WHEN po.status = 'COMPLETED' THEN po.target_start_date
        ELSE NULL
    END,
    CASE
        WHEN po.status = 'COMPLETED' THEN po.target_end_date
        ELSE NULL
    END
FROM commercial.purchase_order po
ON CONFLICT DO NOTHING;


-- ============================================================
-- 14. SHIPMENT INSTRUCTION
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
    'SI-' || do_num,
    do_num,
    CASE
        WHEN ROW_NUMBER() OVER (ORDER BY do_num) % 3 = 1 THEN 'FLT-001'
        WHEN ROW_NUMBER() OVER (ORDER BY do_num) % 3 = 2 THEN 'FLT-002'
        ELSE 'FLT-003'
    END,
    NULL,
    CASE
        WHEN ROW_NUMBER() OVER (ORDER BY do_num) % 3 = 1 THEN 'AREA-JKT-01'
        WHEN ROW_NUMBER() OVER (ORDER BY do_num) % 3 = 2 THEN 'AREA-SBY-01'
        ELSE 'AREA-BPN-01'
    END,
    discharge_site,
    CASE
        WHEN status = 'COMPLETED' THEN 'COMPLETED'
        WHEN status = 'IN_PROGRESS' THEN 'IN_PROGRESS'
        ELSE status
    END
FROM commercial.delivery_order
ON CONFLICT DO NOTHING;


-- ============================================================
-- 15. WORK ACTIVITY (DI-FIX: Mengubah alias "do" menjadi "d_o")
-- ============================================================

INSERT INTO operational.work_activity (
    id,
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
    nextval('operational.work_activity_id_seq'),
    si.si_num,
    si.fleet_main_code,
    si.working_site,
    CASE
        WHEN ROW_NUMBER() OVER (ORDER BY si.si_num) % 3 = 1
            THEN 'LOADING'
        WHEN ROW_NUMBER() OVER (ORDER BY si.si_num) % 3 = 2
            THEN 'SAILING'
        ELSE 'DISCHARGING'
    END,
    d_o.target_start_date::TIMESTAMPTZ,
    d_o.target_end_date::TIMESTAMPTZ,
    si.status,
    CASE
        WHEN si.status IN ('IN_PROGRESS', 'COMPLETED')
            THEN d_o.actual_start_date::TIMESTAMPTZ
        ELSE NULL
    END,
    CASE
        WHEN si.status = 'COMPLETED'
            THEN d_o.actual_end_date::TIMESTAMPTZ
        ELSE NULL
    END
FROM operational.shipment_instruction si
JOIN commercial.delivery_order d_o  -- <--- ALIAS FIXED (Bukan "do" lagi)
  ON d_o.do_num = si.do_num
ON CONFLICT DO NOTHING;


-- ============================================================
-- 16. FORM WATER SAMPLING (1 FORM PER BULAN)
-- ============================================================

INSERT INTO form.water_sampling (
    form_no,
    sampling_date,
    total_sample,
    recorder_by,
    received_by,
    status
)
SELECT
    'FORM-' || TO_CHAR(d, 'YYYYMM'),
    d::DATE,
    3,
    'USR-OPS01',
    'USR-LAB01',
    CASE
        WHEN d < CURRENT_DATE - INTERVAL '30 days'
            THEN 'COMPLETED'
        ELSE 'SUBMITTED'
    END
FROM generate_series(
    CURRENT_DATE - INTERVAL '11 months',
    CURRENT_DATE,
    INTERVAL '1 month'
) d
ON CONFLICT DO NOTHING;


-- ============================================================
-- 17. FORM SAMPLE (3 SAMPLE PER FORM)
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
    CASE
        WHEN s.sample_no = 1 THEN 'SURFACE'
        WHEN s.sample_no = 2 THEN 'MID_DEPTH'
        ELSE 'BOTTOM'
    END,
    'Dummy sample ' || s.sample_no,
    ws.status
FROM form.water_sampling ws
CROSS JOIN generate_series(1, 3) s(sample_no)
ON CONFLICT DO NOTHING;


-- ============================================================
-- 18. FORM MEASUREMENT (4 PARAMETER PER SAMPLE)
-- ============================================================

INSERT INTO form.measurement (
    sample_id,
    parameter_name,
    parameter_value,
    uom_code,
    method,
    status
)
SELECT
    s.sample_id,
    p.parameter_name,
    CASE p.parameter_name
        WHEN 'TEMPERATURE' THEN ROUND((27 + RANDOM() * 6)::NUMERIC, 2)
        WHEN 'TURBIDITY' THEN ROUND((5 + RANDOM() * 30)::NUMERIC, 2)
        WHEN 'PH' THEN ROUND((6.8 + RANDOM() * 1.0)::NUMERIC, 2)
        WHEN 'DISSOLVED_OXYGEN' THEN ROUND((4 + RANDOM() * 4)::NUMERIC, 2)
    END,
    CASE p.parameter_name
        WHEN 'TEMPERATURE' THEN 'CEL'
        WHEN 'TURBIDITY' THEN 'NTU'
        WHEN 'PH' THEN 'M'
        WHEN 'DISSOLVED_OXYGEN' THEN 'MG_L'
    END,
    'FIELD_TEST',
    'VALID'
FROM form.sample s
CROSS JOIN (
    VALUES
        ('TEMPERATURE'),
        ('TURBIDITY'),
        ('PH'),
        ('DISSOLVED_OXYGEN')
) p(parameter_name)
ON CONFLICT DO NOTHING;


-- ============================================================
-- 19. LABORATORY RESULT
-- ============================================================

INSERT INTO laboratory.result (
    doc_no,
    lab_code,
    sample_id
)
SELECT
    'LAB-RESULT-' || LPAD(s.sample_id::TEXT, 6, '0'),
    CASE
        WHEN s.sample_id % 2 = 0 THEN 'LAB-001'
        ELSE 'LAB-002'
    END,
    s.sample_id
FROM form.sample s
ON CONFLICT DO NOTHING;


-- ============================================================
-- 20. ENVIRONMENT WATER QUALITY (1 READING PER HARI PER STATION)
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
    d::TIMESTAMPTZ,
    ROUND((1 + RANDOM() * 20)::NUMERIC, 2),
    ROUND((2 + RANDOM() * 8)::NUMERIC, 2),
    ROUND((27 + RANDOM() * 6)::NUMERIC, 2),
    ROUND((5 + RANDOM() * 30)::NUMERIC, 2),
    ROUND((4 + RANDOM() * 4)::NUMERIC, 2),
    ROUND((6.8 + RANDOM() * 1.0)::NUMERIC, 2),
    ROUND((25 + RANDOM() * 10)::NUMERIC, 2),
    CASE
        WHEN RANDOM() < 0.85 THEN 'GOOD'
        WHEN RANDOM() < 0.95 THEN 'WARNING'
        ELSE 'BAD'
    END
FROM enviro.station st
CROSS JOIN LATERAL generate_series(
    (SELECT start_date FROM tmp_dummy_period)::TIMESTAMPTZ,
    (SELECT end_date FROM tmp_dummy_period)::TIMESTAMPTZ,
    INTERVAL '1 day'
) d
ON CONFLICT DO NOTHING;


-- ============================================================
-- 21. TIDE READING (1 READING PER JAM PER TIDE STATION)
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
    d,
    ROUND((28 + RANDOM() * 5)::NUMERIC, 2),
    ROUND((5 + RANDOM() * 30)::NUMERIC, 2),
    ROUND((0.1 + RANDOM() * 2)::NUMERIC, 2),
    ROUND((4 + RANDOM() * 4)::NUMERIC, 2),
    ROUND((1.020 + RANDOM() * 0.010)::NUMERIC, 4),
    ROUND((0.5 + 1.5 * SIN(EXTRACT(EPOCH FROM d) / 43200)
           + RANDOM() * 0.2)::NUMERIC, 2)
FROM enviro.station st
CROSS JOIN LATERAL generate_series(
    (SELECT start_date FROM tmp_dummy_period)::TIMESTAMPTZ,
    (SELECT end_date FROM tmp_dummy_period)::TIMESTAMPTZ,
    INTERVAL '1 hour'
) d
WHERE st.station_type = 'TIDE'
ON CONFLICT DO NOTHING;


-- ============================================================
-- 22. BUOY READING (1 READING PER JAM PER BUOY STATION)
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
    d,
    ROUND((28 + RANDOM() * 5)::NUMERIC, 2),
    ROUND((5 + RANDOM() * 30)::NUMERIC, 2),
    ROUND((0.1 + RANDOM() * 2)::NUMERIC, 2),
    ROUND((4 + RANDOM() * 4)::NUMERIC, 2),
    ROUND((1.020 + RANDOM() * 0.010)::NUMERIC, 4),
    ROUND((0.5 + 1.5 * SIN(EXTRACT(EPOCH FROM d) / 43200)
           + RANDOM() * 0.2)::NUMERIC, 2)
FROM enviro.station st
CROSS JOIN LATERAL generate_series(
    (SELECT start_date FROM tmp_dummy_period)::TIMESTAMPTZ,
    (SELECT end_date FROM tmp_dummy_period)::TIMESTAMPTZ,
    INTERVAL '1 hour'
) d
WHERE st.station_type = 'BUOY'
ON CONFLICT DO NOTHING;


-- ============================================================
-- 23. VOYAGE CURRENT (1 READING PER JAM PER FLEET)
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
        WHEN 'FLT-001' THEN -6.1045 + SIN(EXTRACT(EPOCH FROM d) / 86400) * 0.05
        WHEN 'FLT-002' THEN -7.2050 + SIN(EXTRACT(EPOCH FROM d) / 86400) * 0.05
        ELSE -1.2350 + SIN(EXTRACT(EPOCH FROM d) / 86400) * 0.05
    END,
    CASE f.fleet_code
        WHEN 'FLT-001' THEN 106.8801 + COS(EXTRACT(EPOCH FROM d) / 86400) * 0.05
        WHEN 'FLT-002' THEN 112.7360 + COS(EXTRACT(EPOCH FROM d) / 86400) * 0.05
        ELSE 116.8270 + COS(EXTRACT(EPOCH FROM d) / 86400) * 0.05
    END,
    d,
    CASE
        WHEN EXTRACT(DAY FROM d)::INT % 10 = 0 THEN 'MAINTENANCE'
        ELSE 'IN_PROGRESS'
    END
FROM fleet.info f
CROSS JOIN LATERAL generate_series(
    (SELECT start_date FROM tmp_dummy_period)::TIMESTAMPTZ,
    (SELECT end_date FROM tmp_dummy_period)::TIMESTAMPTZ,
    INTERVAL '1 hour'
) d
ON CONFLICT DO NOTHING;


-- ============================================================
-- 24. VOYAGE HISTORY (1 READING PER JAM PER FLEET)
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
        WHEN 'FLT-001' THEN -6.1045 + SIN(EXTRACT(EPOCH FROM d) / 86400) * 0.05
        WHEN 'FLT-002' THEN -7.2050 + SIN(EXTRACT(EPOCH FROM d) / 86400) * 0.05
        ELSE -1.2350 + SIN(EXTRACT(EPOCH FROM d) / 86400) * 0.05
    END,
    CASE f.fleet_code
        WHEN 'FLT-001' THEN 106.8801 + COS(EXTRACT(EPOCH FROM d) / 86400) * 0.05
        WHEN 'FLT-002' THEN 112.7360 + COS(EXTRACT(EPOCH FROM d) / 86400) * 0.05
        ELSE 116.8270 + COS(EXTRACT(EPOCH FROM d) / 86400) * 0.05
    END,
    d
FROM fleet.info f
CROSS JOIN LATERAL generate_series(
    (SELECT start_date FROM tmp_dummy_period)::TIMESTAMPTZ,
    (SELECT end_date FROM tmp_dummy_period)::TIMESTAMPTZ,
    INTERVAL '1 hour'
) d
ON CONFLICT DO NOTHING;


-- ============================================================
-- UPDATE STATISTICS
-- ============================================================
ANALYZE param.country;
ANALYZE param.currency;
ANALYZE param.unit_of_measure;
ANALYZE param.status;
ANALYZE param.threshold;

ANALYZE site.info;
ANALYZE "user".info;
ANALYZE partner.info;
ANALYZE buyer.info;
ANALYZE buyer.ledger_hist;
ANALYZE fleet.info;
ANALYZE fleet.maintenance;
ANALYZE form.water_sampling;
ANALYZE form.sample;
ANALYZE form.measurement;
ANALYZE laboratory.result;
ANALYZE enviro.station;
ANALYZE enviro.water_quality;
ANALYZE enviro.tide_reading;
ANALYZE enviro.buoy_reading;
ANALYZE commercial.purchase_order;
ANALYZE commercial.delivery_order;
ANALYZE operational.shipment_instruction;
ANALYZE operational.work_activity;
ANALYZE voyage.voyage;
ANALYZE voyage.voyage_hist;

COMMIT;