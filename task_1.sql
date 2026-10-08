WITH r_tables AS (
    SELECT *
    FROM dblink(
        'dbname=schema_compare_right user=*** password=***',
        $$SELECT table_schema, table_name
          FROM information_schema.tables
          WHERE table_type = 'BASE TABLE'
            AND table_schema NOT IN ('pg_catalog', 'information_schema')$$
    ) AS t(table_schema TEXT, table_name TEXT)
)
SELECT l.table_name,
       l.table_schema AS left_schema,
       r.table_schema AS right_schema
FROM information_schema.tables l
JOIN r_tables r
  ON l.table_schema = r.table_schema
 AND l.table_name = r.table_name
WHERE l.table_type = 'BASE TABLE'
  AND l.table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY l.table_schema, l.table_name;



WITH r AS (
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
),
cte AS (
    SELECT
        l.table_schema AS left_table_schema,
        l.table_name AS left_table_name,
        l.column_name AS left_column_name,
        l.udt_name AS left_udt_name,
        l.character_maximum_length AS left_character_maximum_length,
        l.numeric_precision AS left_numeric_precision,
        l.numeric_scale AS left_numeric_scale,
        l.is_nullable AS left_is_nullable,
        col_description((quote_ident(l.table_schema) || '.' || quote_ident(l.table_name))::regclass, l.ordinal_position) AS left_comment,
        r.table_schema AS right_table_schema,
        r.table_name AS right_table_name,
        r.column_name AS right_column_name,
        r.udt_name AS right_udt_name,
        r.character_maximum_length AS right_character_maximum_length,
        r.numeric_precision AS right_numeric_precision,
        r.numeric_scale AS right_numeric_scale,
        r.is_nullable AS right_is_nullable,
        r.column_comment AS right_comment
    FROM information_schema.columns l
    JOIN r
        ON l.table_schema = r.table_schema
        AND l.table_name = r.table_name
        AND l.column_name = r.column_name
    WHERE l.table_schema NOT IN ('pg_catalog', 'information_schema')
        AND (l.udt_name IS DISTINCT FROM r.udt_name
            OR l.character_maximum_length IS DISTINCT FROM r.character_maximum_length
            OR l.numeric_precision IS DISTINCT FROM r.numeric_precision
            OR l.numeric_scale IS DISTINCT FROM r.numeric_scale
            OR col_description((quote_ident(l.table_schema) || '.' || quote_ident(l.table_name))::regclass, l.ordinal_position) IS DISTINCT FROM r.column_comment
            OR l.is_nullable IS DISTINCT FROM r.is_nullable)
),
typed AS (
    SELECT
        left_table_schema,
        right_table_schema,
        left_table_name AS table_name,
        left_column_name AS column_name,
        left_comment,
        right_comment,
        CASE WHEN left_is_nullable IS DISTINCT FROM right_is_nullable THEN
            CASE WHEN left_is_nullable = 'YES' THEN 'null' ELSE 'not null' END || '\' ||
            CASE WHEN right_is_nullable = 'YES' THEN 'null' ELSE 'not null' END
        END AS is_null,
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
    FROM cte
)
SELECT
    left_table_schema AS left_schema,
    right_table_schema AS right_schema,
    table_name,
    column_name,
    is_null,
    CASE WHEN left_type_full IS DISTINCT FROM right_type_full
        THEN left_type_full || '\' || right_type_full
    END AS type_diff,
    CASE WHEN left_comment IS DISTINCT FROM right_comment
        THEN '"' || COALESCE(left_comment, '') || '"\"' || COALESCE(right_comment, '') || '"'
    END AS name_diff
FROM typed
ORDER BY table_name, column_name;
