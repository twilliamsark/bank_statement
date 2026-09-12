# SPEC — Step 8.3: Save Reconciled → CreditCardTransaction

Parent: [`SPEC_STEP_8.md`](./SPEC_STEP_8.md) (overall Step 8 design)  
Prior: [`SPEC_STEP_8.1.md`](./SPEC_STEP_8.1.md), [`SPEC_STEP_8.2.md`](./SPEC_STEP_8.2.md)  
Next: [`SPEC_STEP_8.4.md`](./SPEC_STEP_8.4.md) (manual category/subcategory dropdowns)

Status: **Not started**

---

## Goal

Commit staging rows that already have both **category** and **subcategory** into the shared `credit_card_transactions` table:

1. Add `monthly_credit_card_statement_id` as a FK on `CreditCardTransaction` (and make year-end parent nullable so monthly-only rows can exist).
2. Add a **Save Reconciled** button that copies those staging rows into `CreditCardTransaction`, then deletes them from `UnreconciledTransaction` inside the same DB transaction.

Rows still missing category or subcategory stay in staging.

**Out of this chunk:** manual dropdowns to set categories (Step 8.4). After 8.2, Save Reconciled primarily covers auto-matched rows; 8.4 unlocks the rest.

---

## Decisions for 8.3

| Topic | Decision |
| ----- | -------- |
| Button label | **Save Reconciled** |
| Eligible rows | `UnreconciledTransaction`s with **both** `category` and `subcategory` present (and not a potential duplicate — see 8.6) |
| Commit target | `CreditCardTransaction` with `monthly_credit_card_statement_id` set |
| Year-end FK | `credit_card_statement_id` becomes **nullable**; monthly commits leave it `nil` |
| Parent XOR | Exactly one of `credit_card_statement_id` / `monthly_credit_card_statement_id` must be present |
| Atomicity | Create final rows + destroy staging rows in **one** DB transaction |
| Location | Set `location` to `""` on committed monthly rows (no location on monthly PDFs) |
| Checksum / fingerprint | Assigned by existing `CreditCardTransaction` model callbacks/helpers after categories are known |

---

## Data model changes

### `credit_card_transactions`

| Change | Notes |
| ------ | ----- |
| `monthly_credit_card_statement_id` | new nullable FK → `monthly_credit_card_statements` |
| `credit_card_statement_id` | become **nullable** (required today) |
| XOR validation | exactly one parent statement FK present |
| `category` / `subcategory` | remain **required** on this table (only created when staging already has both) |

Associations:

- `CreditCardTransaction` `belongs_to :monthly_credit_card_statement, optional: true`
- `MonthlyCreditCardStatement` `has_many :credit_card_transactions` (committed rows; keep `has_many :unreconciled_transactions` for staging)
- `CreditCardAccount` transaction counts/lists must include monthly-committed rows — today `has_many :credit_card_transactions, through: :credit_card_statements` misses them. Add a combined association/method used by account show / filters (or equivalent union).

---

## Service

### `UnreconciledTransactions::SaveReconciled` (name flexible)

Given a `MonthlyCreditCardStatement`:

1. Select staging rows where `category` and `subcategory` are both present.
2. In one `ActiveRecord::Base.transaction`:
   - For each eligible row, create `CreditCardTransaction` with:
     - `monthly_credit_card_statement_id` = statement id
     - `credit_card_statement_id` = `nil`
     - `date`, `description`, `amount_cents`, `category`, `subcategory` from staging
     - `location` = `""`
     - checksum / `import_fingerprint` via existing model behavior
   - Destroy that staging row after successful create (or destroy all eligible after creates — same transaction).
3. Return `saved_count` (and optionally leave `remaining_count` for flash).

If zero eligible rows: button disabled and/or no-op safe; flash accordingly.

Skip rows with `potential_duplicate: true` once Step 8.6 exists; until then, eligibility is category/subcategory only.

---

## UI

On the Unreconciled Transactions list:

- **Save Reconciled** button (top; bottom optional to match parent Step 8 UX).
- Disabled when no staging rows have both category and subcategory.
- On success: flash saved count; re-render list showing only remaining (uncategorized) staging rows.
- Committed rows no longer appear in staging; they should show up wherever account / statement transaction lists include monthly-backed `CreditCardTransaction`s.

### Routes

```ruby
# nested under monthly_credit_card_statements
resource :save_reconciled, only: %i[create], module: :monthly_credit_card_statements
# POST → UnreconciledTransactions::SaveReconciled → redirect back to unreconciled index
```

---

## Explicitly out of Step 8.3

| Out | Notes |
| --- | ----- |
| Category/subcategory dropdowns | Step 8.4 |
| Auto Reconcile algorithm | Step 8.2 (already specified) |
| Staging extras (`posting_date`, `section`, `reference_number`) | Not required to commit |
| `reconciled` / `match_source` columns | Still optional; “both fields present” is the eligibility rule |
| Fingerprint-based monthly dedupe | Out of Step 8 |
| Monthly statement summary cents columns / rich `#show` | Optional polish |

---

## Tests (minimum)

- Migration: `monthly_credit_card_statement_id` present; `credit_card_statement_id` nullable
- XOR validation: rejects both-null and both-present parents
- Save Reconciled: creates `CreditCardTransaction`s with monthly FK, nil year-end FK, copied fields, `location: ""`
- Eligible staging rows destroyed; rows missing category or subcategory remain
- Zero eligible → no creates / safe no-op
- Account-facing transaction listing includes monthly-committed rows (if association updated in this chunk)

---

## Suggested implementation order

1. Migration: monthly FK + nullable year-end FK
2. Model validations + associations (including account combined txns)
3. `UnreconciledTransactions::SaveReconciled`
4. Route + controller + **Save Reconciled** button
5. Tests

---

## Done when

- Categorized staging rows can be committed to `CreditCardTransaction` under the monthly statement
- Those staging rows are removed atomically after copy
- Uncategorized staging rows remain for Step 8.4 (manual fills) + another Save Reconciled
