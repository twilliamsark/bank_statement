# SPEC — Step 8.6: Fingerprint Potential-Duplicate Flag

Parent: [`SPEC_STEP_8.md`](./SPEC_STEP_8.md) (overall Step 8 design)  
Prior: [`SPEC_STEP_8.1.md`](./SPEC_STEP_8.1.md) (`import_fingerprint` on staging)  
Related: [`SPEC_STEP_8.2.md`](./SPEC_STEP_8.2.md) (Auto Reconcile), [`SPEC_STEP_8.3.md`](./SPEC_STEP_8.3.md) (Save Reconciled)

Status: **Not started**

---

## Goal

When importing monthly rows into `unreconciled_transactions`, if a new row’s `import_fingerprint` already exists for the **same credit card account** (in staging or in committed `credit_card_transactions`), mark the new row as a **potential duplicate**.

The user must **manually clear** that flag before the row is eligible for:

- **Auto Reconcile** (category fill), and
- **Save Reconciled** (copy into `credit_card_transactions`)

Duplicates are **not** auto-skipped or auto-deleted — they stay visible in staging until the user clears the flag or deletes the row.

---

## Decisions for 8.6

| Topic | Decision |
| ----- | -------- |
| Flag column | `potential_duplicate` boolean on `unreconciled_transactions`, default `false` |
| When set | At monthly import time, on the **newly created** staging row |
| Compare against | Same `CreditCardAccount` only: existing `UnreconciledTransaction`s **and** `CreditCardTransaction`s |
| Match key | `import_fingerprint` equality (already `MD5(date \| description[0,21] \| amount_cents)` from 8.1) |
| Same import batch | First row with a novel fingerprint for that account stays `false`; later rows with the same fingerprint are marked `true` (also mark `true` if fingerprint already exists in DB before this import) |
| Existing rows | Never rewrite an older staging/committed row’s data; only flag the newcomer |
| Clear flag | Manual UI action per row (or equivalent PATCH); clearing sets `potential_duplicate = false` |
| Eligibility | `potential_duplicate == true` → **ineligible** for Auto Reconcile and Save Reconciled until cleared |
| Cross-account | No match across different cards |

---

## Data model

### `unreconciled_transactions`

| Column | Type | Notes |
| ------ | ---- | ----- |
| `potential_duplicate` | boolean | `null: false`, default `false` |

Optional index: `[monthly_credit_card_statement_id, potential_duplicate]` and/or `[import_fingerprint]` (fingerprint index may already exist from 8.1).

---

## Import behavior

Update `MonthlyCreditCardStatements::Importer` (after computing `import_fingerprint` for each gem txn):

1. Resolve the target `CreditCardAccount` `A` (same as today).
2. Build a set of fingerprints already known for `A`:
   - All `UnreconciledTransaction` fingerprints for statements belonging to `A`
   - All `CreditCardTransaction` fingerprints for `A` (year-end and monthly-committed)
3. While inserting staging rows for this import (in order):
   - Compute fingerprint `F`
   - If `F` is in the known set → create row with `potential_duplicate: true`
   - Else → create with `potential_duplicate: false`, then add `F` to the known set (so later rows in the **same** file with the same `F` are flagged)

Still **create** the staging row either way (do not skip insert).

Importer result may include `potential_duplicate_count` for flash messaging.

---

## Eligibility rules (amend 8.2 / 8.3 behavior)

A staging row is eligible for Auto Reconcile and Save Reconciled only if:

1. `potential_duplicate` is **false**, and
2. Existing rules still hold (Auto Reconcile: missing category/subcategory; Save Reconciled: both category and subcategory present)

### `UnreconciledTransactions::AutoReconcile` (8.2)

- Skip rows with `potential_duplicate: true` (leave categories unchanged).

### `UnreconciledTransactions::SaveReconciled` (8.3)

- Select only rows with both category/subcategory **and** `potential_duplicate: false`.
- Flagged rows remain in staging even if categorized.

Manual category/subcategory edits (8.4) **may** still update flagged rows so the user can prepare them; Save remains blocked until the flag is cleared.

---

## UI

On the Unreconciled Transactions list:

- Show a clear **Potential duplicate** indicator on flagged rows (badge/status column).
- Control to **Clear duplicate flag** (button or checkbox → PATCH `potential_duplicate: false`).
- Optional: confirm copy (“Only clear this if you are sure this charge is not already imported.”).
- Auto Reconcile / Save Reconciled ignore flagged rows; flash may mention how many were skipped as potential duplicates.
- After import, flash can report staged count + potential duplicate count.

No requirement in 8.6 to delete flagged rows automatically; user can delete the monthly statement or individual row if a destroy action exists later.

### Routes

```ruby
# extend unreconciled_transactions update, or dedicated member route
resources :unreconciled_transactions, only: %i[index update] do
  # PATCH with potential_duplicate: false
end
```

---

## Explicitly out of Step 8.6

| Out | Notes |
| --- | ----- |
| Auto-delete or auto-skip insert of duplicates | Always stage; flag only |
| Matching across different credit cards | Same account only |
| Changing fingerprint algorithm | Stays 8.1 definition |
| Merging/linking to the “other” matched txn in UI | Optional later; flag + clear is enough |
| Clearing flag in bulk | Optional polish; per-row is required |

---

## Tests (minimum)

- Import when fingerprint exists on a committed same-account `CreditCardTransaction` → new staging row `potential_duplicate: true`
- Import when fingerprint exists on another staging row for same account → new row flagged
- Two identical lines in one file → first unflagged (if novel), second flagged
- Same fingerprint on a **different** card → not flagged
- Auto Reconcile skips flagged rows
- Save Reconciled skips flagged rows even when category/subcategory set
- PATCH clears flag → row becomes eligible for Save Reconciled
- Integration: UI shows potential-duplicate state and clear action

---

## Suggested implementation order

1. Migration: `potential_duplicate` on `unreconciled_transactions`
2. Importer fingerprint lookup + same-batch tracking
3. Gate Auto Reconcile + Save Reconciled queries
4. UI badge + clear-flag action
5. Tests

---

## Done when

- Re-importing (or overlapping) monthly charges surfaces as flagged staging rows instead of silently creating another path to `credit_card_transactions`
- User must explicitly clear `potential_duplicate` before Auto Reconcile / Save Reconciled will act on that row
- Fingerprint comparison is scoped to the same credit card account across staging and committed tables
