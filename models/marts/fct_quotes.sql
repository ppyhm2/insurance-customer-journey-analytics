-- One row per quote.
-- Demographic context from proposals is joined down to quote grain so segmentation
-- analysis does not require additional joins at the consumption layer.
SELECT
    quote_id,
    proposal_id,
    brand,
    car_make,
    car_model,
    user_age,
    user_age_category,
    postcode,
    insurer_name,
    quote_status,
    monthly_premium,
    monthly_commission,
    quoted_at,
    is_purchased,
    total_payments,
    failed_payment_count,
    first_payment_status,
    first_payment_date,
    latest_payment_status,
    latest_payment_date,
    CURRENT_TIMESTAMP AS data_refreshed_on
FROM int_quotes_with_transactions
