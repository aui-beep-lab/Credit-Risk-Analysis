# Credit Risk Analysis: End-to-End Data Analytics Project

A complete credit risk analytics pipeline: data cleaning, exploratory data
analysis, statistical visualization, machine learning default-prediction
models, portfolio forecasting, and a SQL analytics layer, built on the
`credit_risk_dataset` (32,581 loan records).

---

## Project Structure

```
credit_risk_project/
├── data/
│   ├── credit_risk_clean.csv          (cleaned + feature-engineered dataset)
│   ├── credit_risk_scored.csv         (adds ML-predicted default probability/tier)
│   ├── credit_risk_full.csv           (adds simulated application date for trend analysis)
│   ├── monthly_portfolio_trend.csv    (monthly aggregates)
│   ├── forecast_next_6_months.csv     (forecast output)
│   └── cleaning_log.txt               (data cleaning audit trail)
├── scripts/
│   ├── 01_data_cleaning.py
│   ├── 02_eda_visuals.py
│   ├── 03_eda_visuals_advanced.py
│   ├── 04_predictive_modeling.py
│   ├── 05_forecasting.py
│   ├── 06_sql_validation.py
│   └── 07_dashboard_summary.py
├── visuals/                            (24 saved PNG charts)
├── models/
│   ├── random_forest_model.pkl
│   ├── gradient_boosting_model.pkl
│   ├── scaler.pkl / label_encoders.pkl
│   └── model_summary.txt
├── sql/
│   ├── 01_schema.sql                  (Postgres table + indexes)
│   ├── 02_dashboard_views.sql         (10 dashboard-ready views)
│   ├── credit_risk.db                 (SQLite DB, validated, ready to query)
│   └── query_results/                 (CSV output of every view, proven to run)
└── Credit_Risk_Analysis.ipynb          (full pipeline as a single notebook)
```

---

## 1. Dataset

| Field | Description |
|---|---|
| `person_age`, `person_income`, `person_emp_length` | Borrower demographics |
| `person_home_ownership` | RENT / OWN / MORTGAGE / OTHER |
| `loan_intent` | Purpose of the loan (6 categories) |
| `loan_grade` | Risk grade, A (best) through G (worst) |
| `loan_amnt`, `loan_int_rate`, `loan_percent_income` | Loan terms |
| `loan_status` | Target: 0 = repaid, 1 = defaulted |
| `cb_person_default_on_file`, `cb_person_cred_hist_length` | Credit bureau history |

Source rows: 32,581. Final analysis rows after cleaning: 32,399.

## 2. Data Cleaning

- Removed 165 exact duplicate records
- Removed 7 rows with implausible age (outside 18 to 80, e.g. age = 144)
- Removed 2 rows with implausible employment length (over 60 years, e.g. 123)
- Removed 8 rows with income above $1,000,000 (extreme outliers versus the population)
- Imputed 887 missing `person_emp_length` values using median by age bracket
- Imputed 3,091 missing `loan_int_rate` values using median by loan grade
  (rate is fundamentally driven by grade, so this preserves signal better
  than a global median)
- Engineered 7 new features: `age_group`, `income_bracket`,
  `loan_to_income_pct`, `dti_risk_band`, `has_prior_default`,
  `credit_hist_ratio`, `loan_status_label`

Full audit trail in `data/cleaning_log.txt`.

## 3. Exploratory Analysis & Visualization (24 charts)

Highlights (see `visuals/` for all):

| Insight | Chart |
|---|---|
| Default rate climbs from 10% (Grade A) to 98% (Grade G) | `04_default_rate_by_grade.png` |
| Loan-to-income ratio is the single strongest default predictor | `18_feature_importance.png` |
| Renters default at 2 to 3 times the rate of mortgage holders across every grade | `09_heatmap_grade_vs_homeownership.png` |
| Borrowers with prior credit bureau defaults default at 37.9%, versus 18.4% for those without | `12_prior_default_impact.png` |
| Debt consolidation and medical loans carry the highest default rates (27 to 29%) | `05_default_rate_by_intent.png` |

## 4. Predictive Modeling (Default Risk Scoring)

Three classifiers trained to predict `loan_status` (default probability):

| Model | ROC-AUC | PR-AUC |
|---|---|---|
| Logistic Regression | 0.857 | 0.671 |
| Random Forest | 0.928 | 0.878 |
| Gradient Boosting (best) | 0.943 | 0.897 |

Top predictive features: loan-to-income ratio (26%), loan grade (19%),
borrower income (17%), interest rate (13%), home ownership (10%).

Every loan in the portfolio is scored with a `predicted_default_probability`
and bucketed into a `predicted_risk_tier` (Very Low through Very High), used
throughout the SQL layer.

## 5. Forecasting

Methodology note: this dataset is a cross-sectional snapshot with no
application-date field. To demonstrate time-series forecasting on a
portfolio, a synthetic monthly application date is simulated (seeded,
reproducible, mild seasonal weighting) across a 36-month window. The trend
shape and forecasting method are the deliverable here; treat the specific
historical dates as illustrative, not as real transaction dates. This is
disclosed directly on the forecast chart titles as well.

Using a hand-rolled Holt's Linear Trend (double exponential smoothing)
model (no `statsmodels` dependency), the next 6 months are forecast for:
- Loan application volume, trending upward from about 1,140 to about 1,350 per month
- Portfolio default rate, stable around 22%, with a 95% confidence band

See `visuals/21_forecast_loan_volume.png`, `22_forecast_default_rate.png`,
and `data/forecast_next_6_months.csv`.

## 6. SQL Analytics Layer

`sql/01_schema.sql` defines a normalized Postgres table with constraints and
indexes. `sql/02_dashboard_views.sql` defines 10 dashboard-ready views:
portfolio KPIs, default rate by grade, intent, and DTI band, a grade by
home-ownership risk matrix, monthly trend, model risk-tier distribution,
and the top 10 highest-risk segments.

All views were validated end-to-end against a SQLite build of the same
schema (`sql/credit_risk.db`). Real output for every query is saved in
`sql/query_results/*.csv`, for example:

```
Portfolio KPIs: 32,399 loans, 21.9% default rate, $310.8M total exposure
Grade A: 9.97% default rate, up to Grade G: 98.44% default rate
Borrowers with prior default: 37.9% current default rate (versus 18.4% without)
```

## 7. How to Reproduce

```bash
pip install pandas numpy matplotlib seaborn scikit-learn joblib
python scripts/01_data_cleaning.py
python scripts/02_eda_visuals.py
python scripts/03_eda_visuals_advanced.py
python scripts/04_predictive_modeling.py
python scripts/05_forecasting.py
python scripts/06_sql_validation.py
python scripts/07_dashboard_summary.py
```

Or open `Credit_Risk_Analysis.ipynb` and run all cells top to bottom.

---

**Tech stack:** Python (pandas, scikit-learn, matplotlib, seaborn), SQL
(PostgreSQL views, validated against SQLite), Holt's linear trend forecasting
