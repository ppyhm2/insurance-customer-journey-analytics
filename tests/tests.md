# Testing Strategy

The tests below are non-exhaustive but representative of what should be implemented to ensure data quality across all three layers.

---

## Staging tests

| Test | Target | Description |
|---|---|---|
| Unique and not null | `proposal_id`, `quote_id`, `transaction_id`, `decline_id` | Primary key integrity |
| Accepted values | `drop_out_status` | Must be one of: `page_1`, `page_2`, `page_3`, `page_4`, `completed_form` |
| Accepted values | `quote_status` | Must be one of: `Quoted`, `Declined` |
| Accepted values | `payment_status` | Must be one of: `Success`, `Failed` |
| Greater than | `user_age` | Must be greater than 16 |
| Not null when condition | `monthly_premium` | Must never be null when `quote_status = 'Quoted'` |

---

## Intermediate tests

| Test | Target | Description |
|---|---|---|
| Referential integrity | `int_proposals_with_quotes.proposal_id` | Every `proposal_id` must exist in `stg_proposals` |
| Row count parity | `int_proposals_with_quotes` vs `stg_proposals` | Row counts must match — guards against join fan-out; each proposal should appear exactly once |

---

## Mart tests

| Test | Target | Description |
|---|---|---|
| Not null when condition | `fct_proposals.purchased_premium` | Must never be null when `was_purchased = True` |
| Null when condition | `fct_quotes.first_payment_status` | Must never be populated for unpurchased quotes |
| Always positive | `fct_quotes.monthly_premium` | Average premium must always be positive |

---

## Late-arriving data

With late-arriving data — for example a purchase occurring six months after a proposal is created — several issues can arise. The parameters used at proposal creation (age, pricing, risk profile, underwriting rules) may no longer be valid, meaning a purchased policy could be mispriced or misclassified.

**Recommended approach: quarantine**

Late-arriving records are moved to a separate table rather than deleted. This preserves an audit trail that can be referred to or restored if required, while keeping the core tables clean and trustworthy. All records tied to an affected `proposal_id` would be quarantined together.

The definition of "late" must be agreed with the business — the Insurance team is the right owner of that threshold. A starting point of **30 days** is reasonable to propose.
