-- One row per proposal.
-- Quote outcomes, purchase status, and first payment status are collapsed to proposal grain
-- so stakeholders can answer end-to-end journey questions from a single row without any joins.
SELECT
    proposal_id,
    user_id,
    brand,
    landing_at,
    drop_out_status,
    form_completed_at,
    form_completed_at - landing_at AS time_to_complete, -- null for non-completions
    car_make,
    car_model,
    user_age,
    postcode,
    quote_count,
    was_quoted,
    was_purchased,
    purchased_insurer_name,
    purchased_premium,
    first_quoted_at,
    CURRENT_TIMESTAMP              AS data_refreshed_on
FROM int_proposals_with_quotes
