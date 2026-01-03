# Analysis Pipeline
**Doc Scope:** Documents SQL pipeline stages and their validation and analysis intent across the analytics lifecycle.


## [01_data_cleaning.sql](../sql/scripts/01_data_cleaning.sql)
**Purpose:** Prepare analysis-ready data by validating structure, integrity, and consistency, and isolating data quality issues that would invalidate downstream analysis.

| Section | Intent |
| --- | --- |
| Raw Data Ingestion | Provision staging tables for raw data persistence |
| Data Load | Load source CSV data into staging environment |
| Data Profiling & Structure Audit | Measure column completeness and uniqueness integrity |
| Duplicate & Key Consistency | Identify duplicate records and key collisions |
| Hierarchy & Dimension Validation | Validate hierarchical field coherence |
| Continuous Variable Validation | Validate numeric validity, range constraints, and distribution shape |
| Data Corrections | Normalize mappings and enforce dimensional consistency |
| Data Quality Handling | Classify irrecoverable data quality conditions |


## [02_exploratory_data_analysis.sql](../sql/scripts/02_exploratory_data_analysis.sql)
**Purpose:** To determine where growth is driven by real demand versus incentives or cost effects, and to guide investment prioritization across markets, products, pricing, and segments.

| Section | Intent |
| --- | --- |
| Market Demand Concentration & Growth Weighting | Prioritize markets by growth contribution |
| Category Demand Mix & Investment Relevance | Guide product investment via category demand mix |
| Pricing & Discount-Driven Demand Dynamics | Define discounting as a stimulator vs sustainer of demand |
| Fulfillment Cost & Demand Structure | Attribute demand shape to shipping cost pressure |
| Segment Contribution & Demand Quality Profile | Quantify segment value, validate promo dependence, and measure fulfillment cost sensitivity |