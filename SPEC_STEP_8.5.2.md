# SPEC — Step 8.5.2: Free-Text Category / Subcategory

Parent: [`SPEC_STEP_8.md`](./SPEC_STEP_8.md)  
Prior: [`SPEC_STEP_8.4.md`](./SPEC_STEP_8.4.md), [`SPEC_STEP_8.5.1.md`](./SPEC_STEP_8.5.1.md)

Status: **Not started**

---

## Goal

Allow the user to **type new category and subcategory values** (not only pick from existing distinct values) on:

1. **Unreconciled** list (`UnreconciledTransaction` — Step 8.4 UI)
2. **Account transactions** list (`CreditCardTransaction` — Step 8.5.1 UI)

Existing values remain available for quick pick; free text creates/reuses labels that then appear in future dropdowns/suggestions.

---

## Decisions for 8.5.2

| Topic | Decision |
| ----- | -------- |
| Surfaces | Unreconciled index **and** `credit_card_accounts/transactions#index` |
| Control shape | Combobox-style: suggestions from existing distinct values **plus** ability to type a new value (not a bare free-text field with no suggestions, and not select-only) |
| Category | May be an existing value or a new string |
| Subcategory | May be an existing value for the chosen category, an existing global subcategory string, or a new string |
| Dependent behavior | Prefer filtering subcategory suggestions by selected category when that category already exists in data; if category is brand-new, subcategory suggestions may be empty (user types freely) |
| Persistence | Same PATCH-on-change as 8.4 / 8.5.1 |
| Normalization | Trim whitespace; reject blank after trim; do **not** auto-title-case (preserve user casing) |
| Deduping labels | Case-sensitive storage for v1 (matches current DB strings); optional later: case-insensitive merge |
| `CreditCardTransaction` | Category/subcategory remain required; checksum recalculated on change (8.5.1) |
| `UnreconciledTransaction` | Category/subcategory may still be blank until both set (Save Reconciled eligibility unchanged) |
| New values in filters | After save, new labels appear in filter/select option lists on subsequent loads |

---

## UX

Per editable row (both surfaces):

1. Category control shows existing categories as suggestions; user may type a new category and commit (blur / Enter / change).
2. Subcategory control shows suggestions for the current category when available; user may type a new subcategory.
3. Changing category still clears subcategory if the previous subcategory is not kept (same as 8.4 when switching categories) — user must set subcategory again for required committed rows.
4. Do not require a separate “Add category” admin screen; first use of a new string is enough.

Implementation may use:

- `<input list="…">` + `<datalist>` of existing values, or
- a small Stimulus combobox that allows custom values

Reuse/extend `category-subcategory` rather than inventing a second pattern.

---

## Behavior details

### Option / suggestion sources

Unchanged base lists:

```ruby
CreditCardTransaction.distinct.order(:category).pluck(:category)
CreditCardTransaction.where(category: selected).distinct.order(:subcategory).pluck(:subcategory)
```

When the typed category is not yet in `CreditCardTransaction`, subcategory datalist may be empty until something is saved under that category.

### Validation

- Strip leading/trailing spaces before save.
- `CreditCardTransaction`: both fields required after strip.
- `UnreconciledTransaction`: allow blank; if one is present and the other blank, Save Reconciled still skips the row (8.3 rule).
- Reasonable max length (e.g. 100 chars) to avoid accidental paste bombs — enforce in model validations.

### After save

- New category/subcategory strings immediately become available as suggestions on other rows after Turbo refresh / next page load.
- Account show category totals and Auto Reconcile unanimous matching will treat the new labels like any other stored strings.

---

## Explicitly out of Step 8.5.2

| Out | Notes |
| --- | ----- |
| Category taxonomy admin CRUD | No separate manage-categories page |
| Renaming/merging existing labels in bulk | Follow-on |
| Case-insensitive canonicalization | Follow-on |
| AI-suggested categories | Out of scope |
| Editing on statement-scoped txn indexes | Still optional (8.5.1 out); include only if shared partial already editable |

---

## Tests (minimum)

- Unreconciled: PATCH with a **new** category + subcategory persists and enables Save Reconciled when both present
- Account transactions: PATCH with a new category + subcategory persists; checksum updates
- Blank/whitespace-only rejected for committed txns; stripped values saved
- Suggestions still include prior distinct values; after creating a new category, a subsequent row can select it
- Dependent subcategory suggestions empty (or unfiltered) for a never-before-seen category without error

---

## Suggested implementation order

1. Model length/presence + strip normalization (both models as appropriate)
2. Replace `<select>`-only UI with combobox/datalist (shared partial or Stimulus extension)
3. Wire unreconciled + account transaction row forms
4. Tests

---

## Done when

- User can invent a new category/subcategory on unreconciled rows and on account transaction rows without pre-seeding year-end data
- Existing values remain easy to pick
- New labels flow into later suggestions, filters, and Auto Reconcile like any other stored category pair
