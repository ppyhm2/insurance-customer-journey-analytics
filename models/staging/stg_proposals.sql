SELECT
    proposal_id,
    user_id,
    brand,
    CAST(landing_at AS TIMESTAMP)        AS landing_at,
    drop_out_status,
    CAST(form_completed_at AS TIMESTAMP) AS form_completed_at,
    car_make,    -- UPPER() may be needed for standardisation
    car_model,   -- UPPER() may be needed for standardisation
    CAST(user_age AS INT)                AS user_age,
    postcode
FROM raw.proposals
