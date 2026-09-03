-- ============================================================
-- FEATURE SCHEMA: operational
-- file    : feature/12_operational.sql
-- objects : 7 statement(s)
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- ============================================================
-- SECTION 15: OPERATIONAL SCHEMA TABLES
-- ============================================================

CREATE TABLE operational.work_area (
    area_code       VARCHAR(30)     PRIMARY KEY,
    name            VARCHAR(150)    NOT NULL,
    area_type       VARCHAR(50)     NOT NULL DEFAULT 'DREDGING',
    geom            GEOMETRY(Polygon, 4326),
    lat             NUMERIC(10,7) GENERATED ALWAYS AS (
                        CASE WHEN geom IS NOT NULL THEN ST_Y(ST_Centroid(geom)) ELSE NULL END
                    ) STORED,
    long            NUMERIC(11,7) GENERATED ALWAYS AS (
                        CASE WHEN geom IS NOT NULL THEN ST_X(ST_Centroid(geom)) ELSE NULL END
                    ) STORED,
    site_code       VARCHAR(30)
                        REFERENCES site.info(site_code) ON DELETE SET NULL,
    description     TEXT,
    tenant_id       UUID,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE operational.shipment_instruction (
    si_num              VARCHAR(30)     PRIMARY KEY,
    do_num              VARCHAR(30)     NOT NULL
                            REFERENCES commercial.delivery_order(do_num) ON DELETE RESTRICT,
    fleet_main_code     VARCHAR(30)     NOT NULL
                            REFERENCES fleet.info(fleet_code) ON DELETE RESTRICT,
    fleet_assist_code   VARCHAR(30)
                            REFERENCES fleet.info(fleet_code) ON DELETE SET NULL,
    working_site        VARCHAR(30)
                            REFERENCES site.info(site_code) ON DELETE SET NULL,
    discharge_site      VARCHAR(30)
                            REFERENCES site.info(site_code) ON DELETE SET NULL,
    work_area_code      VARCHAR(30)
                            REFERENCES operational.work_area(area_code) ON DELETE SET NULL,
    status              VARCHAR(30)
                            REFERENCES param.status(status_code) ON DELETE SET NULL,
    planned_start       TIMESTAMPTZ,
    planned_end         TIMESTAMPTZ,
    actual_start        TIMESTAMPTZ,
    actual_end          TIMESTAMPTZ,
    notes               TEXT,
    created_by          VARCHAR(30)
                            REFERENCES "user".info(user_code) ON DELETE SET NULL,
    approved_by         VARCHAR(30)
                            REFERENCES "user".info(user_code) ON DELETE SET NULL,
    tenant_id           UUID,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT chk_different_fleet CHECK (
        fleet_assist_code IS NULL OR fleet_assist_code <> fleet_main_code
    )
);

CREATE TABLE operational.work_activity (
    activity_num    BIGSERIAL       PRIMARY KEY,
    si_num          VARCHAR(30)     NOT NULL
                        REFERENCES operational.shipment_instruction(si_num) ON DELETE CASCADE,
    fleet_code      VARCHAR(30)     NOT NULL
                        REFERENCES fleet.info(fleet_code) ON DELETE RESTRICT,
    area_code       VARCHAR(30)
                        REFERENCES operational.work_area(area_code) ON DELETE SET NULL,
    activity_type   VARCHAR(50)     NOT NULL,
    activity_name   VARCHAR(200),
    planned_start   TIMESTAMPTZ,
    planned_end     TIMESTAMPTZ,
    status          VARCHAR(30)
                        REFERENCES param.status(status_code) ON DELETE SET NULL,
    actual_start    TIMESTAMPTZ,
    actual_end      TIMESTAMPTZ,
    notes           TEXT,
    tenant_id       UUID,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT chk_planned_dates CHECK (planned_end >= planned_start OR planned_end IS NULL),
    CONSTRAINT chk_actual_dates  CHECK (actual_end >= actual_start  OR actual_end IS NULL)
);

CREATE TABLE operational.dredging_records (
    id               BIGSERIAL      PRIMARY KEY,
    si_num           VARCHAR(30)    NOT NULL
                            REFERENCES operational.shipment_instruction(si_num) ON DELETE RESTRICT,
    activity_num     BIGINT         NOT NULL
                            REFERENCES operational.work_activity(activity_num) ON DELETE RESTRICT,
    record_date      DATE           NOT NULL,
    dredging_volume  NUMERIC(18,4)  NOT NULL CHECK (dredging_volume >= 0),
    uom_code         VARCHAR(20)    NOT NULL
                            REFERENCES param.unit_of_measure(uom_code) ON DELETE RESTRICT,
    quality_class    VARCHAR(50),
    disposal_method  VARCHAR(100),
    created_by       VARCHAR(30)
                            REFERENCES "user".info(user_code) ON DELETE SET NULL,
    notes            TEXT,
    tenant_id        UUID,
    created_at       TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT uq_dredging_daily UNIQUE (activity_num, record_date)
);

-- Operational: Convert volume to target UOM
CREATE OR REPLACE FUNCTION operational.fn_convert_volume_to_target_uom(
    p_volume NUMERIC, p_from_uom VARCHAR, p_to_uom VARCHAR
) RETURNS NUMERIC AS $$
DECLARE v_converted NUMERIC;
BEGIN
    IF p_from_uom = p_to_uom THEN RETURN p_volume; END IF;
    SELECT conv_value * p_volume INTO v_converted
    FROM param.unit_conversion
    WHERE uom_from = p_from_uom AND uom_to = p_to_uom AND is_active = TRUE;
    IF v_converted IS NULL THEN
        SELECT (p_volume / conv_value) INTO v_converted
        FROM param.unit_conversion
        WHERE uom_from = p_to_uom AND uom_to = p_from_uom AND is_active = TRUE;
    END IF;
    RETURN COALESCE(v_converted, p_volume);
END;
$$ LANGUAGE plpgsql;

-- Operational: Validate dredging volume
CREATE OR REPLACE FUNCTION operational.fn_validate_dredging_volume()
RETURNS TRIGGER AS $$
DECLARE
    v_do_num VARCHAR(30); v_target NUMERIC(18,4); v_target_uom VARCHAR(20);
    v_total NUMERIC(18,4); v_converted_vol NUMERIC(18,4);
BEGIN
    SELECT si.do_num, d_o.target_volume, d_o.uom_code
    INTO v_do_num, v_target, v_target_uom
    FROM operational.shipment_instruction si
    JOIN commercial.delivery_order d_o ON d_o.do_num = si.do_num
    WHERE si.si_num = NEW.si_num;
    IF v_do_num IS NULL OR v_target IS NULL THEN RETURN NEW; END IF;
    v_converted_vol := operational.fn_convert_volume_to_target_uom(NEW.dredging_volume, NEW.uom_code, v_target_uom);
    SELECT COALESCE(SUM(
        operational.fn_convert_volume_to_target_uom(dr.dredging_volume, dr.uom_code, v_target_uom)
    ), 0) INTO v_total
    FROM operational.dredging_records dr
    JOIN operational.shipment_instruction si ON si.si_num = dr.si_num
    WHERE si.do_num = v_do_num AND dr.id <> COALESCE(NEW.id, -1);
    IF (v_total + v_converted_vol) > v_target THEN
        RAISE EXCEPTION 'VOLUME_EXCEEDED: Total volume (%) exceeds target (%) for DO %',
            ROUND(v_total + v_converted_vol, 4), ROUND(v_target, 4), v_do_num;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Operational: Validate dredging volume
CREATE OR REPLACE TRIGGER trg_validate_dredging_volume
BEFORE INSERT OR UPDATE OF dredging_volume, uom_code ON operational.dredging_records
FOR EACH ROW EXECUTE FUNCTION operational.fn_validate_dredging_volume();
