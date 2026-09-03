#!/usr/bin/env bash
# Run a list of SQL files against a throwaway database and report the result.
# pg_cron must be preloaded into the target database, so the server config is
# rewritten + the cluster restarted for each run.
# usage: ./run_sql.sh <db_name> <file1> [file2 ...]
set -uo pipefail

export PATH=/usr/lib/postgresql/17/bin:$PATH
PGHOST=127.0.0.1
PGPORT=55432
PGUSER=postgres
DATADIR=/tmp/pgdata
CONF=$DATADIR/postgresql.conf

DB="$1"; shift

# point pg_cron at the target database, then restart the cluster
sed -i "s/^cron.database_name = .*/cron.database_name = '$DB'/" "$CONF"
pg_ctl -D "$DATADIR" -l /tmp/pg.log -w -m fast restart >/dev/null 2>&1

psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d postgres -q -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity
    WHERE datname = '$DB' AND pid <> pg_backend_pid();" >/dev/null 2>&1
dropdb   -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" --if-exists "$DB" >/dev/null 2>&1
createdb -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" "$DB" || exit 1

LOG=/tmp/run_${DB}.log
: > "$LOG"

FAIL=0
for f in "$@"; do
    printf '\n===== FILE: %s =====\n' "$f" >> "$LOG"
    if ! psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$DB" \
              -v ON_ERROR_STOP=1 -q -f "$f" >> "$LOG" 2>&1; then
        FAIL=1
        echo "STOPPED at: $f"
        break
    fi
done

echo "--- ERROR lines ---"
grep -E "(ERROR|FATAL|PANIC):" "$LOG" | sort | uniq -c | sort -rn || echo "(none)"
echo "notice_count=$(grep -cE '^NOTICE' "$LOG")"
exit $FAIL
