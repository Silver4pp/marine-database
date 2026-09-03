#!/usr/bin/env bash
# Deploy the split schema in dependency order.
#
#   ./deploy.sh "postgresql://user:pass@host:5432/dbname"
#
# Six layers, applied in the only order that satisfies every dependency:
#
#   base/01-04   extensions, schemas, shared + partition functions
#   feature/*    tables, per-schema functions and triggers (numbered = FK order)
#   base/08      the global updated_at trigger - needs EVERY table to exist
#   view/        materialized views, then regular views
#   index/       all indexes, including the ones on the materialized views
#   seed/        reference data
#   base/05-07   tenant hardening, RLS, tenant-aware functions (optional)
#   cron/        pg_cron jobs (optional)
#
# base/05 runs AFTER seed on purpose: it backfills tenant_id on the rows the
# seeds inserted and only then sets NOT NULL, so reference data does not have to
# know about tenants.
#
# Every file runs with ON_ERROR_STOP=1 inside its own transaction, so a failure
# stops the run instead of leaving a half-built database.
set -euo pipefail

DB_URL="${1:-}"
if [[ -z "$DB_URL" ]]; then
    echo "usage: $0 <database-url>" >&2
    exit 64
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"

# Optional: with CRON_DB set, pg_cron is pointed at the target database and the
# cluster is restarted (only needed when the run should include the cron layer).
if [[ -n "${CRON_DB:-}" && -n "${PGDATA_DIR:-}" ]]; then
    sed -i "s/^cron.database_name = .*/cron.database_name = '$CRON_DB'/" "$PGDATA_DIR/postgresql.conf"
    pg_ctl -D "$PGDATA_DIR" -l /tmp/pg.log -w -m fast restart >/dev/null
fi

run() {
    local f="$1"; shift
    printf '  -> %-40s' "$(basename "$f")"
    if env "$@" psql "$DB_URL" -v ON_ERROR_STOP=1 -q -1 -f "$ROOT/$f" >/dev/null; then
        echo "ok"
    else
        echo "FAILED"
        exit 1
    fi
}

# Same as run(), but also passes psql variables. Needed by base/05, whose tenant
# name may contain spaces and therefore cannot travel in PGOPTIONS.
run_with_vars() {
    local f="$1"; shift
    local envs=()
    while [[ "$1" == *=* ]]; do envs+=("$1"); shift; done
    printf '  -> %-40s' "$(basename "$f")"
    if env "${envs[@]}" psql "$DB_URL" -v ON_ERROR_STOP=1 -q -1 "$@" -f "$ROOT/$f" >/dev/null; then
        echo "ok"
    else
        echo "FAILED"
        exit 1
    fi
}

echo "== 1/8 base: extensions, schemas, shared functions =="
run base/01_extensions.sql
run base/02_schemas.sql
run base/03_functions.sql
run base/04_partition_functions.sql

echo "== 2/8 feature schemas (numbered = foreign-key order) =="
for f in "$ROOT"/feature/*.sql; do
    run "feature/$(basename "$f")"
done

echo "== 3/8 base: global updated_at trigger (needs every table) =="
run base/08_global_updated_at.sql

echo "== 4/8 view layer =="
run view/01_materialized_views.sql
run view/02_views.sql

echo "== 5/8 index layer (includes the materialized-view indexes) =="
run index/01_indexes.sql

echo "== 6/8 seed data =="
for f in "$ROOT"/seed/*.sql; do
    run "seed/$(basename "$f")"
done

echo
if [[ -n "${WITH_HARDENING:-}" ]]; then
    echo "== 7/8 base/05: tenant hardening =="
    run_with_vars base/05_tenant_hardening.sql \
        PGOPTIONS="-c mig.default_tenant_code=${TENANT_CODE:-DEFAULT}" \
        -v mig_name="${TENANT_NAME:-DefaultTenant}"

    echo "== 7/8 base/06: row level security =="
    run base/06_rls.sql

    echo "== 7/8 base/07: tenant-aware functions =="
    run base/07_tenant_aware_functions.sql
else
    echo "== 7/8 tenant hardening skipped (set WITH_HARDENING=1) =="
fi

if [[ -n "${WITH_CRON:-}" ]]; then
    echo "== 8/8 cron layer =="
    run cron/01_scheduled_jobs.sql
else
    echo "== 8/8 cron layer skipped (set WITH_CRON=1) =="
fi

echo
echo "Optional stages, off by default:"
echo "  WITH_HARDENING=1   base/05 tenant hardening + base/06 RLS + base/07 tenant-aware functions"
echo "                     TENANT_CODE / TENANT_NAME set the backfill target (default DEFAULT)"
echo "  WITH_CRON=1        cron/01_scheduled_jobs.sql (needs pg_cron preloaded)"
echo
echo "Deploy finished."
