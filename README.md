# Database schema — six layers, applied in order

The original single-file schema (`original/schema_v1_original.sql`, 2 653 lines)
is split into six directories. Nothing was retyped by hand: a statement-aware
generator does the split and proves it is lossless.

```
db/
├── original/
│   └── schema_v1_original.sql        the untouched source (read-only reference)
│
├── base/                             1 - foundation and cross-cutting concerns
│   ├── 01_extensions.sql             postgis, pgcrypto, btree_gist, pg_cron
│   ├── 02_schemas.sql                the 21 application schemas
│   ├── 03_functions.sql              public.fn_set_updated_at()
│   ├── 04_partition_functions.sql    public.fn_create_yearly_partition / _future_partitions
│   ├── 05_tenant_hardening.sql       backfill → FK → NOT NULL → index → composite FK
│   ├── 06_rls.sql                    ENABLE + FORCE RLS, per-tenant policies
│   ├── 07_tenant_aware_functions.sql the helpers 05 would otherwise break
│   └── 08_global_updated_at.sql      global updated_at trigger (needs every table)
│
├── feature/                          2 - one file per schema: tables, that schema's
│   ├── 01_param.sql … 20_telemetry.sql   functions, that schema's triggers
│   ├── 21_operational_delivery.sql   delivery_trip, delivery_trip_event,
│   │                                 cargo_manifest, delivery_receipt
│   ├── 22_enviro.sql                 provenance for the canonical enviro path
│   ├── 23_hse.sql                    hse.corrective_action
│   └── 24_compliance.sql             compliance.requirement / entity_requirement /
│                                     evaluation / finding / alert
│
├── index/
│   └── 01_indexes.sql                3 - every index, tables and materialized views
│
├── view/
│   ├── 01_materialized_views.sql     4 - the 5 reporting matviews
│   └── 02_views.sql                  4 - v_overdue_actions, v_requirement_status,
│                                         v_station_latency, v_reading_provenance
│
├── cron/
│   └── 01_scheduled_jobs.sql         5 - 5 pg_cron jobs
│
├── seed/
│   ├── 01_param.sql … 19_document.sql    6 - reference data, numbered like feature/
│   └── 21_new_lookup_values.sql      status codes for the new layers
│
├── scripts/
│   ├── deploy.sh                     applies everything in dependency order
│   └── run_sql.sh                    test harness: applies files to a throwaway database
├── test/
│   ├── 00_stub_auth.sql              Supabase auth stub for local runs only
│   ├── 01_grant_app_user.sql         grants for the non-superuser RLS test role
│   ├── 10_smoke_test.sql             original schema: constraints + triggers fire
│   ├── 20_smoke_test_v2.sql          new entities, composite FKs, provenance
│   └── 21_smoke_test_rls.sql         RLS tenant isolation (run as a non-superuser)
└── tools/
    ├── split_schema.py               the generator + lossless verifier
    └── schema_fixes.py               every correction to the original, in one place
```

Docs: `NOTES.md` (what was fixed, what was deliberately not), `ENVIRO_CANONICAL.md`
(which environmental table is authoritative for what).

## Splitting rule

A file contains exactly one kind of thing, and every SQL statement in the original
appears in exactly one file:

| Kind of statement | Goes to |
|---|---|
| `CREATE EXTENSION` | `base/01` |
| `CREATE SCHEMA` | `base/02` |
| `public.fn_set_updated_at` | `base/03` |
| `public.fn_create_*partition*` | `base/04` |
| the global `updated_at` `DO $$` block | `base/08` |
| `CREATE TABLE` / `ALTER TABLE` / `CREATE FUNCTION` / `CREATE TRIGGER` | `feature/<nn>_<schema>.sql` |
| `CREATE INDEX` / `CREATE UNIQUE INDEX` | `index/01` |
| `CREATE MATERIALIZED VIEW` | `view/01` |
| `CREATE VIEW` | `view/02` |
| `INSERT` / `WITH … INSERT` | `seed/<nn>_<schema>.sql` |

Feature files keep their own functions and triggers next to their tables, because
a trigger cannot be created before the table it fires on.

Numbering **is** the load order in `feature/` and `seed/`: `01_param` … `20_telemetry`
are generated in foreign-key dependency order, and the hand-written files continue
from `21` onwards. Files the generator owns (`01`–`20`) are rewritten on every
`--write`; everything else is left alone, so hand-written files are safe to edit.

## Deploy

```bash
./scripts/deploy.sh "postgresql://user:pass@host:5432/dbname"
```

Order, and why it cannot be rearranged:

```
base/01-04   extensions, schemas, shared + partition functions
feature/*    tables, per-schema functions and triggers
base/08      global updated_at trigger - needs EVERY table to exist
view/01      materialized views
view/02      regular views
index/01     indexes, including the ones ON the materialized views
seed/*       reference data
base/05-07   tenant hardening, RLS, tenant-aware functions   (optional)
cron/01      pg_cron jobs                                    (optional)
```

`index/` comes after `view/` because `index/01` holds the unique indexes the
materialized views need for `REFRESH … CONCURRENTLY`. `base/05` comes after
`seed/` because it backfills `tenant_id` on the rows the seeds inserted and only
then sets `NOT NULL` — reference data does not have to know about tenants.

Each file runs with `ON_ERROR_STOP=1` inside one transaction, and a failure stops
the run — including the optional stages, which used to print `ok` after failing.

`deploy.sh` is **create-only** — like the original file, the `CREATE TABLE`
statements have no `IF NOT EXISTS`, so re-running it against a populated database
stops with `relation "…" already exists`.

### Optional stages

| Variable | Adds | Notes |
|---|---|---|
| `WITH_HARDENING=1` | `base/05`, `base/06`, `base/07` | tenant FK/NOT NULL/indexes/composite FKs, then RLS, then tenant-aware functions |
| `WITH_CRON=1` | `cron/01` | needs `pg_cron` preloaded and `cron.database_name` |
| `TENANT_CODE` / `TENANT_NAME` | — | tenant that existing rows are backfilled into (default `DEFAULT` / `DefaultTenant`) |

```bash
WITH_HARDENING=1 WITH_CRON=1 TENANT_CODE=DEFAULT ./scripts/deploy.sh "$DB_URL"
```

`base/07` is not optional once `base/05` has run: `workflow.fn_start_instance`,
`document.fn_upload_document` and `buyer.fn_reverse_ledger_entry` insert into
tenant-scoped tables without supplying `tenant_id`, so after 05 they fail with
`null value in column "tenant_id"`. The first two are redefined with a trailing
`p_tenant_id` parameter defaulting to the caller's current tenant; the reversal
takes the tenant from the entry it reverses.

`base/05` **aborts before touching anything** unless a tenant code is supplied —
it will not invent a tenant behind your back:

```bash
PGOPTIONS="-c mig.default_tenant_code=DEFAULT" \
  psql "$DB_URL" -v ON_ERROR_STOP=1 -f base/05_tenant_hardening.sql
```

A psql `-v` variable is client-side only and `current_setting()` cannot see it,
which is why the code travels as a dotted GUC. The tenant *name* may contain
spaces, which `PGOPTIONS` cannot carry (the backend splits its options on
whitespace and rejects the remainder), so the name goes in as a psql variable:

```bash
psql "$DB_URL" -v mig_name="Default Tenant" -f base/05_tenant_hardening.sql
```

## Regenerating

```bash
python3 tools/split_schema.py --write --verify
```

`--verify` re-reads the generated files and compares the statement set against the
source. Last run: **276 source statements == 276 split statements, plus 5
documented additions, identical set.**

Corrections live in `tools/schema_fixes.py`, so they survive regeneration.

## Testing locally

The `security` schema references `auth.users` and `auth.uid()`, so a plain
PostgreSQL server needs a stub, and the RLS test needs a role without `BYPASSRLS`:

```bash
psql "$DB_URL" -f test/00_stub_auth.sql      # never run this on real Supabase
WITH_HARDENING=1 WITH_CRON=1 ./scripts/deploy.sh "$DB_URL"
psql "$DB_URL" -f test/01_grant_app_user.sql
psql "$DB_URL" -f test/10_smoke_test.sql
psql "$DB_URL" -f test/20_smoke_test_v2.sql
psql "$DB_URL" -U app_user -f test/21_smoke_test_rls.sql
```

Expected output on a clean database: **test 10 → 3 errors, test 20 → 6 errors,
test 21 → 1 blocked write.** Every one of those is a negative assertion that the
constraint or policy did its job; they are listed in `NOTES.md`.

`test/21` must run as a **non-superuser**. A superuser has `BYPASSRLS` and skips
every policy, so running it as `postgres` passes vacuously — the script raises
rather than report a meaningless result. It also reads the `TA`/`TB` fixtures
`test/20` creates, so run 20 first.
