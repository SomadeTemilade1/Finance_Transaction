Select *
from finance_staging;
---Row count and column nulls
SELECT COUNT(*) AS total_rows FROM finance_staging;

SELECT
  COUNT(*) AS total,
  COUNT(ï»¿Transaction_ID)     AS has_txn_id,
  COUNT(Payment_Method)     AS has_payment_method,
  COUNT(Approval_Code)      AS has_approval_code,
  COUNT(*) - COUNT(Payment_Method) AS null_payment_method,
  COUNT(*) - COUNT(Approval_Code)  AS null_approval_code
FROM finance_staging;
----Check for duplicates
SELECT Ï»¿Transaction_ID, COUNT(*) AS occurrences
FROM finance_staging
GROUP BY Ï»¿Transaction_ID
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;

---Profile categories
SELECT Transaction_Category, COUNT(*) AS cnt
FROM finance_staging
GROUP BY Transaction_Category ORDER BY cnt DESC;

SELECT Department, COUNT(*) AS cnt
FROM finance_staging
GROUP BY Department ORDER BY cnt DESC;

— Remove Duplicate Records
WITH ranked AS (
  SELECT *,
    ROW_NUMBER() OVER (
      PARTITION BY Ï»¿Transaction_ID
      ORDER BY Transaction_Date ASC
    ) AS rn
  FROM finance_staging
)
DELETE FROM finance_staging
WHERE Ï»¿Transaction_ID IN (
  SELECT Ï»¿Transaction_ID FROM ranked WHERE rn > 1
);

-- Fix typos
UPDATE finance_staging SET Department = 'Finance'    WHERE Department = 'Finace';
UPDATE finance_staging SET Department = 'Operations' WHERE Department = 'Operatins';
UPDATE finance_staging SET Department = 'Marketing'  WHERE Department = 'Maketing';
UPDATE finance_staging SET Department = 'Treasury'   WHERE Department = 'Treasurey';

-- Strip trailing/leading whitespace from all text columns
UPDATE finance_staging SET Department = TRIM(Department);
UPDATE finance_staging SET Transaction_Status = TRIM(Transaction_Status);
UPDATE finance_staging SET Payment_Method = TRIM(Payment_Method);

---Check no dirty values remain
SELECT DISTINCT Department FROM finance_staging ORDER BY Department;

UPDATE finance_staging
SET Payment_Method = 'Not Applicable'
WHERE Payment_Method IS NULL
  AND Transaction_Status IN ('Pending', 'Failed');
  
-- Flag completed transactions missing an approval code
SELECT Ï»¿Transaction_ID, Transaction_Date, Amount_USD, Transaction_Status
FROM finance_staging
WHERE Approval_Code IS NULL
  AND Transaction_Status = 'Completed';

-- Add outlier flag column
ALTER TABLE finance_staging ADD COLUMN Is_Outlier BOOLEAN DEFAULT FALSE;

-- Flag records more than 3 standard deviations from the mean
UPDATE finance_staging
SET Is_Outlier = TRUE
WHERE Amount_USD > (
    SELECT threshold FROM (
        SELECT AVG(Amount_USD) + 3 * STDDEV(Amount_USD) AS threshold
        FROM finance_staging
    ) AS stats
);


SELECT Ï»¿Transaction_ID, Transaction_Date, Customer_ID,
       Transaction_Category, Amount_USD, Department
FROM finance_staging
WHERE Is_Outlier = TRUE
ORDER BY Amount_USD DESC;

-- Check for invalid dates (PostgreSQL)
SELECT Ï»¿Transaction_ID, Transaction_Date
FROM finance_staging
WHERE CAST(Transaction_Date AS DATE) IS NULL
   OR CAST(Transaction_Date AS DATE) < '2022-01-01'
   OR CAST(Transaction_Date AS DATE) > '2024-12-31';
   
SELECT Ï»¿Transaction_ID, Amount_USD
FROM finance_staging WHERE Amount_USD NOT REGEXP '^[0-9]+(\\.[0-9]+)?$';

-- Check valid Transaction_Category values
SELECT DISTINCT Transaction_Category FROM finance_staging
WHERE Transaction_Category NOT IN (
  'Revenue','Operating Expense','Capital Expenditure',
  'Tax Payment','Loan Repayment','Investment','Refund'
);
-- Check valid Transaction_Status values
SELECT DISTINCT Transaction_Status FROM finance_staging
WHERE Transaction_Status NOT IN (
  'Completed','Pending','Failed','Under Review'
);
—---Final Quality Check
SELECT
  COUNT(*) AS total_rows,
  SUM(CASE WHEN Ï»¿Transaction_ID IS NULL THEN 1 ELSE 0 END)  AS null_ids,
  SUM(CASE WHEN Payment_Method IS NULL THEN 1 ELSE 0 END) AS null_payment,
  SUM(CASE WHEN Approval_Code IS NULL
       AND Transaction_Status = 'Completed' THEN 1 ELSE 0 END) AS missing_approvals,
  SUM(CASE WHEN Is_Outlier = TRUE THEN 1 ELSE 0 END)       AS outlier_count,
  COUNT(DISTINCT Ï»¿Transaction_ID) AS unique_ids
FROM finance_staging;

ALTER TABLE finance_staging 
RENAME COLUMN `ï»¿Transaction_ID` TO `Transaction_ID`;

-- Check first
SELECT * FROM finance_staging
WHERE Is_Outlier = TRUE;

-- Then delete
DELETE FROM finance_staging
WHERE Is_Outlier = TRUE;









