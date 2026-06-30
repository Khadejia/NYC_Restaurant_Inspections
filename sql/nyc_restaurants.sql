-- ============================================================================
-- PROJECT:     NYC Restaurant Health Inspections (2022-2025)
-- DATABASE:    PostgreSQL
-- AUTHOR:      Khadejia Viveros
--
-- PROJECT OVERVIEW:
-- This script runs the end-to-end data pipeline for cleaning, transforming, 
-- and analyzing NYC restaurant health inspections. It processes unfiltered data, 
-- enforces datatype constraints, handles empty attributes, and builds a 
-- structured final dataset tailored directly for interactive Tableau dashboards.
-- ============================================================================

-- ============================================================
-- SECTION 1: CREATE TABLES
-- Set up raw staging environments to land original city datasets.
-- ============================================================

-- SOURCE STAGING TABLE FOR UNFILTERED DATA
CREATE TABLE inspections_staging (
    camis               VARCHAR(20),
    dba                 VARCHAR(200),
    boro                VARCHAR(50),
    building            VARCHAR(20),
    street              VARCHAR(100),
    zipcode             VARCHAR(10),
    phone               VARCHAR(20),
    cuisine_description VARCHAR(100),
    inspection_date     VARCHAR(30),
    action              VARCHAR(300),
    violation_code      VARCHAR(20),
    violation_description TEXT,
    critical_flag       VARCHAR(20),
    score               VARCHAR(10),
    grade               VARCHAR(5),
    grade_date          VARCHAR(30),
    record_date         VARCHAR(30),
    inspection_type     VARCHAR(100),
    latitude            NUMERIC(10,7),
    longitude           NUMERIC(10,7),
    community_board     VARCHAR(10),
    council_district    VARCHAR(10),
    census_tract        VARCHAR(10),
    bin                 VARCHAR(20),
    bbl                 VARCHAR(20),
    nta                 VARCHAR(10)
);

-- ============================================================
-- SECTION 2: DATA IMPORT OVERVIEW
-- Notes source file context and origin repository tracks.
-- ============================================================

-- CSV datasets were imported into PostgreSQL prior to analysis.
-- Source files are included in the project repository.
-- Source: NYC OpenData — DOHMH Restaurant Inspection Results
-- URL: https://data.cityofnewyork.us/Health/DOHMH-New-York-City-Restaurant-Inspection-Results/43nn-pn8j

-- ============================================================
-- SECTION 3: VERIFY IMPORTS
-- Check row volumes and sample rows to guarantee accurate ingest.
-- ============================================================

SELECT 
    COUNT(*) AS total_rows
FROM inspections_staging;

SELECT 
    *
FROM inspections_staging
LIMIT 5;

-- ============================================================
-- SECTION 4: CREATE CLEANING TABLE (STAGING)
-- Isolate working data records to safeguard source imports.
-- ============================================================

CREATE TABLE inspections_core AS
SELECT 
    *
FROM inspections_staging;

-- ============================================================
-- SECTION 5: REMOVE DUPLICATE RECORDS
-- Isolates system CTIDs via row numbers to purge redundant elements.
-- ============================================================

DELETE FROM inspections_core
WHERE ctid IN (
    SELECT 
        ctid
    FROM (
        SELECT
            ctid,
            ROW_NUMBER() OVER (
                PARTITION BY
                    camis,
                    inspection_date,
                    violation_code,
                    inspection_type
                ORDER BY 
                    inspection_date
            ) AS row_num
        FROM inspections_core
    ) duplicates
    WHERE row_num > 1
);

-- ============================================================
-- SECTION 6: REMOVE INVALID DATES
-- Drops system default placeholders or blank rows before calculation.
-- ============================================================

DELETE FROM inspections_core
WHERE inspection_date = '1900-01-01'
   OR inspection_date IS NULL
   OR TRIM(inspection_date) = '';

SELECT 
    COUNT(*) AS rows_after_date_filter
FROM inspections_core;

-- ============================================================
-- SECTION 7: HANDLE MISSING VALUES
-- Normalizes empty string fields into uniform descriptive defaults.
-- ============================================================

UPDATE inspections_core
SET
    boro = COALESCE(NULLIF(TRIM(boro), ''), 'Unknown'),
    grade = COALESCE(NULLIF(TRIM(grade), ''), 'Unknown'),
    cuisine_description = COALESCE(NULLIF(TRIM(cuisine_description), ''), 'Other');

-- ============================================================
-- SECTION 8: CLEAN DATA TYPES
-- Converts textual entries into native typed date and integer fields.
-- ============================================================

ALTER TABLE inspections_core
    ADD COLUMN inspection_date_clean DATE,
    ADD COLUMN grade_date_clean DATE,
    ADD COLUMN score_clean INTEGER;

UPDATE inspections_core
SET inspection_date_clean = TO_DATE(inspection_date, 'MM/DD/YYYY')
WHERE inspection_date IS NOT NULL
  AND TRIM(inspection_date) != '';

UPDATE inspections_core
SET grade_date_clean = TO_DATE(grade_date, 'MM/DD/YYYY')
WHERE grade_date IS NOT NULL
  AND TRIM(grade_date) != '';

UPDATE inspections_core
SET score_clean = CAST(score AS INTEGER)
WHERE score ~ '^\d+$';

-- ============================================================
-- SECTION 9: ADD TABLEAU DATE COLUMNS
-- Derives optimized calendar breakdown intervals for Tableau sorting.
-- ============================================================

ALTER TABLE inspections_core
    ADD COLUMN inspection_year INTEGER,
    ADD COLUMN inspection_month VARCHAR(7),
    ADD COLUMN inspection_quarter VARCHAR(7);

UPDATE inspections_core
SET 
    inspection_year = EXTRACT(YEAR FROM inspection_date_clean),
    inspection_month = TO_CHAR(inspection_date_clean, 'YYYY-MM'),
    inspection_quarter = CONCAT(
        EXTRACT(YEAR FROM inspection_date_clean),
        '-Q',
        EXTRACT(QUARTER FROM inspection_date_clean)
    );

-- ============================================================
-- SECTION 10: CREATE FINAL TABLE FOR TABLEAU
-- Filters for actionable timelines, regular cycle types, and explicit scores.
-- ============================================================

CREATE TABLE inspections_final AS
SELECT 
    *
FROM inspections_core
WHERE inspection_year >= 2022
  AND inspection_type ILIKE '%Cycle%'
  AND grade IN ('A', 'B', 'C')
  AND score_clean IS NOT NULL;

SELECT 
    COUNT(*) AS clean_rows
FROM inspections_final;

-- ============================================================
-- SECTION 11: STANDARDIZE BOROUGHS
-- Enforces title capitalization patterns over geographic descriptions.
-- ============================================================

UPDATE inspections_final
SET boro = INITCAP(TRIM(boro));

SELECT 
    DISTINCT boro
FROM inspections_final
ORDER BY boro;

-- ============================================================
-- SECTION 12: STANDARDIZE CUISINES
-- Compresses diverse menu entries down to high-level market sectors.
-- ============================================================

UPDATE inspections_final
SET cuisine_description =
    CASE
        WHEN cuisine_description ILIKE '%american%' THEN 'American'
        WHEN cuisine_description ILIKE '%chinese%' THEN 'Chinese'
        WHEN cuisine_description ILIKE '%italian%' THEN 'Italian'
        WHEN cuisine_description ILIKE '%mexican%' OR cuisine_description ILIKE '%latin%' THEN 'Mexican'
        WHEN cuisine_description ILIKE '%japanese%' OR cuisine_description ILIKE '%sushi%' THEN 'Japanese'
        WHEN cuisine_description ILIKE '%indian%' THEN 'Indian'
        WHEN cuisine_description ILIKE '%caribbean%' THEN 'Caribbean'
        WHEN cuisine_description ILIKE '%mediterranean%' OR cuisine_description ILIKE '%greek%' THEN 'Mediterranean'
        WHEN cuisine_description ILIKE '%bakery%' OR cuisine_description ILIKE '%coffee%' OR cuisine_description ILIKE '%cafe%' THEN 'Bakery & Cafe'
        WHEN cuisine_description ILIKE '%seafood%' OR cuisine_description ILIKE '%fish%' THEN 'Seafood'
        ELSE cuisine_description
    END;

-- ============================================================
-- SECTION 13: COMPUTE CUSTOM ATTRIBUTES (FEATURE ENGINEERING)
-- Generates discrete category thresholds and Boolean flag switches.
-- ============================================================

-- SCORE CATEGORY BINNING
ALTER TABLE inspections_final
    ADD COLUMN score_category VARCHAR(20);

UPDATE inspections_final
SET score_category =
    CASE
        WHEN score_clean <= 13 THEN 'Grade A (0-13)'
        WHEN score_clean <= 27 THEN 'Grade B (14-27)'
        ELSE 'Grade C (28+)'
    END;

-- CRITICAL FLAG SIMPLIFICATION
ALTER TABLE inspections_final
    ADD COLUMN is_critical VARCHAR(5);

UPDATE inspections_final
SET is_critical =
    CASE
        WHEN critical_flag = 'Critical' THEN 'Yes'
        WHEN critical_flag = 'Not Critical' THEN 'No'
        ELSE 'N/A'
    END;

-- ============================================================================
-- SECTION 14: QUALITY ASSURANCE (QA) ON COMBINED TABLE
-- Runs validation queries to ensure dates, row counts, and performance averages
-- match expectations before opening the data to Tableau.
-- ============================================================================

SELECT 
    COUNT(*) AS total_records
FROM inspections_final;

SELECT 
    MIN(inspection_date_clean) AS earliest,
    MAX(inspection_date_clean) AS latest
FROM inspections_final;

SELECT 
    inspection_year,
    COUNT(*) AS inspections,
    ROUND(AVG(score_clean), 1) AS avg_score
FROM inspections_final
GROUP BY 
    inspection_year
ORDER BY 
    inspection_year;

-- ============================================================
-- SECTION 15: CREATE INDEXES
-- Builds target physical index references to optimize dashboard filter speeds.
-- ============================================================

CREATE INDEX idx_inspection_camis ON inspections_final(camis);
CREATE INDEX idx_borough ON inspections_final(boro);
CREATE INDEX idx_inspection_date ON inspections_final(inspection_date_clean);
CREATE INDEX idx_cuisine ON inspections_final(cuisine_description);

-- ============================================================
-- SECTION 16: TABLEAU DASHBOARD AGGREGATIONS
-- High-level aggregations designed to feed charts and dynamic KPIs.
-- ============================================================

-- MONTHLY INSPECTION LINE PATTERNS
SELECT 
    inspection_month,
    COUNT(DISTINCT camis) AS restaurants_inspected,
    COUNT(*) AS total_inspections,
    ROUND(AVG(score_clean), 1) AS avg_score
FROM inspections_final
GROUP BY 
    inspection_month
ORDER BY 
    inspection_month;

-- BOROUGH METRIC OVERVIEWS
SELECT 
    boro,
    COUNT(DISTINCT camis) AS restaurants,
    COUNT(*) AS inspections,
    ROUND(AVG(score_clean), 1) AS avg_score
FROM inspections_final
WHERE boro IS NOT NULL
GROUP BY 
    boro
ORDER BY 
    inspections DESC;

-- GLOBAL GRADE DISTRIBUTIONS
SELECT 
    grade,
    event_count AS count,
    ROUND(event_count * 100.0 / SUM(event_count) OVER (), 1) AS pct
FROM (
    SELECT 
        grade, 
        COUNT(*) AS event_count
    FROM inspections_final
    GROUP BY 
        grade
) grade_counts
ORDER BY 
    count DESC;

-- INCIDENT FREQUENCY RATING (TOP 10 VIOLATIONS)
SELECT 
    violation_description,
    COUNT(*) AS frequency,
    SUM(CASE WHEN is_critical = 'Yes' THEN 1 ELSE 0 END) AS critical_count
FROM inspections_final
WHERE violation_description IS NOT NULL
GROUP BY 
    violation_description
ORDER BY 
    frequency DESC
LIMIT 10;

-- ============================================================
-- SECTION 17: MASTER PORTFOLIO EXPORT
-- The primary select statement used to stream records down to flat outputs.
-- ============================================================

SELECT
    camis,
    dba AS restaurant_name,
    boro,
    building || ' ' || street AS address,
    zipcode,
    cuisine_description,
    inspection_date_clean AS inspection_date,
    inspection_year,
    inspection_type,
    score_clean AS score,
    grade,
    score_category,
    critical_flag,
    is_critical,
    violation_code,
    violation_description,
    latitude,
    longitude
FROM inspections_final
ORDER BY 
    inspection_date_clean DESC;

-- ============================================================
-- SECTION 18: ADVANCED BUSINESS ANALYSIS EXPLORATION
-- Deep-dive queries using professional syntax constructs (CTEs, 
-- Window Functions, and Filtering) to pull key business insights.
-- ============================================================

-- [INSPECTION COUNTS CTE]: Isolates top 20 business entities by case tracking numbers
WITH inspection_counts AS (
    SELECT
        camis,
        dba,
        COUNT(*) AS inspections
    FROM inspections_final
    GROUP BY 
        camis, 
        dba
)
SELECT
    dba,
    inspections
FROM inspection_counts
ORDER BY 
    inspections DESC
LIMIT 20;

-- [WINDOW OVER RANKINGS]: Assigns strict positional rankings over geographic case totals
SELECT
    boro,
    COUNT(*) AS inspections,
    RANK() OVER (
        ORDER BY COUNT(*) DESC
    ) AS borough_rank
FROM inspections_final
GROUP BY 
    boro;

-- [PARTITIONED ROW NUMBERING]: Extracts the leading industry food choice across each borough zone
WITH cuisine_rank AS (
    SELECT
        boro,
        cuisine_description,
        COUNT(*) AS inspections,
        ROW_NUMBER() OVER (
            PARTITION BY boro
            ORDER BY COUNT(*) DESC
        ) AS ranking
    FROM inspections_final
    GROUP BY
        boro,
        cuisine_description
)
SELECT
    boro,
    cuisine_description,
    inspections
FROM cuisine_rank
WHERE ranking = 1;

-- [RUNNING TOTAL WINDOWS]: Compiles vertical timeline increments over month-by-month cases
SELECT
    inspection_month,
    COUNT(*) AS inspections,
    SUM(COUNT(*)) OVER (
        ORDER BY inspection_month
    ) AS running_total
FROM inspections_final
GROUP BY 
    inspection_month;

-- [LAG DELTA COMPARISONS]: References preceding records to determine periodic growth rates
WITH monthly_totals AS (
    SELECT
        inspection_month,
        COUNT(*) AS inspections
    FROM inspections_final
    GROUP BY 
        inspection_month
)
SELECT
    inspection_month,
    inspections,
    LAG(inspections) OVER (
        ORDER BY inspection_month
    ) AS previous_month,
    inspections - LAG(inspections) OVER (
        ORDER BY inspection_month
    ) AS monthly_change
FROM monthly_totals;

-- [HAVING CLAUSE FILTERING]: Flags sector tracks demonstrating high violation patterns
SELECT
    cuisine_description,
    ROUND(AVG(score_clean), 1) AS avg_score,
    COUNT(*) AS inspections
FROM inspections_final
GROUP BY 
    cuisine_description
HAVING COUNT(*) >= 25
ORDER BY 
    avg_score DESC;

-- [SUBQUERY VALUE SCALING]: Isolates separate operational rows scaling above global metrics
SELECT
    dba,
    score_clean,
    inspection_date_clean
FROM inspections_final
WHERE score_clean > (
    SELECT 
        AVG(score_clean) 
    FROM inspections_final
)
ORDER BY 
    score_clean DESC;

-- [PARTITIONED SCALE CALCULATIONS]: Ratios local metric frequencies relative to borough areas
SELECT
    boro,
    grade,
    COUNT(*) AS inspections,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY boro),
        1
    ) AS pct_borough
FROM inspections_final
GROUP BY
    boro,
    grade
ORDER BY
    boro,
    grade;

-- [FILTER EXERCISES]: Isolates target high-priority critical indicators among categorical lists
SELECT
    cuisine_description,
    COUNT(*) FILTER (WHERE is_critical = 'Yes') AS critical_violations,
    COUNT(*) AS inspections
FROM inspections_final
GROUP BY 
    cuisine_description
ORDER BY 
    critical_violations DESC;

-- [NESTED PERFORMANCE AGGREGATIONS]: Evaluates established restaurant chains with repeated records
WITH restaurant_scores AS (
    SELECT
        dba,
        ROUND(AVG(score_clean), 1) AS avg_score,
        COUNT(*) AS inspections
    FROM inspections_final
    GROUP BY 
        dba
    HAVING COUNT(*) >= 3
)
SELECT
    dba,
    avg_score,
    RANK() OVER (
        ORDER BY avg_score DESC
    ) AS score_rank
FROM restaurant_scores
ORDER BY 
    score_rank
LIMIT 20;

-- [GEOGRAPHIC GROUPINGS]: Measures clean average health scores across operational districts
SELECT
    boro,
    ROUND(AVG(score_clean), 1) AS avg_score,
    COUNT(*) AS inspections
FROM inspections_final
GROUP BY 
    boro
ORDER BY 
    avg_score DESC;

-- [CASE LOGIC CLASSIFIER]: Profiles general performance tiers without re-writing master files
SELECT
    dba,
    AVG(score_clean) AS avg_score,
    COUNT(*) AS inspections,
    CASE
        WHEN AVG(score_clean) <= 13 THEN 'Excellent'
        WHEN AVG(score_clean) <= 27 THEN 'Satisfactory'
        ELSE 'Needs Improvement'
    END AS performance
FROM inspections_final
GROUP BY 
    dba
HAVING COUNT(*) >= 3
ORDER BY 
    avg_score;

-- [DENSE RANK RANKINGS]: Evaluates recurring health code breaches by true index volumes
SELECT
    violation_description,
    COUNT(*) AS occurrences,
    DENSE_RANK() OVER (
        ORDER BY COUNT(*) DESC
    ) AS violation_rank
FROM inspections_final
GROUP BY 
    violation_description
ORDER BY 
    violation_rank
LIMIT 15;
