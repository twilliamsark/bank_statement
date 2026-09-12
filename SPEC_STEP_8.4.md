# SPEC — Step 8.4: Manual Category / Subcategory (Save Remaining)

Parent: [`SPEC_STEP_8.md`](./SPEC_STEP_8.md) (overall Step 8 design)  
Prior: [`SPEC_STEP_8.1.md`](./SPEC_STEP_8.1.md), [`SPEC_STEP_8.2.md`](./SPEC_STEP_8.2.md), [`SPEC_STEP_8.3.md`](./SPEC_STEP_8.3.md)

Status: **Complete**

---

## Goal

Let the user **set or change** `category` and `subcategory` on each remaining `UnreconciledTransaction` via dropdowns so those rows become eligible for the **Save Reconciled** button from Step 8.3.

This is the “save remaining” path: Auto Reconcile (8.2) + Save Reconciled (8.3) handle matches; anything left is categorized by hand here, then saved with the same Save Reconciled action.

**Out of this chunk:** free-text categories; editing categories on already-committed `CreditCardTransaction`s; fingerprint dedupe.

---

## Decisions for 8.4

| Topic | Decision |
| ----- | -------- |
| UI control | Per-row **category** and **subcategory** `<select>`s (not free text) |
| Option source | Distinct values already present on `CreditCardTransaction` |
| Subcategory options | Filtered by the selected category (dependent dropdown) |
| Persist | PATCH individual staging row when selects change (Turbo preferred) |
| Eligibility for Save Reconciled | Unchanged from 8.3: both fields present → included on next Save Reconciled |
| Empty option lists | If no year-end (or other) txn categories exist yet, dropdowns are empty — guide user to import a year-end statement first |

---

## Behavior

On the Unreconciled Transactions list:

1. Replace static category/subcategory display with dropdowns on each row.
2. Category options:
   ```ruby
   CreditCardTransaction.distinct.order(:category).pluck(:category)
   ```
3. Subcategory options (for the row’s current/selected category):
   ```ruby
   CreditCardTransaction.where(category: selected).distinct.order(:subcategory).pluck(:subcategory)
   ```
4. Changing category refreshes subcategory options (Stimulus/Turbo); clear subcategory if it is no longer valid for the new category.
5. Changing either field PATCHes the `UnreconciledTransaction`.
6. When **both** are set, the row is eligible for **Save Reconciled** (8.3). No separate “reconciled” column required unless added for UI status.
7. User may change values that Auto Reconcile (8.2) already filled — edits overwrite staging fields until Save Reconciled commits them.
8. After manual fills, user clicks existing **Save Reconciled** → those rows copy to `CreditCardTransaction` and leave staging (8.3 service unchanged).

Optional UX polish (nice-to-have in 8.4, not blocking):

- Visual distinction for rows with both fields vs incomplete
- Header counts: `N ready to save / M total`
- Disable Save Reconciled when zero rows are complete (if not already done in 8.3)

---

## Routes

```ruby
resources :monthly_credit_card_statements, only: %i[…] do
  resources :unreconciled_transactions, only: %i[index update], module: :monthly_credit_card_statements
  # PATCH :update → category / subcategory
end
```

---

## Stimulus / Turbo

- Category change → update subcategory `<select>` options for that row without full-page reload.
- Successful PATCH → update row state (e.g. “ready” vs “needs category”) without losing scroll position if practical.
- Keep Save Reconciled as a normal form POST (`data-turbo-submits-with` ok).

---

## Explicitly out of Step 8.4

| Out | Notes |
| --- | ----- |
| Free-text / create-new category | Out of Step 8 |
| New Save Remaining button | Reuse **Save Reconciled** from 8.3 |
| Commit logic changes | 8.3 service already copies any fully categorized staging rows |
| Staging columns `posting_date` / `section` / `reference_number` | Still deferred |
| Committed-txn category editing | Out of Step 8 |

---

## Tests (minimum)

- PATCH with category + subcategory updates the staging row
- PATCH clearing one field leaves the row ineligible for Save Reconciled
- Subcategory options scoped to selected category
- Integration: set dropdowns on an unmatched row → Save Reconciled creates `CreditCardTransaction` and removes staging row
- Empty category list when no `CreditCardTransaction` categories exist (smoke / integration)

---

## Suggested implementation order

1. `unreconciled_transactions#update` (strong params: category, subcategory)
2. Replace table cells with selects; wire dependent subcategory Stimulus controller
3. Turbo PATCH on change
4. Optional ready/incomplete styling + counts
5. Tests

---

## Done when

- User can categorize remaining staging rows via dropdowns
- Those rows become Save Reconciled–eligible and commit through the 8.3 path
- End-to-end monthly flow works: Import (8.1) → Auto Reconcile (8.2) → Save Reconciled (8.3) → manually fix leftovers (8.4) → Save Reconciled again
