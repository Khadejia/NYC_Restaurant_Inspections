# NYC Restaurant Health Inspections (2022–2026)

## Project Overview

An end-to-end data analytics project analyzing over 400,000 restaurant inspection records across New York City's five boroughs using PostgreSQL and Tableau. The project focuses on food safety violations, inspection grade trends, cuisine-level risk analysis, and borough-level performance within NYC's restaurant industry.

The analysis primarily focuses on inspection trends from 2022–2025, with limited inspection data available for early 2026.

This project demonstrates data cleaning, SQL analysis, KPI development, and interactive dashboard design for public health business intelligence reporting.

---

# Objectives

* Analyze NYC restaurant inspection trends from 2022–2026
* Identify which cuisine types and boroughs carry the highest food safety risk
* Measure the frequency of critical violations beyond what inspection grades reveal
* Compare inspection scores across cuisines, boroughs, and time periods
* Build interactive Tableau dashboards for analytical insights

---

# Tools & Technologies

* PostgreSQL
* SQL
* Tableau Public
* NYC OpenData (CSV)

---

# Data Pipeline & Dataset Information

This project follows a structured data pipeline from source data to a final analysis-ready dataset used in Tableau.

## Data Pipeline

Source Data → Cleaning & Standardization → Data Enrichment → Final Dataset → Tableau Visualization

---

## Source Data


* **Source:** [NYC Open Data Portal - DOHMH New York City Restaurant Inspection Results](https://data.cityofnewyork.us/)
* **Dataset Size:** Approximately 400,000 inspection records / 26 columns
* **Timeline:** Updated continuously through 2025 (Analysis focuses primarily on 2022–2025, with limited records available for 2026)
* **Note on File Size:** Because the raw dataset exceeds 100MB, it is excluded from this repository via `.gitignore`. 

Located in `data/source_data/`:

- Download the DOHMH Restaurant Inspection Results dataset from NYC OpenData
- Save the file as `nyc_restaurant_inspections.csv`

---

## Final Dataset (Used in Tableau)

Located in `data/final/`:

- Export the cleaned dataset as `inspections_final.csv`
- Final CSV files are excluded from the repository via `.gitignore`

Data preparation included:

* Filtering to standard Cycle Inspections only
* Retaining available 2026 inspection records for trend continuity
* Excluding complaint and pre-permit inspections
* Standardizing borough names
* Standardizing cuisine descriptions
* Creating derived date and performance metrics


---

# SQL Workflow

The SQL workflow includes:

* Table creation and schema validation
* Data import verification
* Removal of placeholder and invalid inspection records
* Date and score data type conversion
* Filtering to standard Cycle Inspections
* Borough and cuisine standardization
* Derived column creation:

  * Inspection Year
  * Inspection Month
  * Inspection Quarter
  * Score Category
  * Critical Violation Flag
* Exploratory data analysis
* KPI generation
* Tableau-ready query preparation

---

# Business Questions

* Which cuisine types have the highest average inspection scores?
* How common are critical violations compared to non-critical violations?
* Which boroughs have the highest and lowest inspection scores?
* Has the Grade A rate improved over time?
* What are the most frequently cited violations?
* Which restaurant categories present the greatest food safety risk?

---

# Key Insights

* Critical violations occur far more frequently than inspection grades alone suggest.
* Restaurants can receive a Grade A while still accumulating critical violations if the overall inspection score remains below the grading threshold.
* Cuisine type is a stronger predictor of inspection performance than borough.
* Grade A rates remained relatively stable from 2022–2026.
* Food storage, temperature control, and pest-related issues are among the most frequently cited violations.
* Manhattan restaurants achieved slightly better average inspection scores than other boroughs, though the performance gap is relatively small.

---

# Live Dashboard

[View Interactive Tableau Dashboard](https://public.tableau.com/views/nyc_restaurant_inspections/Overview?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)

---

# Dashboard Previews

## Overview Dashboard

<img width="1199" height="899" alt="Overview" src="https://github.com/user-attachments/assets/f93f06e2-9c49-4d4d-b594-e15150bb5904" />


---

## Violations Dashboard

<img width="1199" height="899" alt="Violations" src="https://github.com/user-attachments/assets/668ef9ab-b374-41c9-aba8-a0e2ced707e4" />


---

## Grades Dashboard

<img width="1199" height="899" alt="Grades" src="https://github.com/user-attachments/assets/123855bf-5aed-44c9-96a1-d82b0d19b582" />


---

## Cuisine & Score Dashboard

<img width="1199" height="899" alt="Cuisine" src="https://github.com/user-attachments/assets/10ee2635-beae-4a2e-a278-3e043b7e7a54" />


---

## Restaurant Records Dashboard

<img width="1199" height="899" alt="Records" src="https://github.com/user-attachments/assets/a7261aa1-95f2-4c91-b17d-172b0ae7eb5e" />


---

# Dashboard Features

The Tableau solution contains five interactive dashboards organized into four analytical content panels and one detailed records view. All dashboards share a consistent sidebar containing KPIs, filters, and navigation controls.

Dashboard features include:

* Grade distribution badges (A, B, C)
* KPI cards:

  * Total Inspections
  * Grade A Rate
  * Critical Violation Rate
  * Average Inspection Score
* Monthly inspection trends
* Borough performance comparisons
* Violation type analysis
* Grade trend analysis
* Cuisine-level risk analysis
* Best vs. worst performing cuisine comparisons
* Interactive dashboard navigation
* Restaurant records detail table
* Search and filter functionality
* Wildcard search across restaurant name, borough, cuisine, and grade

---

# Repository Structure

```text
nyc-restaurant-inspections/
│
├── data/                             # (Large data files excluded via .gitignore)
│   ├── source_data/                  # Place downloaded source CSV dataset here (.gitkeep)
│   └── final/                        # Output directory for clean transformed data (.gitkeep)
│
├── sql/
│   └── nyc_restaurants.sql           # SQL processing and analysis scripts
│
│── .gitignore                        # Configuration to exclude heavy data tracking
│
└── README.md                         # Project documentation and portfolio overview
```

# Technical Skills Demonstrated

* SQL data cleaning and transformation
* PostgreSQL database management
* Data standardization using pattern matching (ILIKE)
* Date extraction and time-series analysis
* Aggregations and window functions
* KPI development and reporting
* Large-scale dataset preparation
* Interactive Tableau dashboard design
* Dashboard navigation and user experience design
* Data visualization
* Data storytelling
