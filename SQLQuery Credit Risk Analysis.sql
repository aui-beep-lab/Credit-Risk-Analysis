select * from [dbo] . [credit_risk_dataset]

-- ===================================================
-- CREDIT RISK ANALYTICS - COMPLETE DATABASE SETUP & EDA
-- RDBMS: Microsoft SQL Server (T-SQL)
-- ===================================================

-- ---------------------------------------------------
-- STEP 1: CLEANUP & SCHEMA CREATION
-- ---------------------------------------------------
DROP TABLE IF EXISTS loans;

CREATE TABLE loans (
    loan_id                     INT IDENTITY(1,1) PRIMARY KEY,
    person_age                  SMALLINT NOT NULL,
    person_income               NUMERIC(12,2) NOT NULL,
    person_home_ownership      VARCHAR(20) NOT NULL,
    person_emp_length           NUMERIC(5,1),
    loan_intent                 VARCHAR(30) NOT NULL,
    loan_grade                  CHAR(1) NOT NULL,
    loan_amnt                   NUMERIC(12,2) NOT NULL,
    loan_int_rate               NUMERIC(5,2),
    loan_status                 SMALLINT NOT NULL,                  -- 0 = Non-Default, 1 = Default
    loan_percent_income         NUMERIC(5,4) NOT NULL,              -- loan_amnt / person_income
    cb_person_default_on_file   CHAR(1) NOT NULL,                   -- Y/N
    cb_person_cred_hist_length  SMALLINT NOT NULL,
    
    -- Feature-Engineered & Analytical Fields
    age_group                   VARCHAR(10),
    income_bracket              VARCHAR(10),
    loan_to_income_pct          NUMERIC(6,2),
    dti_risk_band               VARCHAR(15),
    has_prior_default           SMALLINT,
    credit_hist_ratio           NUMERIC(6,2),
    predicted_default_probability NUMERIC(6,4),
    predicted_risk_tier         VARCHAR(15),
    sim_application_date        DATE,                               -- Simulated timeline field

    CONSTRAINT chk_loan_status CHECK (loan_status IN (0,1)),
    CONSTRAINT chk_loan_grade CHECK (loan_grade IN ('A','B','C','D','E','F','G')),
    CONSTRAINT chk_default_on_file CHECK (cb_person_default_on_file IN ('Y','N'))
);

-- ---------------------------------------------------
-- STEP 2: CREATE INDEXES FOR PERFORMANCE
-- ---------------------------------------------------
CREATE INDEX idx_loans_grade ON loans(loan_grade);
CREATE INDEX idx_loans_intent ON loans(loan_intent);
CREATE INDEX idx_loans_status ON loans(loan_status);
CREATE INDEX idx_loans_home_ownership ON loans(person_home_ownership);
CREATE INDEX idx_loans_app_date ON loans(sim_application_date);

-- ---------------------------------------------------
-- STEP 3: DATA MIGRATION & TYPE SANITIZATION
-- ---------------------------------------------------
INSERT INTO loans (
    person_age,
    person_income,
    person_home_ownership,
    person_emp_length,
    loan_intent,
    loan_grade,
    loan_amnt,
    loan_int_rate,
    loan_status,
    loan_percent_income,
    cb_person_default_on_file,
    cb_person_cred_hist_length
)
SELECT 
    person_age,
    person_income,
    person_home_ownership,
    person_emp_length,
    loan_intent,
    UPPER(TRIM(CAST(loan_grade AS VARCHAR(10)))),
    loan_amnt,
    loan_int_rate,
    loan_status,
    loan_percent_income,
    -- Handles bit (1/0), string ('1'/'0'), or text ('Y'/'N') inputs safely
    CASE 
        WHEN CAST(cb_person_default_on_file AS VARCHAR(10)) IN ('1', 'Y', 'YES', 'TRUE') THEN 'Y'
        ELSE 'N'
    END,
    cb_person_cred_hist_length
FROM dbo.credit_risk_dataset;

-- ---------------------------------------------------
-- STEP 4: FEATURE ENGINEERING & DATA POPULATION
-- ---------------------------------------------------
UPDATE loans
SET 
    -- 1. Loan-to-Income Percentage
    loan_to_income_pct = ROUND((loan_amnt / NULLIF(person_income, 0)) * 100, 2),
    
    -- 2. Demographic Groupings
    age_group = CASE 
        WHEN person_age < 25 THEN '18-24'
        WHEN person_age BETWEEN 25 AND 35 THEN '25-35'
        WHEN person_age BETWEEN 36 AND 50 THEN '36-50'
        ELSE '50+'
    END,

    income_bracket = CASE 
        WHEN person_income < 35000 THEN 'Low'
        WHEN person_income BETWEEN 35000 AND 85000 THEN 'Medium'
        ELSE 'High'
    END,

    -- 3. Binary Indicator for Prior Defaults
    has_prior_default = CASE 
        WHEN cb_person_default_on_file = 'Y' THEN 1 
        ELSE 0 
    END,

    -- 4. Debt-to-Income (DTI) Risk Classification
    dti_risk_band = CASE 
        WHEN loan_percent_income < 0.15 THEN 'Low Risk'
        WHEN loan_percent_income BETWEEN 0.15 AND 0.30 THEN 'Medium Risk'
        ELSE 'High Risk'
    END,

    -- 5. Ratio of Credit History Duration relative to Applicant Age
    credit_hist_ratio = ROUND((CAST(cb_person_cred_hist_length AS FLOAT) / NULLIF(person_age, 0)) * 100, 2),

    -- 6. Simulated Application Timestamps across a 1-year window
    sim_application_date = DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, '2026-09-01');

-- ---------------------------------------------------
-- STEP 5: CREATE ANALYTICAL VIEW FOR DASHBOARDS
-- ---------------------------------------------------
GO

CREATE OR ALTER VIEW vw_credit_risk_summary AS
SELECT 
    loan_id,
    person_age,
    age_group,
    person_income,
    income_bracket,
    person_home_ownership,
    loan_intent,
    loan_grade,
    loan_amnt,
    loan_int_rate,
    loan_status,
    loan_percent_income,
    dti_risk_band,
    cb_person_default_on_file,
    has_prior_default,
    credit_hist_ratio,
    sim_application_date
FROM loans;

GO

-- ---------------------------------------------------
-- STEP 6: VERIFY POPULATED TABLE
-- ---------------------------------------------------
SELECT TOP 10 * FROM dbo.loans;

-- ---------------------------------------------------
-- STEP 7: EXPLORATORY DATA ANALYSIS (EDA)
-- ---------------------------------------------------

-- Analysis A: Default Rate & Financial Metrics by Loan Grade
SELECT 
    loan_grade,
    COUNT(*) AS total_applicants,
    SUM(CAST(loan_status AS INT)) AS total_defaults,
    ROUND(AVG(CAST(loan_status AS FLOAT)) * 100, 2) AS default_rate_pct,
    SUM(loan_amnt) AS total_loan_volume,
    ROUND(AVG(loan_int_rate), 2) AS avg_interest_rate
FROM loans
GROUP BY loan_grade
ORDER BY loan_grade;

-- Analysis B: Capital Loss Exposure by Loan Purpose (Intent)
SELECT 
    loan_intent,
    COUNT(*) AS total_loans,
    SUM(CASE WHEN loan_status = 1 THEN loan_amnt ELSE 0 END) AS defaulted_capital,
    ROUND(SUM(CASE WHEN loan_status = 1 THEN loan_amnt ELSE 0 END) / SUM(loan_amnt) * 100, 2) AS capital_loss_pct
FROM loans
GROUP BY loan_intent
ORDER BY defaulted_capital DESC;

-- Analysis C: Default Rate by Credit Bureau History & Income Group
SELECT 
    cb_person_default_on_file,
    income_bracket,
    COUNT(*) AS total_loans,
    ROUND(AVG(CAST(loan_status AS FLOAT)) * 100, 2) AS default_rate_pct
FROM loans
GROUP BY cb_person_default_on_file, income_bracket
ORDER BY cb_person_default_on_file DESC, default_rate_pct DESC;