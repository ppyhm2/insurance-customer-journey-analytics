-- Aggregate quotes to proposal grain before joining.
-- This prevents fan-out when joining back to stg_proposals.
-- first_payment_status is brought up from transactions via the purchased quote_id
-- so that fct_proposals can surface the full end-to-end journey without additional joins.
WITH quote_summary AS (
    SELECT
        proposal_id,
        COUNT(quote_id)                                                       AS quote_count,
        COALESCE(BOOL_OR(is_purchased), FALSE)                                AS was_purchased,
        MAX(CASE WHEN is_purchased IS TRUE THEN insurer_name END)             AS purchased_insurer_name,
        MAX(CASE WHEN is_purchased IS TRUE THEN monthly_premium END)          AS purchased_premium,
        COALESCE(MAX(CASE WHEN quote_status = 'Quoted' THEN TRUE END), FALSE) AS was_quoted,
        MIN(quoted_at)                                                        AS first_quoted_at,
        MAX(CASE WHEN is_purchased IS TRUE THEN quote_id END)                 AS purchased_quote_id
    FROM stg_quotes
    GROUP BY proposal_id
),
first_payment AS (
    SELECT
        quote_id,
        payment_status AS first_payment_status
    FROM (
        SELECT
            quote_id,
            payment_status,
            ROW_NUMBER() OVER (PARTITION BY quote_id ORDER BY payment_date ASC) AS rn
        FROM stg_transactions
    ) ranked
    WHERE rn = 1
)
SELECT
    p.proposal_id,
    p.user_id,
    p.brand,
    p.landing_at,
    p.drop_out_status,
    p.form_completed_at,
    p.form_completed_at - p.landing_at AS time_to_complete, -- null for non-completions
    p.car_make,
    p.car_model,
    p.user_age,
    CASE
        WHEN p.user_age BETWEEN 17 AND 25 THEN '17-25'
        WHEN p.user_age BETWEEN 26 AND 35 THEN '26-35'
        WHEN p.user_age BETWEEN 36 AND 50 THEN '36-50'
        WHEN p.user_age BETWEEN 51 AND 65 THEN '51-65'
        ELSE '65+'
    END                                AS user_age_category,
    p.postcode,
    q.quote_count,
    q.was_quoted,
    q.was_purchased,
    q.purchased_insurer_name,
    q.purchased_premium,
    q.first_quoted_at,
    fp.first_payment_status
FROM stg_proposals p
LEFT JOIN quote_summary q  ON q.proposal_id = p.proposal_id
LEFT JOIN first_payment fp ON fp.quote_id   = q.purchased_quote_id
