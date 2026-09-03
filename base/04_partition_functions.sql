-- ============================================================
-- BASE LAYER / 4: Partition maintenance functions
-- file    : base/04_partition_functions.sql
-- objects : 2 statement(s)
-- note    : public.fn_create_yearly_partition / fn_create_future_partitions. Called by cron/.
-- generated from original/schema_v1_original.sql by tools/split_schema.py
-- ============================================================

-- Create yearly partition
CREATE OR REPLACE FUNCTION public.fn_create_yearly_partition(p_schema_name TEXT, p_table_name TEXT, p_year INT)
RETURNS VOID AS $$
DECLARE v_partition_name TEXT := p_table_name || '_' || p_year;
    v_start_date TEXT := p_year || '-01-01'; v_end_date TEXT := (p_year + 1) || '-01-01';
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = p_schema_name AND tablename = v_partition_name) THEN
        EXECUTE format('CREATE TABLE %I.%I PARTITION OF %I.%I FOR VALUES FROM (%L) TO (%L)', p_schema_name, v_partition_name, p_schema_name, p_table_name, v_start_date, v_end_date);
        RAISE NOTICE 'Created partition: %.%', p_schema_name, v_partition_name;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create future partitions
CREATE OR REPLACE FUNCTION public.fn_create_future_partitions(p_schema_name TEXT, p_table_name TEXT, p_years_ahead INT DEFAULT 5)
RETURNS VOID AS $$
DECLARE v_current_year INT := EXTRACT(YEAR FROM CURRENT_DATE)::INT; v_year INT;
BEGIN
    FOR v_year IN v_current_year..(v_current_year + p_years_ahead) LOOP PERFORM public.fn_create_yearly_partition(p_schema_name, p_table_name, v_year); END LOOP;
END;
$$ LANGUAGE plpgsql;
