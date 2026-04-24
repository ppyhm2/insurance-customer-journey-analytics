-- Join proposal and quote context down to decline reason grain.
-- Enables segmented decline analysis without additional joins at the mart layer.
SELECT
    d.decline_id,
    d.quote_id,
    d.reason_code,
    q.proposal_id,
    q.insurer_name,
    q.quote_status,
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
    END                  AS user_age_category,
    p.postcode
FROM stg_decline_reasons d
LEFT JOIN stg_quotes    q ON q.quote_id    = d.quote_id
LEFT JOIN stg_proposals p ON p.proposal_id = q.proposal_id
