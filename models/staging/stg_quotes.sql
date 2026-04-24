SELECT
    quote_id,
    proposal_id,
    insurer_name,
    status                                    AS quote_status,
    CAST(monthly_premium    AS DECIMAL(10,2)) AS monthly_premium,
    CAST(monthly_commission AS DECIMAL(10,2)) AS monthly_commission,
    CAST(quoted_at AS TIMESTAMP)              AS quoted_at,
    CAST(is_purchased AS BOOL)                AS is_purchased
FROM raw.quotes
