-- ============================================================
-- CRON LAYER: pg_cron scheduled jobs
-- file    : cron/01_scheduled_jobs.sql
-- note    : Hand-written, not generated. The original file contained no
--           cron.schedule calls; these are the jobs the new layers need in order
--           to keep themselves correct.
--
--           Requires pg_cron to be preloaded and cron.database_name to point at
--           this database:
--             shared_preload_libraries = 'pg_cron'
--             cron.database_name = '<this db>'
--           On Supabase pg_cron is available and cron.database_name is 'postgres',
--           in which case every command below must be schema-qualified through a
--           foreign-data or dblink wrapper, or the jobs must be created in the
--           'postgres' database. Verify with:  SELECT * FROM cron.job;
--
--           Re-runnable: each job is unscheduled by name before it is scheduled
--           again, so editing a command here and re-deploying is safe.
-- depends : everything (runs last)
-- ============================================================

\set ON_ERROR_STOP on

-- re-schedule helper: drop by name, then create
DO $job$
DECLARE
    j RECORD;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'cron') THEN
        RAISE NOTICE 'cron schema absent - pg_cron is not installed, skipping job creation';
        RETURN;
    END IF;

    -- cron.job has no comment column before pg_cron 1.7, so the description of
    -- each job lives here as a comment rather than in the catalog.
    FOR j IN
        SELECT * FROM (VALUES
            -- 1. partition maintenance: telemetry.ais_position is partitioned by
            --    year and ingest fails hard if the target partition is missing
            ('partition-maintenance', '30 1 * * *',
             $$SELECT public.fn_create_future_partitions('telemetry','ais_position',2);$$),

            -- 2. reporting refresh: the five materialized views, concurrently so
            --    readers are never blocked
            ('reporting-refresh', '0 2 * * *',
             $$REFRESH MATERIALIZED VIEW CONCURRENTLY reporting.tide_read_daily;
               REFRESH MATERIALIZED VIEW CONCURRENTLY reporting.buoy_read_daily;
               REFRESH MATERIALIZED VIEW CONCURRENTLY reporting.dredging_production;
               REFRESH MATERIALIZED VIEW CONCURRENTLY reporting.account_balance;
               REFRESH MATERIALIZED VIEW CONCURRENTLY reporting.hse_incident_summary;$$),

            -- 3. compliance scan: grade every obligation and raise alerts for
            --    anything that is not COMPLIANT
            ('compliance-scan', '15 6 * * *',
             $$SELECT compliance.fn_scan_requirements();$$),

            -- 4. compliance alert hygiene: an obligation that became COMPLIANT
            --    again must not keep a live alert open
            ('compliance-alert-expiry', '45 6 * * *',
             $$UPDATE compliance.alert a
                  SET is_active = FALSE
                WHERE a.is_active = TRUE
                  AND NOT EXISTS (
                      SELECT 1 FROM compliance.entity_requirement er
                      JOIN compliance.requirement r ON r.requirement_id = er.requirement_id
                      WHERE er.entity_req_id = a.entity_req_id
                        AND er.is_active = TRUE
                        AND compliance.fn_grade(er.expiry_date, r.warn_days_before,
                                                r.evidence_required,
                                                er.document_id IS NOT NULL) <> 'COMPLIANT'
                  );$$),

            -- 5. HSE digest: overdue corrective work is only monitorable if
            --    somebody is told about it every morning
            ('hse-overdue-digest', '0 7 * * *',
             $$INSERT INTO audit.log (user_code, action, table_schema, table_name, record_pk, new_data)
               SELECT 'SYSTEM', 'HSE_OVERDUE_DIGEST', 'hse', 'corrective_action',
                      'digest', jsonb_build_object(
                          'digest_date', CURRENT_DATE,
                          'overdue_count', count(*) FILTER (WHERE ageing_status = 'OVERDUE'),
                          'due_today_count', count(*) FILTER (WHERE ageing_status = 'DUE_TODAY'),
                          'oldest_days_overdue', max(days_overdue))
               FROM hse.v_overdue_actions
               WHERE ageing_status IN ('OVERDUE','DUE_TODAY');$$)
        ) AS spec(jobname, schedule, command)
    LOOP
        PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = j.jobname;
        PERFORM cron.schedule(j.jobname, j.schedule, j.command);
        RAISE NOTICE 'scheduled % at %', j.jobname, j.schedule;
    END LOOP;
END;
$job$;

SELECT jobid, jobname, schedule, database, active FROM cron.job ORDER BY jobname;
