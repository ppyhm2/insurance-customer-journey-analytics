-- Aggregate quotes to proposal grain before joining.
-- This prevents fan-out when joining back to stg_proposals.
WITH quote_summary AS (
    SELECT
        proposal_id,
        COUNT(quote_id)                                              AS quote_count,
        BOOL_OR(is_purchased)                                        AS was_purchased,
        MAX(CASE WHEN is_purchased IS TRUE THEN insurer_name END)    AS purchased_insurer_name,
        MAX(CASE WHEN is_purchased IS TRUE THEN monthly_premium END) AS purchased_premium,
        MAX(CASE WHEN quote_status = 'Quoted' THEN TRUE END)         AS was_quoted,
        MIN(quoted_at)                                               AS first_quoted_at
    FROM stg_quotes
    GROUP BY proposal_id
)
SELECT
    p.proposal_id,
    p.user_id,
    p.brand,
    p.landing_at,
    p.drop_out_status,
    p.form_completed_at,
    p.form_completed_at - p.landing_at AS time_to_complete,
    p.car_make,
    p.car_model,
    p.user_age,
    p.postcode,
    q.quote_count,
    q.was_quoted,
    q.was_purchased,
    q.purchased_insurer_name,
    q.purchased_premium,
    q.first_quoted_at
FROM stg_proposals p
LEFT JOIN quote_summary q ON q.proposal_id = p.proposal_id
