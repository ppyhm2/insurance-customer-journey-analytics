SELECT
    transaction_id,
    quote_id,
    CAST(amount       AS DECIMAL(10,2)) AS amount,
    CAST(payment_date AS DATE)          AS payment_date,
    status                              AS payment_status
FROM raw.transactions
