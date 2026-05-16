# Insurance Customer Journey Analytics

A practice exercise in analytics engineering and data modelling, built around a fictional insurtech brief.

The brief: the Product and Insurance teams at a fictional direct-to-consumer motor insurer need visibility of their end-to-end customer journey — from the moment a user lands on the site through to ongoing premium payments. They want a robust data model that supports self-serve analysis and a dashboard that surfaces actionable insight without requiring technical knowledge to operate.

---

## What this covers

- **Requirements gathering** — stakeholder framing, problem statement, and brainstorming the questions the data should answer
- **KPI definition** — five KPIs with clear business and technical definitions, including a note on intentional definitional differences between related metrics
- **Data modelling** — a layered dbt-style architecture (staging → intermediate → marts) with grain justifications, normalisation rationale, and documented limitations
- **SQL implementation** — staging, intermediate, and mart layer SQL for all models
- **Testing strategy** — staging, intermediate, and mart-level tests, plus an approach to late-arriving data
- **Dashboard design** — page-by-page description of a five-page dashboard with chart rationale and filter design

---

## Repository structure

```
insurance-customer-journey-analytics/
├── README.md
├── write_up.md             ← full narrative write-up covering all of the above
├── kpi_definitions.md      ← KPI business and technical definitions
├── models/
│   ├── staging/
│   │   ├── stg_proposals.sql
│   │   ├── stg_quotes.sql
│   │   ├── stg_transactions.sql
│   │   └── stg_decline_reasons.sql
│   ├── intermediate/
│   │   ├── int_proposals_with_quotes.sql
│   │   ├── int_quotes_with_transactions.sql
│   │   └── int_decline_reasons_enriched.sql
│   └── marts/
│       ├── fct_proposals.sql
│       ├── fct_quotes.sql
│       └── fct_decline_reasons.sql
├── tests/
│   └── tests.md            ← testing strategy and late-arriving data approach
└── data/
    ├── proposals.csv
    ├── quotes.csv
    ├── decline_reasons.csv
    └── transactions.csv
```

---

## Dataset

The four source tables model a fictional motor insurance customer journey. All data is synthetically generated — there is no real company or real customer data involved.

| Table | Grain | Key fields |
|---|---|---|
| `proposals` | One row per proposal | `proposal_id`, `brand`, `drop_out_status`, `car_make`, `user_age` |
| `quotes` | One row per quote | `quote_id`, `proposal_id`, `insurer_name`, `status`, `monthly_premium`, `is_purchased` |
| `decline_reasons` | One row per reason per declined quote | `decline_id`, `quote_id`, `reason_code` |
| `transactions` | One row per monthly payment | `transaction_id`, `quote_id`, `amount`, `payment_date`, `status` |

All IDs are UUID. Data covers the 2024 calendar year. A small number of transactions spill into early 2025 where a policy purchased late in 2024 has ongoing monthly payments — this is intentional and realistic.

---

## Stack

- **Modelling:** dbt-style layered architecture (staging → intermediate → marts)
- **SQL:** written as portable pseudo-SQL; adaptable to Redshift, BigQuery, Snowflake, or PostgreSQL
- **Visualisation:** dashboard design described only as the back-end was the focus of this exercise
