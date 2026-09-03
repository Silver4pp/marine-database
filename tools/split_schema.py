#!/usr/bin/env python3
"""
Split the single-file schema into the six-layer layout.

    base/     extensions, schema creation, shared + partition functions,
              tenant hardening, RLS, tenant-aware functions, global updated_at
    feature/  one file per schema: tables + that schema's functions + triggers
    index/    every CREATE INDEX (tables and materialized views)
    view/     materialized views and regular views
    cron/     pg_cron jobs
    seed/     reference data, one file per schema

The splitter is statement-aware: it tokenises the SQL (respecting dollar-quoted
bodies, single-quoted strings and comments), assigns every statement to exactly
one file, then writes the files. Nothing is hand-copied, so a statement can never
be silently dropped.

Feature files are numbered in foreign-key dependency order, so `ls feature/`
*is* the load order.

`--verify` re-reads the generated files and asserts the multiset of statements in
the output equals the multiset in the input (modulo the documented fixes in
tools/schema_fixes.py).

Only the files this script owns are written; anything else in those directories
is left alone.
"""
import os
import re
import sys
import argparse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "original", "schema_v1_original.sql")

# schema -> feature file number, in foreign-key dependency order
FEATURE_ORDER = [
    "param", "site", "user", "partner", "buyer", "fleet", "form", "laboratory",
    "survey", "enviro", "commercial", "operational", "voyage", "financial",
    "hse", "security", "audit", "workflow", "document", "telemetry",
]
FEATURE_FILE = {s: f"feature/{i:02d}_{s}.sql" for i, s in enumerate(FEATURE_ORDER, 1)}

SEED_FILE = {s: f"seed/{i:02d}_{s}.sql" for i, s in enumerate(FEATURE_ORDER, 1)}

# hand-written feature files keep the numbering after the generated ones
TITLE = {
    "base/01_extensions.sql": ("BASE LAYER / 1", "PostgreSQL extensions",
        "Run first. Requires superuser or a role with CREATE on the database."),
    "base/02_schemas.sql": ("BASE LAYER / 2", "Schema creation",
        "All 21 application schemas."),
    "base/03_functions.sql": ("BASE LAYER / 3", "Shared functions",
        "public.fn_set_updated_at(), used by base/08."),
    "base/04_partition_functions.sql": ("BASE LAYER / 4", "Partition maintenance functions",
        "public.fn_create_yearly_partition / fn_create_future_partitions. Called by cron/."),
    "base/05_tenant_hardening.sql": ("BASE LAYER / 5", "Tenant hardening",
        "Backfill, FK to security.tenant, NOT NULL, indexes, composite (tenant_id, code) FKs. "
        "Needs PGOPTIONS=\"-c mig.default_tenant_code=CODE\". Hand-written, not generated."),
    "base/06_rls.sql": ("BASE LAYER / 6", "Row level security",
        "ENABLE + FORCE RLS and per-tenant policies. Run as a non-superuser to see it work. "
        "Hand-written, not generated."),
    "base/07_tenant_aware_functions.sql": ("BASE LAYER / 7", "Tenant-aware functions",
        "Redefines the helpers that migration 05 breaks. Hand-written, not generated."),
    "base/08_global_updated_at.sql": ("BASE LAYER / 8", "Global updated_at trigger",
        "MUST run after every table exists, so it comes after the feature layer."),
    "index/01_indexes.sql": ("INDEX LAYER", "All indexes",
        "Tables and materialized views. Includes the partial UNIQUE indexes moved "
        "out of the table bodies (FIX-1..3)."),
    "view/01_materialized_views.sql": ("VIEW LAYER / 1", "Materialized views",
        "Built WITH DATA, so it must run after every source table is populated."),
    "view/02_views.sql": ("VIEW LAYER / 2", "Regular views", ""),
    "cron/01_scheduled_jobs.sql": ("CRON LAYER", "pg_cron jobs",
        "Needs pg_cron preloaded and cron.database_name set. Hand-written, not generated."),
}
for _sch in FEATURE_ORDER:
    TITLE[FEATURE_FILE[_sch]] = ("FEATURE SCHEMA", f"{_sch}", "")
    TITLE[SEED_FILE[_sch]] = ("SEED DATA", f"{_sch} reference data", "")

TITLE.update({
    "feature/21_operational_delivery.sql": ("FEATURE SCHEMA", "operational - trip, manifest, receipt",
        "Hand-written, not generated."),
    "feature/22_enviro.sql": ("FEATURE SCHEMA", "enviro - provenance columns",
        "Hand-written, not generated. See ENVIRO_CANONICAL.md."),
    "feature/23_hse.sql": ("FEATURE SCHEMA", "hse - corrective action",
        "Hand-written, not generated."),
    "feature/24_compliance.sql": ("FEATURE SCHEMA", "compliance registry",
        "Hand-written, not generated."),
    "seed/11_compliance.sql": ("SEED DATA", "compliance requirements", ""),
})


# ---------------------------------------------------------------- tokenizer
def split_statements(sql: str):
    """Yield (statement_text_without_trailing_semicolon, first_line_number)."""
    i, n = 0, len(sql)
    line = 1
    buf = []
    start_line = None
    while i < n:
        ch = sql[i]
        nxt = sql[i + 1] if i + 1 < n else ""

        if ch == "\n":
            line += 1
            buf.append(ch)
            i += 1
            continue

        if ch == "-" and nxt == "-":
            j = sql.find("\n", i)
            j = n if j == -1 else j
            buf.append(sql[i:j])
            i = j
            continue

        if ch == "/" and nxt == "*":
            j = sql.find("*/", i + 2)
            j = n if j == -1 else j + 2
            seg = sql[i:j]
            line += seg.count("\n")
            buf.append(seg)
            i = j
            continue

        if ch == "$":
            m = re.match(r"\$[A-Za-z_0-9]*\$", sql[i:])
            if m:
                tag = m.group(0)
                j = sql.find(tag, i + len(tag))
                j = n if j == -1 else j + len(tag)
                seg = sql[i:j]
                line += seg.count("\n")
                buf.append(seg)
                i = j
                continue

        if ch == "'":
            j = i + 1
            while j < n:
                if sql[j] == "'":
                    if j + 1 < n and sql[j + 1] == "'":
                        j += 2
                        continue
                    j += 1
                    break
                j += 1
            seg = sql[i:j]
            line += seg.count("\n")
            buf.append(seg)
            i = j
            continue

        if ch == ";":
            stmt = "".join(buf).strip()
            if stmt:
                yield stmt, (start_line or line)
            buf = []
            start_line = None
            i += 1
            continue

        if start_line is None and not ch.isspace():
            start_line = line
        buf.append(ch)
        i += 1

    tail = "".join(buf).strip()
    if tail:
        yield tail, (start_line or line)


def strip_banner(stmt: str) -> str:
    """Remove the generated file banner so verification compares code only."""
    keep = [ln for ln in stmt.split("\n")
            if not (ln.startswith("-- file    :")
                    or ln.startswith("-- objects :")
                    or ln.startswith("-- note    :")
                    or ln.startswith("-- generated from original/")
                    or ln.startswith("-- BASE LAYER")
                    or ln.startswith("-- FEATURE SCHEMA")
                    or ln.startswith("-- INDEX LAYER")
                    or ln.startswith("-- VIEW LAYER")
                    or ln.startswith("-- CRON LAYER")
                    or ln.startswith("-- SEED DATA"))]
    return "\n".join(keep)


def strip_comments(stmt: str) -> str:
    """Statement text with comments removed (used for routing and comparing)."""
    stmt = strip_banner(stmt)
    out = []
    for ln in stmt.split("\n"):
        s = ln.strip()
        if s.startswith("--") or s == "":
            continue
        out.append(ln)
    return "\n".join(out).strip()


def schema_of(rel: str) -> str:
    """First identifier of a qualified name, quotes removed."""
    return rel.replace('"', "").split(".")[0]


# ---------------------------------------------------------------- fixes
from schema_fixes import FIXES, EXTRA_INDEXES, EXTRA_STATEMENTS


def apply_fixes(stmt: str) -> str:
    for _fid, old, new, _why in FIXES:
        if old in stmt:
            stmt = stmt.replace(old, new, 1)
    return stmt


def revert_fixes(stmt: str) -> str:
    # Longest replacement first: a short fix's text can be a substring of a
    # longer fix's text, and reverting the short one first corrupts the longer.
    for _fid, old, new, _why in sorted(FIXES, key=lambda f: len(f[2]), reverse=True):
        if new in stmt:
            stmt = stmt.replace(new, old, 1)
    return stmt


# ---------------------------------------------------------------- banners
def banner(rel, count):
    layer, title, note = TITLE[rel]
    lines = [
        "-- ============================================================",
        f"-- {layer}: {title}",
        f"-- file    : {rel}",
        f"-- objects : {count} statement(s)",
    ]
    if note:
        lines.append(f"-- note    : {note}")
    lines.append("-- generated from original/schema_v1_original.sql by tools/split_schema.py")
    lines.append("-- ============================================================")
    return "\n".join(lines)


# ---------------------------------------------------------------- routing
def target_of(stmt: str) -> str:
    code = strip_comments(stmt).upper()
    if not code:
        return "COMMENT_ONLY"

    if code.startswith("CREATE EXTENSION"):
        return "base/01_extensions.sql"

    if code.startswith("CREATE SCHEMA"):
        return "base/02_schemas.sql"

    if code.startswith("CREATE OR REPLACE FUNCTION") and "PUBLIC.FN_SET_UPDATED_AT" in code:
        return "base/03_functions.sql"

    if code.startswith("DO $$") or code.startswith("DO\n$$"):
        return "base/08_global_updated_at.sql"

    if re.match(r"CREATE (UNIQUE )?INDEX", code):
        return "index/01_indexes.sql"

    if code.startswith("CREATE MATERIALIZED VIEW"):
        return "view/01_materialized_views.sql"

    if re.match(r"CREATE (OR REPLACE )?VIEW", code):
        return "view/02_views.sql"

    if code.startswith("CREATE OR REPLACE FUNCTION") and (
        "PUBLIC.FN_CREATE_YEARLY_PARTITION" in code
        or "PUBLIC.FN_CREATE_FUTURE_PARTITIONS" in code
    ):
        return "base/04_partition_functions.sql"

    if code.startswith("CREATE OR REPLACE FUNCTION") or code.startswith("CREATE FUNCTION"):
        m = re.search(r"CREATE OR REPLACE FUNCTION\s+([A-Z_\"][A-Z0-9_\".]*)", code)
        return FEATURE_FILE[schema_of(m.group(1).strip('"').lower())]

    if code.startswith("CREATE OR REPLACE TRIGGER") or code.startswith("CREATE TRIGGER"):
        m = re.search(r"\bON\s+([A-Z_\"][A-Z0-9_\".]*)", code)
        return FEATURE_FILE[schema_of(m.group(1).strip('"').lower())]

    if code.startswith("CREATE TABLE") or code.startswith("ALTER TABLE"):
        m = re.search(r"(?:CREATE TABLE|ALTER TABLE)\s+(?:IF NOT EXISTS\s+)?([A-Z_\"][A-Z0-9_\".]*)", code)
        return FEATURE_FILE[schema_of(m.group(1).strip('"').lower())]

    if code.startswith("INSERT") or code.startswith("WITH "):
        m = re.search(r"INSERT INTO\s+([A-Z_\"][A-Z0-9_\".]*)", code)
        return SEED_FILE[schema_of(m.group(1).replace(chr(34), "").lower())]

    return "UNROUTED.sql"


# ---------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()

    sql = open(SRC, encoding="utf-8").read()
    stmts = list(split_statements(sql))

    buckets = {}
    for stmt, line in stmts:
        buckets.setdefault(target_of(stmt), []).append((stmt, line))

    dropped = len(buckets.pop("COMMENT_ONLY", []))
    if dropped:
        print(f"(skipped {dropped} comment-only block(s))\n")

    if "UNROUTED.sql" in buckets:
        print("!! UNROUTED STATEMENTS:")
        for s, l in buckets["UNROUTED.sql"]:
            print(f"   line {l}: {s[:90]}")
        sys.exit(2)

    order = sorted(buckets)
    total = 0
    print(f"source statements: {len(stmts)}  (routed: {len(stmts) - dropped})\n")
    for f in order:
        print(f"  {f:46s} {len(buckets[f]):3d} stmts")
        total += len(buckets[f])
    print(f"\n  {'TOTAL':46s} {total:3d} stmts")
    assert total == len(stmts) - dropped, "statement count mismatch"

    if args.write:
        for f, items in buckets.items():
            path = os.path.join(ROOT, f)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            head = banner(f, len(items)) if f in TITLE else ""
            body = (head + "\n\n" if head else "") + "\n\n".join(
                apply_fixes(s) + ";" for s, _ in items) + "\n"
            body += EXTRA_INDEXES.get(f, "")
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(body)
        print(f"\nwrote {len(buckets)} files")

    if args.verify:
        out = []
        for f in order:
            path = os.path.join(ROOT, f)
            out.extend(split_statements(open(path, encoding="utf-8").read()))
        a = sorted(x for x in (strip_comments(s) for s, _ in stmts) if x)
        expected_new = set()
        for blob in list(EXTRA_INDEXES.values()) + list(EXTRA_STATEMENTS.values()):
            for st, _ln in split_statements(blob):
                expected_new.add(strip_comments(st))
        b_all = [x for x in (strip_comments(revert_fixes(s)) for s, _ in out) if x]
        b = sorted(x for x in b_all if x not in expected_new)
        for x in sorted(expected_new):
            print(f"  + intentional addition: {x.splitlines()[0][:70]}")
        if a == b:
            print(f"\nVERIFY OK: {len(a)} source statements == {len(b)} split statements "
                  f"(+{len(expected_new)} intentional additions), identical set")
        else:
            print("\nVERIFY FAILED")
            import difflib
            for d in difflib.unified_diff(a, b, "source", "split", lineterm="", n=0):
                print(d[:200])
            sys.exit(1)


if __name__ == "__main__":
    main()
