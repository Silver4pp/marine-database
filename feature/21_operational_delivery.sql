-- ============================================================
-- FEATURE SCHEMA: operational - trip, manifest, receipt
-- file    : feature/21_operational_delivery.sql
-- note    : delivery_order and shipment_instruction describe intent; these four
--           tables describe what actually happened at sea, so buyer fulfillment
--           is computed from measured cargo instead of from vessel capacity or
--           the static volume on the delivery order.
-- depends : feature/02_site, 03_user, 05_buyer, 06_fleet, 11_commercial,
--           12_operational, 19_document, 01_param
-- ============================================================

-- ------------------------------------------------------------
-- delivery_trip - one vessel voyage from loading to delivery complete
-- ------------------------------------------------------------
CREATE TABLE operational.delivery_trip (
    trip_id             BIGSERIAL       PRIMARY KEY,
    tenant_id           UUID,
    trip_no             VARCHAR(30)     NOT NULL UNIQUE,
    si_num              VARCHAR(30)     NOT NULL
                            REFERENCES operational.shipment_instruction(si_num) ON DELETE RESTRICT,
    do_num              VARCHAR(30)     NOT NULL
                            REFERENCES commercial.delivery_order(do_num) ON DELETE RESTRICT,
    fleet_code          VARCHAR(30)     NOT NULL
                            REFERENCES fleet.info(fleet_code) ON DELETE RESTRICT,
    fleet_assist_code   VARCHAR(30)
                            REFERENCES fleet.info(fleet_code) ON DELETE SET NULL,
    voyage_no           VARCHAR(30),
    trip_seq            SMALLINT        NOT NULL DEFAULT 1,
    loading_site        VARCHAR(30)
                            REFERENCES site.info(site_code) ON DELETE SET NULL,
    discharge_site      VARCHAR(30)
                            REFERENCES site.info(site_code) ON DELETE SET NULL,
    status              VARCHAR(30)
                            REFERENCES param.status(status_code) ON DELETE SET NULL,
    planned_load_at     TIMESTAMPTZ,
    planned_depart_at   TIMESTAMPTZ,
    planned_arrive_at   TIMESTAMPTZ,
    planned_deliver_at  TIMESTAMPTZ,
    actual_load_at      TIMESTAMPTZ,
    actual_depart_at    TIMESTAMPTZ,
    actual_arrive_at    TIMESTAMPTZ,
    actual_unload_at    TIMESTAMPTZ,
    actual_deliver_at   TIMESTAMPTZ,
    eta                 TIMESTAMPTZ,
    eta_revised_at      TIMESTAMPTZ,
    delay_minutes       INT             GENERATED ALWAYS AS (
                            CASE
                                WHEN planned_arrive_at IS NOT NULL AND eta IS NOT NULL
                                    AND eta > planned_arrive_at
                                THEN ROUND(EXTRACT(EPOCH FROM (eta - planned_arrive_at)) / 60)::INT
                                ELSE 0
                            END
                        ) STORED,
    distance_nm         NUMERIC(12,3),
    fuel_consumed       NUMERIC(12,3),
    captain_name        VARCHAR(150),
    crew_count          SMALLINT,
    notes               TEXT,
    created_by          VARCHAR(30)
                            REFERENCES "user".info(user_code) ON DELETE SET NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT chk_trip_assist_differs CHECK (
        fleet_assist_code IS NULL OR fleet_assist_code <> fleet_code
    ),
    CONSTRAINT chk_trip_depart_after_load CHECK (
        actual_depart_at IS NULL OR actual_load_at IS NULL OR actual_depart_at >= actual_load_at
    ),
    CONSTRAINT chk_trip_arrive_after_depart CHECK (
        actual_arrive_at IS NULL OR actual_depart_at IS NULL OR actual_arrive_at >= actual_depart_at
    ),
    CONSTRAINT chk_trip_unload_after_arrive CHECK (
        actual_unload_at IS NULL OR actual_arrive_at IS NULL OR actual_unload_at >= actual_arrive_at
    ),
    CONSTRAINT chk_trip_deliver_after_unload CHECK (
        actual_deliver_at IS NULL OR actual_unload_at IS NULL OR actual_deliver_at >= actual_unload_at
    )
);

-- lookup index only: one SI legitimately runs several trips, and two vessels may
-- run in parallel, so there is deliberately no uniqueness on open trips
CREATE INDEX IF NOT EXISTS idx_trip_si_open
    ON operational.delivery_trip(si_num, actual_deliver_at NULLS FIRST);

-- ------------------------------------------------------------
-- delivery_trip_event - milestone log
-- ------------------------------------------------------------
CREATE TABLE operational.delivery_trip_event (
    event_id        BIGSERIAL       PRIMARY KEY,
    tenant_id       UUID,
    trip_id         BIGINT          NOT NULL
                        REFERENCES operational.delivery_trip(trip_id) ON DELETE CASCADE,
    event_type      VARCHAR(20)     NOT NULL
                        CHECK (event_type IN (
                            'LOADING','DEPARTED','ARRIVED','UNLOADING','DELIVERED','DELAYED'
                        )),
    event_time      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    event_order     INT,
    lat             NUMERIC(10,7)
                        CHECK (lat IS NULL OR (lat >= -90 AND lat <= 90)),
    long            NUMERIC(11,7)
                        CHECK (long IS NULL OR (long >= -180 AND long <= 180)),
    geom            GEOMETRY(Point, 4326) GENERATED ALWAYS AS (
                        CASE
                            WHEN lat IS NOT NULL AND long IS NOT NULL
                            THEN ST_SetSRID(ST_MakePoint(long, lat), 4326)
                            ELSE NULL
                        END
                    ) STORED,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    delay_minutes   INT,
    delay_reason    TEXT,
    recorded_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    source_system   VARCHAR(50)     DEFAULT 'MANUAL',
    notes           TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- a milestone is recorded once per trip; DELAYED repeats, so it is excluded
CREATE UNIQUE INDEX IF NOT EXISTS uq_trip_event_once
    ON operational.delivery_trip_event(trip_id, event_type)
    WHERE event_type <> 'DELAYED';

-- ------------------------------------------------------------
-- cargo_manifest - measured cargo per trip, not an estimate
-- ------------------------------------------------------------
CREATE TABLE operational.cargo_manifest (
    manifest_id       BIGSERIAL     PRIMARY KEY,
    tenant_id         UUID,
    manifest_no       VARCHAR(30)   NOT NULL UNIQUE,
    trip_id           BIGINT        NOT NULL
                          REFERENCES operational.delivery_trip(trip_id) ON DELETE RESTRICT,
    cargo_type        VARCHAR(50)   NOT NULL DEFAULT 'DREDGED_MATERIAL',
    uom_code          VARCHAR(20)   NOT NULL
                          REFERENCES param.unit_of_measure(uom_code) ON DELETE RESTRICT,
    loaded_volume     NUMERIC(18,4) NOT NULL DEFAULT 0 CHECK (loaded_volume >= 0),
    discharged_volume NUMERIC(18,4) CHECK (discharged_volume >= 0),
    loss_volume       NUMERIC(18,4) GENERATED ALWAYS AS (
                          CASE
                              WHEN discharged_volume IS NOT NULL
                              THEN GREATEST(loaded_volume - discharged_volume, 0)
                              ELSE NULL
                          END
                      ) STORED,
    draft_loading     NUMERIC(10,2),
    draft_discharge   NUMERIC(10,2),
    measurement_method VARCHAR(50)
                          CHECK (measurement_method IS NULL OR measurement_method IN (
                              'DRAFT_SURVEY','FLOWMETER','HOPPER_SURVEY','SCALE','ESTIMATED'
                          )),
    quality_class     VARCHAR(50),
    moisture_content  NUMERIC(6,3),
    measured_at       TIMESTAMPTZ,
    verified_by       VARCHAR(30)
                          REFERENCES "user".info(user_code) ON DELETE SET NULL,
    is_valid          BOOLEAN       NOT NULL DEFAULT TRUE,
    notes             TEXT,
    created_at        TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- delivery_receipt - buyer's proof of receipt and accepted volume
-- ------------------------------------------------------------
CREATE TABLE operational.delivery_receipt (
    receipt_id      BIGSERIAL       PRIMARY KEY,
    tenant_id       UUID,
    receipt_no      VARCHAR(30)     NOT NULL UNIQUE,
    trip_id         BIGINT          NOT NULL
                        REFERENCES operational.delivery_trip(trip_id) ON DELETE RESTRICT,
    manifest_id     BIGINT
                        REFERENCES operational.cargo_manifest(manifest_id) ON DELETE SET NULL,
    buyer_code      VARCHAR(30)     NOT NULL
                        REFERENCES buyer.info(buyer_code) ON DELETE RESTRICT,
    received_at     TIMESTAMPTZ     NOT NULL,
    uom_code        VARCHAR(20)     NOT NULL
                        REFERENCES param.unit_of_measure(uom_code) ON DELETE RESTRICT,
    received_volume NUMERIC(18,4)   NOT NULL CHECK (received_volume >= 0),
    rejected_volume NUMERIC(18,4)   NOT NULL DEFAULT 0 CHECK (rejected_volume >= 0),
    rejection_reason TEXT,
    receiver_name   VARCHAR(150)    NOT NULL,
    receiver_title  VARCHAR(100),
    signature_ref   VARCHAR(200),
    document_id     BIGINT
                        REFERENCES document.document(document_id) ON DELETE SET NULL,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    approved_by     VARCHAR(30)
                        REFERENCES "user".info(user_code) ON DELETE SET NULL,
    approved_at     TIMESTAMPTZ,
    notes           TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- Functions
-- ------------------------------------------------------------

-- Validated cargo actually delivered for a delivery order: only manifests still
-- valid and receipts already approved, so fulfillment never comes from vessel
-- capacity or the DO's static volume.
CREATE OR REPLACE FUNCTION operational.fn_do_fulfilled_volume(p_do_num VARCHAR)
RETURNS TABLE (
    uom_code        VARCHAR(20),
    manifest_volume NUMERIC(18,4),
    receipt_volume  NUMERIC(18,4)
) AS $$
BEGIN
    RETURN QUERY
    SELECT m.uom_code,
           COALESCE(SUM(m.discharged_volume), 0)::NUMERIC(18,4),
           COALESCE(SUM(r.received_volume), 0)::NUMERIC(18,4)
    FROM operational.delivery_trip t
    JOIN operational.cargo_manifest m
         ON m.trip_id = t.trip_id AND m.is_valid = TRUE
    LEFT JOIN operational.delivery_receipt r
         ON r.trip_id = t.trip_id
        AND r.manifest_id = m.manifest_id
        AND r.status = 'APPROVED'
    WHERE t.do_num = p_do_num
    GROUP BY m.uom_code
    ORDER BY m.uom_code;
END;
$$ LANGUAGE plpgsql STABLE;

-- Fulfillment percentage against the DO target, converted into the DO's UoM.
CREATE OR REPLACE FUNCTION operational.fn_do_fulfillment_pct(p_do_num VARCHAR)
RETURNS NUMERIC(6,2) AS $$
DECLARE
    v_target     NUMERIC(18,4);
    v_target_uom VARCHAR(20);
    v_actual     NUMERIC(18,4);
BEGIN
    SELECT target_volume, uom_code INTO v_target, v_target_uom
    FROM commercial.delivery_order WHERE do_num = p_do_num;

    IF v_target IS NULL OR v_target = 0 THEN RETURN NULL; END IF;

    SELECT COALESCE(SUM(
        operational.fn_convert_volume_to_target_uom(f.receipt_volume, f.uom_code, v_target_uom)
    ), 0) INTO v_actual
    FROM operational.fn_do_fulfilled_volume(p_do_num) f;

    RETURN ROUND((v_actual / v_target) * 100, 2);
END;
$$ LANGUAGE plpgsql STABLE;

-- ------------------------------------------------------------
-- Trigger: stamp the trip's actual_* columns from its milestone events, so a
-- time is never entered twice
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION operational.fn_sync_trip_from_event()
RETURNS TRIGGER AS $$
BEGIN
    CASE NEW.event_type
        WHEN 'LOADING'   THEN UPDATE operational.delivery_trip
                             SET actual_load_at = NEW.event_time WHERE trip_id = NEW.trip_id;
        WHEN 'DEPARTED'  THEN UPDATE operational.delivery_trip
                             SET actual_depart_at = NEW.event_time WHERE trip_id = NEW.trip_id;
        WHEN 'ARRIVED'   THEN UPDATE operational.delivery_trip
                             SET actual_arrive_at = NEW.event_time WHERE trip_id = NEW.trip_id;
        WHEN 'UNLOADING' THEN UPDATE operational.delivery_trip
                             SET actual_unload_at = NEW.event_time WHERE trip_id = NEW.trip_id;
        WHEN 'DELIVERED' THEN UPDATE operational.delivery_trip
                             SET actual_deliver_at = NEW.event_time WHERE trip_id = NEW.trip_id;
        WHEN 'DELAYED'   THEN UPDATE operational.delivery_trip
                             SET eta = NEW.event_time + make_interval(mins => COALESCE(NEW.delay_minutes, 0)),
                                 eta_revised_at = now()
                             WHERE trip_id = NEW.trip_id;
        ELSE NULL;
    END CASE;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_sync_trip_from_event
AFTER INSERT ON operational.delivery_trip_event
FOR EACH ROW EXECUTE FUNCTION operational.fn_sync_trip_from_event();
