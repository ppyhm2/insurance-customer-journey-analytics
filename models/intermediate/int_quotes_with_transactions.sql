-- Aggregate transactions to quote grain before joining.
-- ROW_NUMBER identifies first and latest payment per quote without duplication.
WITH transaction_ranked AS (
    SELECT
        quote_id,
        payment_date,
        payment_status,
        amount,
        ROW_NUMBER() OVER (PARTITION BY quote_id ORDER BY payment_date ASC)  AS rn_first,
        ROW_NUMBER() OVER (PARTITION BY quote_id ORDER BY payment_date DESC) AS rn_latest
    FROM stg_transactions
),
transaction_summary AS (
    SELECT
        quote_id,
        COUNT(*)                                                    AS total_payments,
        SUM(CASE WHEN payment_status = 'Failed' THEN 1 ELSE 0 END) AS failed_payment_count,
        MIN(payment_date)                                           AS first_payment_date,
        MAX(payment_date)                                           AS latest_payment_date,
        MAX(CASE WHEN rn_first  = 1 THEN payment_status END)       AS first_payment_status,
        MAX(CASE WHEN rn_latest = 1 THEN payment_status END)       AS latest_payment_status
    FROM transaction_ranked
    GROUP BY quote_id
)
SELECT
    q.quote_id,
    q.proposal_id,
    p.brand,
    p.car_make,
    p.car_model,
    p.user_age,
    CASE
        WHEN p.user_age BETWEEN 17 AND 25 THEN '17-25'
        WHEN p.user_age BETWEEN 26 AND 35 THEN '26-35'
        WHEN p.user_age BETWEEN 36 AND 50 THEN '36-50'
        WHEN p.user_age BETWEEN 51 AND 65 THEN '51-65'
        ELSE '65+'
    END                      AS user_age_category,
    p.postcode,
    q.insurer_name,
    q.quote_status,
    q.monthly_premium,
    q.monthly_commission,
    q.quoted_at,
    q.is_purchased,
    t.total_payments,
    t.failed_payment_count,
    t.first_payment_status,
    t.first_payment_date,
    t.latest_payment_status,
    t.latest_payment_date
FROM stg_quotes q
LEFT JOIN transaction_summary t ON t.quote_id    = q.quote_id
LEFT JOIN stg_proposals        p ON p.proposal_id = q.proposal_id
