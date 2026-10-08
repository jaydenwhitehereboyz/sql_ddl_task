
WITH r_tables AS (SELECT *
    FROM dblink(
        'dbname=schema_compare_right user=*** password=***',
        $$SELECT table_schema, table_name
          FROM information_schema.tables
          WHERE table_type = 'BASE TABLE'
            AND table_schema NOT IN ('pg_catalog', 'information_schema')$$
    ) AS t(table_schema TEXT, table_name TEXT)
),

    r_columns AS (
    SELECT *
    FROM dblink(
        'dbname=schema_compare_right user=*** password=***',
        $$SELECT c.table_schema, c.table_name, c.column_name, c.udt_name,
                 c.character_maximum_length, c.numeric_precision, c.numeric_scale, c.is_nullable,
                 col_description((quote_ident(c.table_schema) || '.' || quote_ident(c.table_name))::regclass, c.ordinal_position)
          FROM information_schema.columns c
          WHERE c.table_schema NOT IN ('pg_catalog', 'information_schema')$$
    ) AS t(table_schema TEXT, table_name TEXT, column_name TEXT, udt_name TEXT,
           character_maximum_length INT, numeric_precision INT, numeric_scale INT,
           is_nullable TEXT, column_comment TEXT)
)
,base AS (
    SELECT
        l.table_schema,
        l.table_name,
        l.column_name,
        l.udt_name AS left_udt_name,
        l.character_maximum_length AS left_character_maximum_length,
        l.numeric_precision AS left_numeric_precision,
        l.numeric_scale AS left_numeric_scale,
        l.is_nullable AS left_is_nullable,
        col_description((quote_ident(l.table_schema) || '.' || quote_ident(l.table_name))::regclass, l.ordinal_position) AS left_comment,
        rc.column_name AS right_column_name,
        rc.udt_name AS right_udt_name,
        rc.character_maximum_length AS right_character_maximum_length,
        rc.numeric_precision AS right_numeric_precision,
        rc.numeric_scale AS right_numeric_scale,
        rc.is_nullable AS right_is_nullable,
        rc.column_comment AS right_comment
    FROM information_schema.columns l
    JOIN r_tables rt
        ON l.table_schema = rt.table_schema
        AND l.table_name = rt.table_name
    LEFT JOIN r_columns rc
        ON l.table_schema = rc.table_schema
        AND l.table_name = rc.table_name
        AND l.column_name = rc.column_name
    WHERE l.table_schema NOT IN ('pg_catalog', 'information_schema')
),

typed AS (
    SELECT
        *,
        CASE
            WHEN left_character_maximum_length IS NOT NULL THEN left_udt_name || '(' || left_character_maximum_length || ')'
            WHEN left_udt_name = 'numeric' AND left_numeric_precision IS NOT NULL THEN left_udt_name || '(' || left_numeric_precision || ',' || left_numeric_scale || ')'
            ELSE left_udt_name
        END AS left_type_full,
        CASE
            WHEN right_character_maximum_length IS NOT NULL THEN right_udt_name || '(' || right_character_maximum_length || ')'
            WHEN right_udt_name = 'numeric' AND right_numeric_precision IS NOT NULL THEN right_udt_name || '(' || right_numeric_precision || ',' || right_numeric_scale || ')'
            ELSE right_udt_name
        END AS right_type_full
    FROM base
)


SELECT 1 AS step, table_name, column_name,
       format('ALTER TABLE %I.%I ADD COLUMN %I %s;',
              table_schema, table_name, column_name, left_type_full) AS ddl
			  
			  
FROM typed
WHERE right_column_name IS NULL

UNION ALL
SELECT 2 AS step, table_name, column_name,
       format('ALTER TABLE %I.%I ALTER COLUMN %I TYPE %s USING %I::%s;',
              table_schema, table_name, column_name, left_type_full, column_name, left_type_full) AS ddl
FROM typed
WHERE right_column_name IS NOT NULL
  AND left_type_full IS DISTINCT FROM right_type_full

UNION ALL 
SELECT 3 AS step, table_name, column_name,
       format('ALTER TABLE %I.%I ALTER COLUMN %I %s NOT NULL;',
              table_schema, table_name, column_name,
              CASE WHEN left_is_nullable = 'NO' THEN 'SET' ELSE 'DROP' END) AS ddl
FROM typed
WHERE left_is_nullable IS DISTINCT FROM right_is_nullable AND NOT (right_column_name IS NULL AND left_is_nullable = 'YES')
UNION ALL
SELECT 4 AS step, table_name, column_name,
       format('COMMENT ON COLUMN %I.%I.%I IS %L;', table_schema, table_name, column_name, left_comment) as ddl
FROM typed
WHERE left_comment IS DISTINCT FROM right_comment
ORDER BY step, table_name, column_name;
