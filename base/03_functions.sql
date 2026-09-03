-- ============================================================
-- BASE LAYER / 3: Shared functions
-- file    : base/03_functions.sql
-- objects : 1 statement(s)
-- note    : public.fn_set_updated_at(), used by base/08.
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- ============================================================
-- SECTION 2: GLOBAL FUNCTIONS
-- ============================================================

-- Auto-update updated_at trigger function
CREATE OR REPLACE FUNCTION public.fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
