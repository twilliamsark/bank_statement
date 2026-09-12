# SPEC — Step 8.2.1: Monthly Statements on Credit Card Summary

Parent: [`SPEC_STEP_8.md`](./SPEC_STEP_8.md)  
Prior: [`SPEC_STEP_8.2.md`](./SPEC_STEP_8.2.md)

Status: **Complete**

---

## Goal

On the credit card account summary (`credit_card_accounts#show`):

1. List **monthly statements** on the page, with **year-end statements below** them.
2. Put a **View Unreconciled Transactions** button at the **very top** of the page that goes to the unreconciled list for the most recent monthly statement that still has staging rows (e.g. `/monthly_credit_card_statements/:id/unreconciled_transactions`).

---

## Decisions

| Topic | Decision |
| ----- | -------- |
| Unreconciled button target | Most recent `MonthlyCreditCardStatement` for this card that has ≥1 `UnreconciledTransaction` |
| Button visibility | Show only when such a statement exists |
| Monthly list order | Newest first (`created_at` / period end desc) |
| Year-end list | Existing year-end table, placed **below** monthly section |
| Monthly row actions | **View Unreconciled** link on each monthly statement row → that statement’s unreconciled list |

---

## UI

### Top actions

Above or as the first control in the header action group (visually at the top of the page):

- **View Unreconciled Transactions** → `monthly_credit_card_statement_unreconciled_transactions_path(statement)` for the chosen monthly statement
- Keep existing View transactions / Import Year End / Import Monthly controls

### Statements sections

1. **Monthly statements** — table: period (or —), file, format, unreconciled count, link (Unreconciled / View)
2. **Year-end statements** — existing table, heading clarified as year-end if helpful

---

## Done when

- Card summary shows monthly statements above year-end statements
- Top **View Unreconciled Transactions** reaches the correct unreconciled URL when staging rows exist
