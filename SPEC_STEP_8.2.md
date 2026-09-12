# SPEC — Step 8.2: Auto Reconcile Unreconciled Transactions

Parent: [`SPEC_STEP_8.md`](./SPEC_STEP_8.md) (overall Step 8 design)  
Prior chunk: [`SPEC_STEP_8.1.md`](./SPEC_STEP_8.1.md)  
Depends on: `UnreconciledTransaction` + monthly import UI from 8.1

Status: **Not started**

---

## Goal

Add an **Auto Reconcile** button on the Unreconciled Transactions UI that walks staging rows **missing category and/or subcategory** and fills them from matching year-end `CreditCardTransaction`s using the Step 8 match algorithm.

**Out of this chunk:** manual dropdown reconcile, committing staging rows into `CreditCardTransaction`, duplicate detection via `import_fingerprint`.

---

## Decisions for 8.2

| Topic | Decision |
| ----- | -------- |
| Trigger | Explicit **Auto Reconcile** button (not during monthly import) |
| Which rows | Only `UnreconciledTransaction`s that do **not** already have both `category` and `subcategory` set |
| Match key | Same account + `amount_cents` + first **21** description characters (`description[0, 21]`) — **no date** |
| Match source | Year-end-backed `CreditCardTransaction`s on the same `CreditCardAccount` only |
| Ambiguous matches | If matching year-end rows disagree on `(category, subcategory)`, leave the staging row unchanged |
| Unanimous matches | Set `category` + `subcategory` on the staging row |

This matches the locked algorithm in [`SPEC_STEP_8.md`](./SPEC_STEP_8.md) (category match key vs `import_fingerprint`).

---

## Algorithm

For each eligible `UnreconciledTransaction` `U` belonging to monthly statement `M` on credit card account `A`:

1. Skip if `U.category` and `U.subcategory` are both present.
2. Build prefix: `description.to_s[0, 21]`.
3. Find candidate year-end `CreditCardTransaction`s for account `A`:
   - Same `amount_cents` as `U`
   - Description prefix equals the 21-char prefix (SQL `LEFT(description, 21)` or equivalent at personal scale)
   - Scoped to the same card only (via `credit_card_statements` / account association — not monthly-committed rows for this chunk; year-end parents only)
4. Collect distinct `(category, subcategory)` pairs from candidates.
5. If exactly **one** distinct pair → assign both fields on `U` and save.
6. If zero candidates, or multiple disagreeing pairs → leave `U` unchanged.

Add a small pure helper (do not overload `import_fingerprint`):

```ruby
def self.category_match_prefix(description)
  description.to_s[0, 21]
end
```

(`import_fingerprint` / 21-char helper alignment from the parent Step 8 spec may be done here if convenient, but **must not** be used to skip or match Auto Reconcile rows.)

---

## Service

### `UnreconciledTransactions::AutoReconcile`

Input: a `MonthlyCreditCardStatement` (or its `unreconciled_transactions` relation).

Behavior:

1. Iterate eligible rows (missing category and/or subcategory).
2. Apply the algorithm above.
3. Return a result object with counts, e.g.:
   - `examined_count`
   - `reconciled_count` (successfully filled)
   - `skipped_count` (already had both fields, or no/ambiguous match — optionally split later)

Idempotent: running Auto Reconcile again should not clear already-filled categories; already-complete rows are skipped.

---

## UI

On the Unreconciled Transactions list from 8.1:

- Add **Auto Reconcile** button (top; bottom optional).
- On submit: run the service for that monthly statement, then re-render the list (redirect or Turbo).
- Flash summary: how many rows were filled (and optionally how many remained unmatched).
- After a successful auto-match, those rows show populated **category** and **subcategory** in the table.
- Rows with no unanimous match remain blank.

No category/subcategory dropdowns required in 8.2 — display only (manual edit comes later).

### Routes

Something like:

```ruby
# nested under monthly_credit_card_statements
resource :auto_reconcile, only: %i[create], module: :monthly_credit_card_statements
# POST → UnreconciledTransactions::AutoReconcile → redirect back to unreconciled index
```

Exact controller name is flexible; button must POST and return to the list.

---

## Explicitly out of Step 8.2

| Out | Notes |
| --- | ----- |
| Auto-run matching inside the monthly importer | 8.1 import stays blank; user presses Auto Reconcile |
| Manual category/subcategory selects | Later chunk |
| `reconciled` boolean / `match_source` columns | Optional later; 8.2 can treat “both fields present” as reconciled |
| Import / commit into `CreditCardTransaction` | Later chunk |
| Matching across different cards | Same account only |
| Using `import_fingerprint` for dedupe | Out of Step 8 |

---

## Tests (minimum)

- Unanimous same-account year-end match on amount + 21-char prefix → fills category/subcategory
- No candidates → row unchanged
- Multiple year-end matches with **different** category/subcategory pairs → row unchanged
- Multiple year-end matches that **agree** → fills once
- Rows that already have both fields are not overwritten / are skipped
- Different credit card account with identical amount+prefix does **not** match
- Integration: Auto Reconcile button on unreconciled list updates displayed categories after POST

---

## Suggested implementation order

1. Category match prefix helper
2. `UnreconciledTransactions::AutoReconcile` service
3. Route + controller action + button on unreconciled list
4. Flash + re-render
5. Tests

---

## Done when

- User can import a monthly statement (8.1), then click **Auto Reconcile**
- Matching staging rows get category/subcategory from same-account year-end transactions per the 21-char + amount rule
- Ambiguous or missing matches stay blank
- No rows are committed to `CreditCardTransaction` yet
