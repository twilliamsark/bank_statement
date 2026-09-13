# SPEC — Step 8.5.2: Free-Text Category / Subcategory

Parent: [`SPEC_STEP_8.md`](./SPEC_STEP_8.md)  
Prior: [`SPEC_STEP_8.4.md`](./SPEC_STEP_8.4.md), [`SPEC_STEP_8.5.1.md`](./SPEC_STEP_8.5.1.md)

Status: **Complete**

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

---

## Addendum — post-implementation polish (after 8.5.2)

These follow-on fixes were made in response to real usage of the free-text category UI and the account transactions list. They supersede conflicting details above where noted.

### 1. Subcategory locked until category is set

- Subcategory input is **disabled** when category is blank (placeholder: “Enter category first”).
- Stimulus enables/disables as the user types a category.
- Server-side (`CategorizationLabels`): blank category always clears subcategory on normalize.

### 2. Category change always blanks subcategory

- Any **real** category change clears subcategory and rebuilds its suggestion list.
- On account transactions (`requireSubcategory`), save waits until the user picks a subcategory.
- Supersedes the softer “clear only if invalid for new category” wording in the original UX section.

### 3. Datalist “show all options” focus behavior

Browsers filter `<datalist>` options by the current input value, so a filled field hid sibling suggestions (e.g. Merchandise only showed `Other Stores/Retail`).

- On **user** focus of category or subcategory: temporarily clear the input so the full suggestion list appears.
- On blur with no new value: restore the previous value.
- Focus-clear runs only after **pointerdown** (real click), not when Turbo restores focus after a PATCH — that bug showed a blank subcategory until click-off.

### 4. Category / subcategory field layout

- Fields stay **side by side** (`flex-nowrap`); do not wrap subcategory under category when the row gets tall.
- Fixed width per field (`w-40`), not `flex-1`, so they do not stretch full-row width when description wraps.
- Shared partial: `shared/_category_subcategory_fields`.

### 5. Account transactions description / amount layout

Unfiltered rows with long descriptions pushed **Amount** off-screen.

- Description cell: word-wrap (`break-words whitespace-normal`) with capped max-width.
- Max-width tightened by **5ch** vs Tailwind `xs`/`sm`/`md` caps:
  `max-w-[calc(20rem-5ch)]` / `sm:max-w-[calc(24rem-5ch)]` / `lg:max-w-[calc(28rem-5ch)]`.

### 6. Wider app shell (more viewable area)

Not category-specific, but done in the same polish pass for transaction tables:

- Content max width: `max-w-6xl` → **`max-w-7xl`** (header / main / footer).
- Outer horizontal padding reduced: `px-4/6/8` → **`px-3/4/5`**; main vertical padding slightly reduced.

### Locked behavior summary (combobox)

Applies to **both** surfaces: account transactions **and** unreconciled transactions (shared `category-subcategory` Stimulus + `shared/_category_subcategory_fields`).

| Action | Result |
| ------ | ------ |
| No category | Subcategory disabled / cleared |
| Change category | Subcategory cleared; **do not PATCH until subcategory is chosen**; focus moves to subcategory and opens its suggestion menu |
| Focus category/subcategory | Opens a **custom suggestion menu** with all options (native `<datalist>` abandoned — too unreliable across focus/arrow/Turbo) |
| Type in field | Filters the open menu; free-text values still allowed on change/blur |
| Pick from menu | Sets the field and saves (subcategory) / continues to subcategory (category) |
| Click outside | Closes menus |

**Unreconciled note:** Uses the same shared combobox (`requireSubcategory: true`) so category change does not Turbo-refresh mid-edit.

**Implementation note:** Suggestions are rendered in Stimulus-managed `<ul>` menus under each input, not browser datalists.