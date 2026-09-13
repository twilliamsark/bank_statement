# SPEC — Step 8.5.1: Edit Category / Subcategory on Account Transactions Index

Parent: [`SPEC_STEP_8.md`](./SPEC_STEP_8.md)  
Prior: [`SPEC_STEP_8.5.md`](./SPEC_STEP_8.5.md)  
Related UX: [`SPEC_STEP_8.4.md`](./SPEC_STEP_8.4.md) (same dropdown pattern on unreconciled staging rows)

Status: **Complete**

---

## Goal

On `credit_card_accounts#transactions` (`/credit_card_accounts/:id/transactions`), let the user **change `category` and `subcategory`** on each committed `CreditCardTransaction` via per-row dropdowns (same interaction model as unreconciled Step 8.4).

This covers year-end and monthly-committed rows shown on the account master transaction list.

**Out of this chunk:** free-text / create-new categories ([`SPEC_STEP_8.5.2.md`](./SPEC_STEP_8.5.2.md)); editing on statement-scoped transaction indexes (year-end or monthly) unless trivial to share the same partial; fingerprint / checksum redesign beyond updating checksum when categories change.

---

## Decisions for 8.5.1

| Topic | Decision |
| ----- | -------- |
| Surface | `credit_card_accounts/transactions#index` only (required) |
| UI control | Per-row **category** and **subcategory** `<select>`s (not free text) |
| Option source | Distinct values already present on `CreditCardTransaction` (global, same as 8.4) |
| Subcategory options | Filtered by the selected category (dependent dropdown; reuse `category-subcategory` Stimulus controller) |
| Persist | `PATCH` individual `CreditCardTransaction` when a select changes (Turbo preferred) |
| Required fields | `category` and `subcategory` remain **required** on `CreditCardTransaction` — blank option should not clear to nil (or reject blank on update) |
| Checksum | Recalculate `checksum` when category/subcategory change (existing `checksum_for` inputs include those fields) |
| Filters / pagination | Preserve current filter query params across PATCH (hidden fields / redirect), same idea as unreconciled 8.4.1 |
| Statement column | Keep statement link column; editable cells replace static category/subcategory text |

---

## Behavior

1. Replace static category/subcategory cells in the account transactions table with dependent dropdowns.
2. Category options:
   ```ruby
   CreditCardTransaction.distinct.order(:category).pluck(:category)
   ```
3. Subcategory options for the selected category:
   ```ruby
   CreditCardTransaction.where(category: selected).distinct.order(:subcategory).pluck(:subcategory)
   ```
4. Changing category rebuilds subcategory options; if the prior subcategory is invalid for the new category, clear/select blank only long enough to force a valid pick — do **not** persist a row with blank subcategory.
5. Changing either field PATCHes that `CreditCardTransaction`.
6. Successful update refreshes the row (Turbo Stream) and keeps the results Turbo Frame / filters intact.
7. Edits apply equally to year-end-backed and monthly-backed rows on the list.

### Suggested routes

```ruby
resources :credit_card_accounts, only: %i[index show] do
  resources :transactions, only: %i[index update], module: :credit_card_accounts
end
# PATCH /credit_card_accounts/:credit_card_account_id/transactions/:id
```

Strong params: `category`, `subcategory` only. Ensure the transaction belongs to the account (`all_credit_card_transactions`).

---

## Implementation notes

- Prefer reusing `category-subcategory` Stimulus + a row partial pattern similar to unreconciled `_row`.
- Account transactions table currently lives in `credit_card_statements/transactions/_table` with `show_statement: true`. Either:
  - specialize the account results to an editable table/partial, or
  - add an `editable:` local that swaps static cells for selects without breaking statement-scoped indexes.
- On update, if `checksum` is only assigned `if blank?`, force reassignment when category/subcategory change (e.g. clear checksum before save, or always recompute when those attrs change).

---

## Explicitly out of Step 8.5.1

| Out | Notes |
| --- | ----- |
| Free-text categories | Out of Step 8 |
| Required editing on `credit_card_statements/.../transactions` or monthly statement transactions | Optional follow-on if shared partial makes it free |
| Changing amount/date/description | Out of scope |
| Auto Reconcile behavior changes | Separate (ambiguous Apple prefix, etc.) |

---

## Tests (minimum)

- PATCH with valid category + subcategory updates the `CreditCardTransaction` and recalculates checksum
- PATCH rejecting blank category/subcategory (still required)
- Transaction from another credit card account cannot be updated via this nested route
- Integration: account transactions index renders category/subcategory selects; changing values persists
- Year-end and monthly-backed rows on the same account list are both editable

---

## Suggested implementation order

1. Nested `transactions#update` + membership check + checksum refresh
2. Editable row UI on account transactions index (Stimulus dependent selects)
3. Turbo Stream / filter-param preservation
4. Tests

---

## Done when

- User can correct categories on committed account transactions from the master list without re-importing
- Dropdown UX matches unreconciled (8.4): dependent subcategory, auto-save on change
- Checksums stay consistent with the new category/subcategory values
