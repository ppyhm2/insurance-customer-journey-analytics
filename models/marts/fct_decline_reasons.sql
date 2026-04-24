-- One row per decline reason per quote.
-- A single quote can have multiple decline reasons, which is why this cannot be cleanly
-- collapsed into fct_quotes without losing information or creating ambiguity.
-- Proposal and quote context is joined down to this grain so decline reasons can be
-- sliced by demographic, car make, insurer, and brand without additional joins.
SELECT
    decline_id,
    quote_id,
    reason_code,
    proposal_id,
    insurer_name,
    quote_status,
    brand,
    car_make,
    car_model,
    user_age,
    user_age_category,
    postcode,
    CURRENT_TIMESTAMP AS data_refreshed_on
FROM int_decline_reasons_enriched
