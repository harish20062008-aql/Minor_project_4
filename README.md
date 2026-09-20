# Minor_project_4
# 🎬 BingePlay Streaming Analytics: Advanced MySQL Pipeline

An end-to-end SQL & Python analytics project analyzing user engagement, subscription revenues, viewing patterns, and retention signals for **BingePlay**—a simulated high-volume video streaming platform.

---

## 📌 Project Overview

This repository contains a full-suite SQL analysis covering **12 key analytics modules** designed to extract actionable product and business insights from relational data. The queries address core SaaS and OTT metrics including Monthly Recurring Revenue (MRR), churn detection, engagement streaks (Gaps-and-Islands), and subscription plan tier optimization.

---

## 🛠️ Tech Stack & Prerequisites

* **Database Engine:** MySQL 8.0+
* **Data Processing & Integration:** Python 3.9+, Pandas, SQLAlchemy, PyMySQL
* **SQL Techniques Used:** Common Table Expressions (CTEs), Window Functions (`ROW_NUMBER()`), Gaps-and-Islands Problem Solving (`WEEK()` partitioning), Aggregations, Defensive Subqueries (`NOT EXISTS`).

---

## 📊 Key Analytics Modules & Findings

### Tier 1: Foundations & Core KPIs
* **Active Revenue (MRR):** Calculated active subscriptions and monthly recurring revenue (MRR) considering ongoing non-terminated subscriptions (`end_date IS NULL` or future expiry).
* **Signup Momentum:** Analyzed 2024 user onboarding trends, identifying **May** as the peak acquisition month (584 signups).
* **Device Analytics:** Evaluated cross-platform device performance across Mobile, Tablet, Laptop, and TV (~91 mins average watch time per session).
* **Content Performance:** Measured user sentiment across 5,000+ ratings and compared **BingePlay Originals** vs. **Acquired Content** (Originals outperforming on IMDb ratings by 0.83 points).

### Tier 2: Behavioral Patterns & Tier Optimization
* **Binge Day Detection:** Identified instances where users watched a single show 5+ times in a single day during Q2 2024.
* **Zero-Watch Dropoffs:** Flagged Q1 signups who never completed a single watch session using defensive `NOT EXISTS` anti-joins.
* **Plan Tier Mismatches:** Discovered **384 Premium/Family subscribers** who exclusively consumed Basic-tier content, highlighting downgrade or churn risks.
* **Cliffhanger Comebacks:** Tracked user re-engagement within 1–7 days following an incomplete viewing session to isolate top narrative hooks.

### Tier 3: Advanced Window Functions & Retention
* **Consecutive-Week Engagement:** Implemented a **Gaps-and-Islands** algorithm using ISO week sequencing to track continuous 4+ week viewing streaks (longest active streak: 26 weeks).
* **Churn Signal Detection:** Identified **61 high-risk users** exhibiting a $\ge 50\%$ drop in viewing time between May and June 2024 for re-engagement targeting.

---

## 📂 Repository Structure

```text
├── queries/
│   ├── tier1_foundations.sql     # Active revenue, device metrics, content ratings
│   ├── tier2_behavioral.sql      # Binge patterns, plan optimizations, comebacks
│   └── tier3_advanced.sql        # Gaps-and-islands streaks, churn risk CTEs
├── scripts/
│   └── pipeline.py              # Python script connecting SQLAlchemy to MySQL
├── assets/
│   └── dashboard_preview.png    # Analytics visualization banner
└── README.md                    # Project documentation
