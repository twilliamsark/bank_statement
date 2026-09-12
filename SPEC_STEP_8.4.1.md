# SPEC — Step 8.4.1: Filter Unreconciled Transactions List

Parent: [`SPEC_STEP_8.md`](./SPEC_STEP_8.md)  
Prior: [`SPEC_STEP_8.4.md`](./SPEC_STEP_8.4.md)

Status: **Complete**

---

## Goal

Add the **same style of live filtering** to the monthly **Unreconciled transactions** list as on the credit card transactions list pages:

- Date from / to
- Category / subcategory
- Description (debounced partial match)
- Amount (debounced display-style match)

---

## Decisions

| Topic | Decision |
| ----- | -------- |
| Filter UX | Reuse shared CC filter form pattern (`live-filter` Stimulus + Turbo Frame) |
| Filter fields | `date_from`, `date_to`, `category`, `subcategory`, `description`, `amount` |
| Option source for filter selects | Distinct values on **this statement’s** `unreconciled_transactions` (compact; blank categories omitted from select — “All” still shows them) |
| Edit dropdown options | Unchanged from 8.4 — still from `CreditCardTransaction` distinct values |
| Save Reconciled / Auto Reconcile | Still operate on the **full** statement, not only the filtered subset |
| Ready-to-save count | Based on full statement staging rows |
| Pagination | Same 50-per-page pagination as CC transaction lists |
| Results | Counts (“X match of Y”), amount total for filtered set, empty filtered state |

---

## Implementation notes

1. Include `FilterableTransactions` on `UnreconciledTransaction` and add `apply_filters` (category/subcategory + common filters).
2. Wrap list results in `turbo_frame_tag "unreconciled_transactions"`.
3. Filter form GETs the unreconciled index with `data-turbo-frame="unreconciled_transactions"`.
4. After row PATCH (8.4), refresh the results frame (preserve filter params via hidden fields on the row form when practical).

---

## Done when

- Unreconciled list filters behave like the CC transactions list
- Filtering does not change Save Reconciled / Auto Reconcile scope
