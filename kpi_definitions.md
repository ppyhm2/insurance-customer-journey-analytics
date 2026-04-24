# KPI Definitions

Five KPIs selected to track a user from the moment they land on the site through to their payments. The aim is to balance guided insight with exploratory flexibility, achieved through fixed headline visuals and dashboard filters.

> **A note on conversion definitions:** two KPIs in this document measure conversion at different stages of the customer journey. Quote-to-purchase rate defines conversion as `is_purchased = True` — the moment a customer commits to a policy. End-to-end funnel conversion rate extends this to include first payment success, reflecting full revenue realisation. The difference is intentional and documented to pre-empt stakeholder confusion.

---

## 1. Complete Funnel Conversion Rate

**Business definition**
Measures end-to-end effectiveness across three stages: proposal started, policy purchased, first payment succeeded. Answers: are we converting traffic into revenue? A drop signals something is broken or should be improved, but not where exactly — the other KPIs cover this in a complementary way.

**Technical definition**

| Component | Definition |
|---|---|
| Journey stage 1 | Proposal started — `proposal_id` exists in proposals table |
| Journey stage 2 | Policy purchased — `is_purchased = True` in quotes table |
| Journey stage 3 | First payment succeeded — earliest transaction per `quote_id` has `status = 'Success'` |
| Numerator | `COUNT(DISTINCT proposal_id)` where all three stages completed |
| Denominator | `COUNT(DISTINCT proposal_id)` |
| Source mart | `fct_proposals` |

First payment identified via `ROW_NUMBER() OVER (PARTITION BY quote_id ORDER BY payment_date ASC)` where `rn = 1 AND status = 'Success'`.

---

## 2. Decline Rate by Reason

**Business definition**
Measures how often quotes are declined and why. Answers: are we losing potential customers before they get a chance to convert? If concentrated in a particular reason, it prompts investigation into whether underwriting rules are too strict or whether the target audience needs reviewing.

**Technical definition**

| Metric | Definition | Source mart |
|---|---|---|
| Decline Rate | `COUNT(DISTINCT quote_id WHERE status = 'Declined') / COUNT(DISTINCT quote_id)` | `fct_quotes` |
| Reason Distribution | `COUNT(reason_code) / COUNT(all reason_codes)` | `fct_decline_reasons` |

---

## 3. Drop-out Rate by Page

**Business definition**
Measures where in the proposal form users abandon. Answers: is there a specific page causing friction, and if so why? Could lead to the Product team changing the form.

**Technical definition**

| Metric | Definition |
|---|---|
| Overall drop-out rate | `COUNT(DISTINCT proposal_id WHERE drop_out_status != 'completed_form') / COUNT(DISTINCT proposal_id)` |
| Page 1 drop-out rate | `COUNT(DISTINCT proposal_id WHERE drop_out_status = 'page_1') / COUNT(DISTINCT proposal_id)` |
| Page 2 drop-out rate | `COUNT(DISTINCT proposal_id WHERE drop_out_status = 'page_2') / COUNT(DISTINCT proposal_id)` |
| Page 3 drop-out rate | `COUNT(DISTINCT proposal_id WHERE drop_out_status = 'page_3') / COUNT(DISTINCT proposal_id)` |
| Page 4 drop-out rate | `COUNT(DISTINCT proposal_id WHERE drop_out_status = 'page_4') / COUNT(DISTINCT proposal_id)` |

Source mart: `fct_proposals`

---

## 4. Quote-to-Purchase Rate

**Business definition**
Measures how often a priced quote converts to a sale. Answers: is our offering competitive? Are we trusted? Are we presenting the quote effectively? Are we closing the deal?

**Technical definition**

`COUNT(DISTINCT quote_id WHERE is_purchased = True) / COUNT(DISTINCT quote_id WHERE quote_status = 'Quoted')`

Source mart: `fct_quotes`

---

## 5. Average Premium and Commission

**Business definition**
Measures the average monthly premium and commission per purchased policy, segmented by insurer, age category, car make, and brand. Answers: where is our highest value business coming from? Are we going for volume or high-ticket sales?

**Technical definition**

| Metric | Definition |
|---|---|
| Average monthly premium | `AVG(monthly_premium) WHERE is_purchased = True` |
| Average monthly commission | `AVG(monthly_commission) WHERE is_purchased = True` |

Source mart: `fct_quotes`

Note: commission is consistently 10% of premium in this dataset. If that relationship changes in future, commission should be tracked independently rather than derived.
