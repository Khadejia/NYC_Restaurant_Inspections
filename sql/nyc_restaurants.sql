-- ============================================================
-- PROJECT : NYC RESTAURANT HEALTH INSPECTIONS 2022-2025
-- DATABASE: PostgreSQL
-- DESCRIPTION:
-- End-to-end SQL workflow for data cleaning,
-- transformation, and analytical exploration.
-- AUTHOR  : Khadejia Viveros
-- ============================================================

-- ============================================================
-- SECTION 1: CREATE TABLES
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
-- SECTION 2: DATA IMPORT NOTE
-- ============================================================

-- CSV datasets were imported into PostgreSQL prior to analysis.
-- Source files are included in the project repository.
-- Source: NYC OpenData — DOHMH Restaurant Inspection Results
-- URL: https://data.cityofnewyork.us/Health/DOHMH-New-York-City-Restaurant-Inspection-Results/43nn-pn8j


-- ============================================================
-- SECTION 3: VERIFY IMPORTS
-- Validate successful dataset imports
-- ============================================================

SELECT COUNT(*) AS total_rows
FROM inspections_staging;

SELECT *
FROM inspections_staging
LIMIT 5;


-- ============================================================
-- SECTION 4: CREATE CLEANING TABLE
-- ============================================================

CREATE TABLE inspections_core AS
SELECT *
FROM inspections_staging;


-- ============================================================
-- SECTION 5: REMOVE INVALID DATES
-- ============================================================

DELETE FROM inspections_core
WHERE inspection_date = '1900-01-01'
   OR inspection_date IS NULL
   OR TRIM(inspection_date) = '';

SELECT COUNT(*) AS rows_after_date_filter
FROM inspections_core;


-- ============================================================
-- SECTION 6: CLEAN DATA TYPES
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
-- SECTION 7: ADD TABLEAU DATE COLUMNS
-- ============================================================

ALTER TABLE inspections_core
    ADD COLUMN inspection_year INTEGER,
    ADD COLUMN inspection_month VARCHAR(7),
    ADD COLUMN inspection_quarter VARCHAR(7);

UPDATE inspections_core
SET inspection_year = EXTRACT(YEAR FROM inspection_date_clean),
    inspection_month = TO_CHAR(inspection_date_clean, 'YYYY-MM'),
    inspection_quarter = CONCAT(
        EXTRACT(YEAR FROM inspection_date_clean),
        '-Q',
        EXTRACT(QUARTER FROM inspection_date_clean)
    );


-- ============================================================
-- SECTION 8: CREATE FINAL TABLE FOR TABLEAU
-- ============================================================

CREATE TABLE inspections_final AS
SELECT *
FROM inspections_core
WHERE inspection_year >= 2022
  AND inspection_type ILIKE '%Cycle%'
  AND grade IN ('A', 'B', 'C')
  AND score_clean IS NOT NULL;

SELECT COUNT(*) AS clean_rows
FROM inspections_final;


-- ============================================================
-- SECTION 9: STANDARDIZE BOROUGHS
-- ============================================================

UPDATE inspections_final
SET boro = INITCAP(TRIM(boro));

SELECT DISTINCT boro
FROM inspections_final
ORDER BY boro;


-- ============================================================
-- SECTION 10: STANDARDIZE CUISINES
-- ============================================================

UPDATE inspections_final
SET cuisine_description = 'American'
WHERE cuisine_description ILIKE '%american%';

UPDATE inspections_final
SET cuisine_description = 'Chinese'
WHERE cuisine_description ILIKE '%chinese%';

UPDATE inspections_final
SET cuisine_description = 'Italian'
WHERE cuisine_description ILIKE '%italian%';

UPDATE inspections_final
SET cuisine_description = 'Mexican'
WHERE cuisine_description ILIKE '%mexican%'
   OR cuisine_description ILIKE '%latin%';

UPDATE inspections_final
SET cuisine_description = 'Japanese'
WHERE cuisine_description ILIKE '%japanese%'
   OR cuisine_description ILIKE '%sushi%';

UPDATE inspections_final
SET cuisine_description = 'Indian'
WHERE cuisine_description ILIKE '%indian%';

UPDATE inspections_final
SET cuisine_description = 'Caribbean'
WHERE cuisine_description ILIKE '%caribbean%';

UPDATE inspections_final
SET cuisine_description = 'Mediterranean'
WHERE cuisine_description ILIKE '%mediterranean%'
   OR cuisine_description ILIKE '%greek%';

UPDATE inspections_final
SET cuisine_description = 'Bakery & Cafe'
WHERE cuisine_description ILIKE '%bakery%'
   OR cuisine_description ILIKE '%cafe%'
   OR cuisine_description ILIKE '%coffee%';

UPDATE inspections_final
SET cuisine_description = 'Seafood'
WHERE cuisine_description ILIKE '%seafood%'
   OR cuisine_description ILIKE '%fish%';

UPDATE inspections_final
SET cuisine_description = 'Other'
WHERE cuisine_description IS NULL
   OR TRIM(cuisine_description) = '';


-- ============================================================
-- SECTION 11: SCORE CATEGORY
-- ============================================================

ALTER TABLE inspections_final
ADD COLUMN score_category VARCHAR(20);

UPDATE inspections_final
SET score_category =
    CASE
        WHEN score_clean <= 13 THEN 'Grade A (0-13)'
        WHEN score_clean <= 27 THEN 'Grade B (14-27)'
        ELSE 'Grade C (28+)'
    END;


-- ============================================================
-- SECTION 12: CRITICAL FLAG
-- ============================================================

ALTER TABLE inspections_final
ADD COLUMN is_critical VARCHAR(5);

UPDATE inspections_final
SET is_critical =
    CASE
        WHEN critical_flag = 'Critical' THEN 'Yes'
        WHEN critical_flag = 'Not Critical' THEN 'No'
        ELSE 'N/A'
    END;


-- ============================================================
-- SECTION 13: VERIFY FINAL TABLE
-- ============================================================

SELECT COUNT(*) AS total_records
FROM inspections_final;

SELECT MIN(inspection_date_clean) AS earliest,
       MAX(inspection_date_clean) AS latest
FROM inspections_final;

SELECT inspection_year,
       COUNT(*) AS inspections,
       ROUND(AVG(score_clean), 1) AS avg_score
FROM inspections_final
GROUP BY inspection_year
ORDER BY inspection_year;


-- ============================================================
-- SECTION 14: TABLEAU ANALYSIS QUERIES
-- ============================================================

-- MONTHLY TREND
SELECT inspection_month,
       COUNT(DISTINCT camis) AS restaurants_inspected,
       COUNT(*) AS total_inspections,
       ROUND(AVG(score_clean), 1) AS avg_score
FROM inspections_final
GROUP BY inspection_month
ORDER BY inspection_month;

-- BOROUGH BREAKDOWN
SELECT boro,
       COUNT(DISTINCT camis) AS restaurants,
       COUNT(*) AS inspections,
       ROUND(AVG(score_clean), 1) AS avg_score
FROM inspections_final
WHERE boro IS NOT NULL
GROUP BY boro
ORDER BY inspections DESC;

-- GRADE BREAKDOWN
SELECT grade,
       event_count AS count,
       ROUND(event_count * 100.0 / SUM(event_count) OVER (), 1) AS pct
FROM (
    SELECT grade, 
           COUNT(*) AS event_count
    FROM inspections_final
    GROUP BY grade
) grade_counts
ORDER BY count DESC;

-- TOP VIOLATIONS
SELECT violation_description,
       COUNT(*) AS frequency,
       SUM(CASE WHEN is_critical = 'Yes' THEN 1 ELSE 0 END) AS critical_count
FROM inspections_final
WHERE violation_description IS NOT NULL
GROUP BY violation_description
ORDER BY frequency DESC
LIMIT 10;


-- ============================================================
-- SECTION 15: FINAL DATASET SELECTION
-- ============================================================

-- RESTAURANT RECORDS TABLE
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
ORDER BY inspection_date_clean DESC;
