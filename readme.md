
# Automobile Parts Sales & Operational Analytics (PostgreSQL)

![Database](https://img.shields.io/badge/Database-PostgreSQL-blue)
![Language](https://img.shields.io/badge/Language-SQL-orange)
![Domain](https://img.shields.io/badge/Domain-Automotive%20%26%20Supply%20Chain-green)

## Project Overview
This repository contains a comprehensive SQL-based analytical evaluation of a global Automobile Parts manufacturer and distributor. Using **PostgreSQL**, the analysis evaluates multi-table relational data across sales performance, customer behavioral segmentation, logistics efficiency, product profitability, and reverse logistics.

The project identifies major growth drivers and revenue leakages across **$22.68B+ in total revenue**, providing actionable strategies to optimize dealer channels, reduce order cancellation losses, and resolve international fulfillment delays.

---

## Technical Stack & SQL Capabilities
* **Database Engine:** PostgreSQL
* **Data Modeling:** Relational Schema (Fact and Dimension table structures)
* **Advanced SQL Techniques Applied:**
  * **Common Table Expressions (CTEs):** Structured multi-stage query pipelines for complex metrics.
  * **Window Functions:** `NTILE()`, `RANK()`, `DENSE_RANK()`, `SUM() OVER()`, and `LAG()` for RFM modeling, running totals, and MoM/YoY growth rates.
  * **Aggregates & Joins:** Complex `INNER`/`LEFT` multi-table joins across 10+ relational datasets.
  * **Conditional Logic & Filtering:** `CASE WHEN`, `COALESCE()`, and string extraction/manipulation.

---

## Strategic Recommendations

1. **Capital Allocation:** Shift online acquisition spend into expanding dealer credit lines, prioritizing top-performing Bronze-tier dealers.
2. **Leakage Control:** Introduce strict automated checks at online checkout to block duplicate orders (reducing return processing costs) and tighten discount threshold authorizations.
3. **Logistics Optimization:** Re-evaluate fulfillment routes in Sub-Saharan Africa and audit product descriptions/quality control in Latin America Distribution Center 9 to reduce high return rates.
