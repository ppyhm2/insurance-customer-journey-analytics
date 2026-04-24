# Motor Insurance Analytics — Project Write-Up

## Preamble

This brief has been approached through a typical requirements gathering lens. Starting with the problem statement and business needs:

- End users of the model are likely not analysts, so the data model should prioritise simplicity and usability
- The business is striving for self-serve analytics — data-hungry teams should be able to query confidently without needing to understand joins
- The scope covers the end-to-end customer journey from site arrival through to payments
- The data model should be robust and scalable

With this in mind, the five key questions:

- **Who:** Product and Insurance teams
- **What:** Data model and dashboard based on proposals, quotes, decline reasons, and transactions
- **When:** 2024 data; assume automated daily refresh in production
- **Where:** Data model to live in a SQL warehouse with a BI layer on top
- **Why:** Product and Insurance teams want to understand the customer journey and product performance
- **How:** End users consume the dashboard directly, with the option to access the final marts for ad-hoc analysis

The following questions were brainstormed as representative of what the Product and Insurance teams might want answered:

- Did this user get a quote?
- Did this user buy?
- Conversion rate by insurer
- Decline rate by insurer
- Is there a trend with purchased quotes — by price, time of quote, time of purchase?
- Does demographic profile affect funnel success — age, location, car make?
- Is there a trend of failed payments?
- Is there a leading cause for decline reasons?
- What are the typical prices for each insurer? How do they vary by age and car make?
- Drop-out rate by page
- Time from landing to form completion
- Brand performance — which brand has the highest conversion?
- Quote to first payment time
- 1-quote vs 2-quote performance

The design choices throughout this document are made with those questions in mind. Since Product and Insurance teams will potentially consume both the data model and the dashboard, keeping things as simple as possible is the priority.

---

## KPI Selection

Five KPIs have been selected to address the problem statement: tracking a user from the moment they land on the site to their payments. The aim is to balance guided insight with exploratory flexibility, achieved through fixed headline visuals and dashboard filters.

### 1. Complete Funnel Conversion Rate

Measures end-to-end effectiveness across three stages: proposal started, policy purchased, first payment succeeded. This answers: are we converting traffic into revenue? A drop signals something is broken or should be improved, but not where exactly — the other KPIs cover this in a complementary way.

### 2. Decline Rate by Reason

Measures how often quotes are declined and why. This answers: are we losing potential customers before they get a chance to convert? If concentrated in a particular reason, it prompts investigation into whether underwriting rules are too strict or whether the target audience needs reviewing.

### 3. Drop-out Rate by Page

Measures where in the proposal form users abandon. This answers: is there a specific page causing friction, and if so why? It could lead to the Product team changing the form.

### 4. Quote-to-Purchase Rate

Measures how often a priced quote converts to a sale. This answers: is our offering competitive? Are we trusted? Are we presenting the quote effectively? Are we closing the deal?

### 5. Average Premium and Commission

Measures the average monthly premium and commission per purchased policy, segmented by insurer, age category, car make, and brand. This answers: where is our highest value business coming from? Are we going for volume or high-ticket sales?

---

## Technical Definitions of KPIs

> **A note on conversion definitions:** two KPIs in this document measure conversion at different stages. Quote-to-purchase rate defines conversion as `is_purchased = True` — the moment a customer commits to a policy. End-to-end funnel conversion rate extends this to include first payment success, reflecting full revenue realisation. The difference is intentional and documented to pre-empt stakeholder confusion.

### Decline Rate by Reason

- **Decline Rate:** `COUNT(DISTINCT quote_id WHERE status = 'Declined') / COUNT(DISTINCT quote_id)` — at quote grain in `fct_quotes`
- **Reason Distribution:** `COUNT(reason_code) / COUNT(all reason_codes)` — at reason grain in `fct_decline_reasons`

### Complete Funnel Conversion Rate (Landing to First Payment)

- Journey stage 1 — Proposal started: `proposal_id` exists in proposals table
- Journey stage 2 — Policy purchased: `is_purchased = True` in quotes table
- Journey stage 3 — First payment succeeded: earliest transaction per `quote_id` has `status = 'Success'`
- **Numerator:** `COUNT(DISTINCT proposal_id)` where all three stages completed
- **Denominator:** `COUNT(DISTINCT proposal_id)`
- First payment identified via `ROW_NUMBER() OVER (PARTITION BY quote_id ORDER BY payment_date ASC)` where `rn = 1 AND status = 'Success'`

### Quote-to-Purchase Rate

`COUNT(DISTINCT quote_id WHERE is_purchased = True) / COUNT(DISTINCT quote_id WHERE quote_status = 'Quoted')`

### Drop-out Rate by Page

- Overall: `COUNT(DISTINCT proposal_id WHERE drop_out_status != 'completed_form') / COUNT(DISTINCT proposal_id)`
- Per page: `COUNT(DISTINCT proposal_id WHERE drop_out_status = 'page_N') / COUNT(DISTINCT proposal_id)` for N in 1–4

### Average Premium and Commission by Policy

- `AVG(monthly_premium) WHERE is_purchased = True`
- `AVG(monthly_commission) WHERE is_purchased = True`

---

## Data Modelling and Architecture

### Architecture Overview

Three layers, each serving a distinct function.

**Staging** handles data type casting, renaming of ambiguous column names, and null handling — standardising the dataset. It also acts as a single point of reference for each source table, limiting the blast radius of upstream schema changes to one model rather than propagating fixes across the entire pipeline.

**Intermediate** joins tables and applies business logic before the mart layer.

**Marts** are built from intermediate models and are stakeholder-friendly, ready to be consumed by Product and Insurance teams. Since end users may consume the table or the SQL directly — not only the dashboard — joins are minimised or eliminated at this layer.

What matters most to users is that the data is correct, consistent, and easy to use.

### Mart Descriptions

#### `fct_proposals` (Proposal Grain)

One row per proposal. The primary mart for understanding the end-to-end customer journey. Quote outcomes, purchase status, and first payment status have been deliberately collapsed to proposal grain so a stakeholder can answer journey questions from a single row without any joins.

Full transaction history and individual quote details are intentionally excluded — these live in `fct_quotes`. Collapsing multiple transactions or multiple quotes to proposal grain would either lose information or require arbitrary choices about which quote or payment to surface.

**Columns:** `proposal_id`, `user_id`, `brand`, `car_make`, `car_model`, `user_age`, `postcode`, `drop_out_status`, `landing_at`, `form_completed_at`, `time_to_complete`, `quote_count`, `was_quoted`, `was_purchased`, `purchased_insurer_name`, `purchased_premium`, `first_quoted_at`, `first_payment_status`, `data_refreshed_on`

**Answers:** complete funnel conversion rate, drop-out rate by page, quote-to-purchase rate (partial), average premium at proposal level

#### `fct_quotes` (Quote Grain)

One row per quote. The primary mart for insurer and pricing analysis. Demographic context from proposals is deliberately joined down to quote grain so segmentation analysis does not require additional joins. Full transaction detail is collapsed to quote grain because transactions join at `quote_id`.

**Columns:** `quote_id`, `proposal_id`, `brand`, `car_make`, `car_model`, `user_age`, `user_age_category`, `postcode`, `insurer_name`, `quote_status`, `monthly_premium`, `monthly_commission`, `quoted_at`, `is_purchased`, `total_payments`, `failed_payment_count`, `first_payment_status`, `first_payment_date`, `latest_payment_status`, `latest_payment_date`, `data_refreshed_on`

**Answers:** insurer performance, pricing analysis, decline rates by insurer, average premium and commission by segment, quote-to-purchase rate, payment success rate

#### `fct_decline_reasons` (Quote-Reason Grain)

One row per decline reason per quote. A single quote can have multiple decline reasons, which is why this cannot be cleanly collapsed into `fct_quotes` — doing so would require either string concatenation or arbitrary selection, both of which lose information or create ambiguity.

Proposal and quote context is deliberately joined down to this grain so decline reasons can be sliced by demographic, car information, insurer, and brand without additional joins.

**Columns:** `decline_id`, `quote_id`, `proposal_id`, `insurer_name`, `quote_status`, `brand`, `car_make`, `car_model`, `user_age`, `user_age_category`, `postcode`, `decline_reason_code`, `data_refreshed_on`

**Answers:** decline rate by reason, reason code distribution, segmented decline analysis by demographic, car make, insurer, and brand

### Normalisation Rationale

A fully normalised schema minimises data redundancy by storing each piece of information once, with relationships maintained through foreign keys. In practice that means many smaller tables that need to be joined to answer questions. It is efficient for storage and write operations but requires technical knowledge to query.

A denormalised schema deliberately repeats information across tables. This redundancy is intentional — each mart is self-contained and a stakeholder can answer their question from one table without understanding the underlying relationships.

Denormalisation was chosen here because:

- The target audience is Product and Insurance teams who may not be fully technical
- Self-serve is an explicit goal — data-hungry teams need to query confidently without needing to understand joins
- The problem statement tracks a user end-to-end, which is inherently a linear narrative and lends itself to wide, self-contained tables

### Scalability

The layered architecture scales cleanly. Changes are isolated to the appropriate layer: an upstream schema change is contained to the staging model; a new KPI can be added as a derived column without restructuring the marts; new data sources can be introduced via a new staging model without touching existing models.

### Limitations

- If a user's details change over time (e.g. they move postcode or change vehicle) the model has no mechanism to track historical states
- Geographic analysis is limited to raw postcodes; without an external postcode-to-region lookup table, location-based segmentation is constrained
- The model assumes a UK locale with UK postcode format and monetary values in GBP; international expansion would require revisiting
- The raw quotes table has no `purchased_at` timestamp, only a boolean `is_purchased` flag; a purchase timestamp would enable more precise time-based analysis of the quote-to-purchase journey
- In this dataset, the values for "policy purchased" and "first payment succeeded" are effectively equivalent; there may be future scenarios where the policy is purchased but all transactions fail

---

## SQL Implementation

### Staging

```sql
-- stg_proposals
SELECT
    proposal_id,
    user_id,
    brand,
    CAST(landing_at AS TIMESTAMP)       AS landing_at,
    drop_out_status,
    CAST(form_completed_at AS TIMESTAMP) AS form_completed_at,
    car_make,    -- UPPER() may be needed for standardisation
    car_model,   -- UPPER() may be needed for standardisation
    CAST(user_age AS INT)               AS user_age,
    postcode
FROM raw.proposals
```

```sql
-- stg_quotes
SELECT
    quote_id,
    proposal_id,
    insurer_name,
    status                                     AS quote_status,
    CAST(monthly_premium    AS DECIMAL(10,2))  AS monthly_premium,
    CAST(monthly_commission AS DECIMAL(10,2))  AS monthly_commission,
    CAST(quoted_at AS TIMESTAMP)               AS quoted_at,
    CAST(is_purchased AS BOOL)                 AS is_purchased
FROM raw.quotes
```

```sql
-- stg_transactions
SELECT
    transaction_id,
    quote_id,
    CAST(amount       AS DECIMAL(10,2)) AS amount,
    CAST(payment_date AS DATE)          AS payment_date,
    status                              AS payment_status
FROM raw.transactions
```

```sql
-- stg_decline_reasons
SELECT
    decline_id,
    quote_id,
    reason_code
FROM raw.decline_reasons
```

### Intermediate

```sql
-- int_proposals_with_quotes  (proposal grain)
WITH quote_summary AS (
    SELECT
        proposal_id,
        COUNT(quote_id)                                                  AS quote_count,
        BOOL_OR(is_purchased)                                            AS was_purchased,
        MAX(CASE WHEN is_purchased IS TRUE THEN insurer_name END)        AS purchased_insurer_name,
        MAX(CASE WHEN is_purchased IS TRUE THEN monthly_premium END)     AS purchased_premium,
        MAX(CASE WHEN quote_status = 'Quoted' THEN TRUE END)             AS was_quoted,
        MIN(quoted_at)                                                   AS first_quoted_at
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
    p.form_completed_at - p.landing_at  AS time_to_complete,
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
```

```sql
-- int_quotes_with_transactions  (quote grain)
WITH transaction_ranked AS (
    SELECT
        quote_id,
        payment_date,
        payment_status,
        amount,
        ROW_NUMBER() OVER (PARTITION BY quote_id ORDER BY payment_date ASC)  AS rn_first,
        ROW_NUMBER() OVER (PARTITION BY quote_id ORDER BY payment_date DESC) AS rn_latest
    FROM stg_transactions
),
transaction_summary AS (
    SELECT
        quote_id,
        COUNT(*)                                                        AS total_payments,
        SUM(CASE WHEN payment_status = 'Failed' THEN 1 ELSE 0 END)     AS failed_payment_count,
        MIN(payment_date)                                               AS first_payment_date,
        MAX(payment_date)                                               AS latest_payment_date,
        MAX(CASE WHEN rn_first  = 1 THEN payment_status END)           AS first_payment_status,
        MAX(CASE WHEN rn_latest = 1 THEN payment_status END)           AS latest_payment_status
    FROM transaction_ranked
    GROUP BY quote_id
)
SELECT
    q.quote_id,
    q.proposal_id,
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
    END                                                                AS user_age_category,
    p.postcode,
    q.insurer_name,
    q.quote_status,
    q.monthly_premium,
    q.monthly_commission,
    q.quoted_at,
    q.is_purchased,
    t.total_payments,
    t.failed_payment_count,
    t.first_payment_status,
    t.first_payment_date,
    t.latest_payment_status,
    t.latest_payment_date
FROM stg_quotes q
LEFT JOIN transaction_summary t ON t.quote_id       = q.quote_id
LEFT JOIN stg_proposals        p ON p.proposal_id   = q.proposal_id
```

```sql
-- int_decline_reasons_enriched
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
LEFT JOIN stg_quotes   q ON q.quote_id    = d.quote_id
LEFT JOIN stg_proposals p ON p.proposal_id = q.proposal_id
```

### Marts

```sql
-- fct_proposals
SELECT
    proposal_id,
    user_id,
    brand,
    landing_at,
    drop_out_status,
    form_completed_at,
    form_completed_at - landing_at  AS time_to_complete,  -- null for non-completions
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
    CURRENT_TIMESTAMP               AS data_refreshed_on
FROM int_proposals_with_quotes
```

```sql
-- fct_quotes
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
    CURRENT_TIMESTAMP               AS data_refreshed_on
FROM int_quotes_with_transactions
```

```sql
-- fct_decline_reasons
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
    CURRENT_TIMESTAMP               AS data_refreshed_on
FROM int_decline_reasons_enriched
```

---

## Data Quality and Testing

The tests below are non-exhaustive but representative.

### Staging tests

- `proposal_id`, `quote_id`, `transaction_id`, `decline_id` are unique and not null (primary keys)
- `drop_out_status` only contains expected values: `page_1`, `page_2`, `page_3`, `page_4`, `completed_form`
- `quote_status` only contains expected values: `Quoted`, `Declined`
- `payment_status` only contains expected values: `Success`, `Failed`
- `user_age > 16`
- `monthly_premium` is never null when `quote_status = 'Quoted'`

### Intermediate tests

- Every `proposal_id` in `int_proposals_with_quotes` exists in `stg_proposals` (referential integrity)
- Row count of `int_proposals_with_quotes` equals row count of `stg_proposals` (fan-out guard — each proposal should appear exactly once)

### Mart tests

- `purchased_premium` is never null when `was_purchased = True`
- `first_payment_status` is never populated for unpurchased quotes
- `average_premium` is always positive

### Late-arriving data

With late-arriving data — for example a purchase occurring six months after a proposal is created — several issues can arise. The parameters used to create the proposal initially (age, pricing, risk profile, underwriting rules) may no longer be valid at the time of purchase, meaning the purchased policy could be mispriced or misclassified.

One approach is quarantining: late-arriving data is moved to a separate table away from the main datasets. This preserves integrity and trust in the core data while retaining an audit trail that can be referred to or restored if required. More specifically, all records related to a `proposal_id` could be quarantined if the system detects late-arriving data on that proposal.

The definition of "late" must be agreed with the business — the Insurance team is the right owner of that decision. As a starting point, 30 days is a reasonable threshold to propose.

---

## Dashboard Design

### Overview

The aim is to enable the Product and Insurance teams to generate data-informed — not data-driven — insights and actions. Although self-serve is the goal, the dashboard leans towards guided exploration rather than raw data access, using fixed visuals and contextual filters.

The dashboard has a **front page** summarising all five KPIs as headline numbers and charts. This lets teams get the answer quickly without having to navigate. Each KPI then has a **dedicated deep-dive page** with richer visuals and filters for ad-hoc segmentation (date, age category, car make, brand).

Additional design considerations:

- A **data freshness indicator** on every page to build trust in the numbers
- **Export functionality** so users can interrogate data independently
- **Tooltips and a glossary page** to reduce reliance on the data team — important in a scale-up environment where teams move fast
- **Colour-blindness awareness** — affects approximately 8% of males and 0.5% of females; chart palette should be tested accordingly
- Consistent branding, sizing, and chart choice across all pages

Wireframes for the front page and KPI pages were produced in Excalidraw to illustrate page structure and chart placement.

### KPI Page Descriptions

#### Funnel Conversion Rate
- **Headline:** End-to-end conversion percentage
- **Primary visual:** Bar chart showing absolute numbers and percentage at each of the three journey stages (proposal started, policy purchased, first payment succeeded). Bar chart chosen over line chart as each stage is discrete rather than continuous.
- **Supporting visual:** Conversion rate over time — allows the Product team to identify whether overall conversion is improving or deteriorating
- **Filters:** Date, brand, age category, car make

#### Decline Rate by Reason
- **Headline:** Overall decline rate percentage
- **Primary visual:** Decline rate over time
- **Supporting visuals:** Distribution of declines by reason code (bar chart preferred over pie chart given five reasons and potentially uneven distribution); sparklines per reason code showing individual trends without the visual clutter of five lines on one chart; breakdown by insurer
- **Filters:** Date, age category

#### Drop-out Rate by Page
- **Headlines:** Overall drop-out rate and per-page drop-out rate
- **Primary visual:** Bar chart showing drop-out rate at each of the five pages
- **Supporting visual:** Drop-out rates over time — allows the Product team to measure the impact of form changes directly
- **Filters:** Date, brand, age category

#### Quote-to-Purchase Rate
- **Headline:** Average quote-to-purchase rate
- **Primary visual:** Quote-to-purchase rate over time — allows trend analysis and measurement of pricing or proposition changes
- **Supporting visual:** Quote-to-purchase rate by insurer — top performers surfaced as a fixed visual to guide conclusions without requiring ad-hoc filtering
- **Filters:** Date, age category, car make

#### Average Premium and Commission
- **Headlines:** Average monthly premium, average monthly commission, commission-to-premium ratio (currently fixed at 10% but may change)
- **Primary visual:** Average premium and commission over time
- **Supporting visual:** Average premium by insurer — answers "where is our highest value business coming from?"
- **Filters:** Date, age category, car make, brand
