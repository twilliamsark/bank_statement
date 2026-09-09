# SPEC — Step 4: Transaction Filters + Stimulus Live Filter

Parent document: [`SPEC.md`](./SPEC.md)  
Prior steps: [`SPEC_STEP_1.md`](./SPEC_STEP_1.md), [`SPEC_STEP_2.md`](./SPEC_STEP_2.md), [`SPEC_STEP_3.md`](./SPEC_STEP_3.md) (UI + nested transaction indexes)

Status: **Complete** (filter model + integration tests green)

---

## What Step 4 is

Step 4 turns the Step 3 **statement-scoped transaction lists** into filterable pages with:

- Date range and type filters (submit on change)
- **Live partial-match** filtering on description and amount as you type (debounced; no autocomplete dropdown)

This is the “lookahead filtering” locked in the parent SPEC: the list updates live; there is no suggestion popup.

### Goals

1. Extend `AccountStatements::TransactionsController#index` and `CreditCardStatements::TransactionsController#index` to apply GET query filters.
2. Add a filter form above each transactions table (finance-workspace styling per Step 3 UI standards).
3. Wrap **result count + table** (not the app shell/nav) in a Turbo Frame `transactions`.
4. Add Stimulus `live_filter_controller.js`: debounce ~250ms on description/amount `input`; immediate submit on date/type `change`.
5. Keep filters **bookmarkable** via query params; provide clear-filters link and empty-state when no rows match.
6. Amount filter matches the **dollar display form** of `amount_cents` (e.g. `12.3` → `12.34` / `-12.30`), with parameterized SQL only.
7. Integration tests for each filter dimension (date, type, description, amount) on at least one statement type (ideally both).

### Depends on Step 3

| Prerequisite | Why |
|--------------|-----|
| Nested transaction routes + controllers | Extend `#index` in place |
| `_table` partials | Reuse inside Turbo Frame; avoid rewriting table markup |
| Finance-workspace UI standards | Filter toolbar / cards / buttons / empty states |
| `cents_to_currency` | Display only; filtering uses SQL on cents→dollar string |

### Explicitly out of Step 4

| Deferred to | Work |
|-------------|------|
| Step 5 | Broader layout/nav tweaks, remove `hello_controller`, fine responsive polish if not already done for filters |
| Step 6 | Browser E2E with real Documents PDFs (typing filters manually) |
| Step 4.5 | Per-account **master** transactions across statements ([`SPEC_STEP_4_5.md`](./SPEC_STEP_4_5.md)) |
| Never (v1) | Autocomplete suggestion dropdowns; single global all-accounts mega-list; amount min/max range UI (optional later improvement) |
---

## Planned deliverables

### Filters

| Param | Account statements | Credit card statements |
|-------|--------------------|------------------------|
| `date_from` | Inclusive lower bound on `date` | same |
| `date_to` | Inclusive upper bound on `date` | same |
| `section` | Exact match select (type) | — |
| `category` | — | Exact match select (type) |
| `subcategory` | — | Optional exact match select |
| `description` | Case-insensitive partial `LIKE` / `LOWER(...) LIKE` | same |
| `amount` | Partial match on dollar formatting of `amount_cents` | same |

Select options for type filters should be derived from **distinct values on that statement** (not a hard-coded BoA list), so CSV/PDF imports both work.

### Query / controller shape

Prefer scopes on the transaction models or a small private filter method—keep controllers thin:

```ruby
@transactions = @account_statement.account_transactions
  .then { |rel| Filters::AccountTransactions.apply(rel, params) } # example
  .order(:date, :id)
```

Or model scopes: `.for_date_range`, `.for_section`, `.description_like`, `.amount_display_like`.

**Amount matching (SQLite-first, as deployed):**

1. Normalize user input: strip `$`, commas, whitespace.
2. If blank after normalize → no amount predicate.
3. Bound parameter query, e.g.  
   `WHERE printf('%.2f', amount_cents / 100.0) LIKE :q`  
   with `q = "%#{normalized}%"` — **never** interpolate into SQL.
4. Negatives: typing `-25` should match `printf` of `-2500` cents (`-25.00`).

**Description:** `WHERE LOWER(description) LIKE LOWER(:q)` with `%value%`, or SQLite `LIKE` with care for case (SQLite ASCII case-insensitive for ASCII by default depending on collation—prefer explicit `LOWER` for clarity).

### Lookahead (Stimulus + Turbo)

```
[ filter form: GET, data-controller=live-filter, data-turbo-frame=transactions ]
[ turbo-frame#transactions ]
    result count + clear link
    _table partial OR empty-state
```

Stimulus `live_filter_controller.js`:

- `input` on description/amount → debounce 250ms → `this.element.requestSubmit()` (or form target)
- `change` on date_from/date_to/section/category/subcategory → submit immediately
- Optional: ignore submit if values unchanged

Form must target the Turbo Frame (`data-turbo-frame="transactions"`) so only the frame morphs.

### UI (finance-workspace)

From [`SPEC_STEP_3.md`](./SPEC_STEP_3.md) UI standards:

- Filter bar: `card-pad` or light toolbar; **stack on small screens**
- Primary actions / clear: brand teal text link or `btn-secondary` for clear; avoid inventing new button styles
- Turbo Frame wraps **count + table**, not header/nav
- Empty filter results: `empty-state` (“No transactions match these filters”)
- Result count updates inside the frame (e.g. “12 transactions” / “3 of 40 transactions”)

### Tests

| Case | Expectation |
|------|-------------|
| No params | All statement txns (Step 3 behavior) |
| `date_from` / `date_to` | Inclusive range |
| `section` or `category` | Exact type filter |
| `description` partial | Case-insensitive match |
| `amount` partial | `12.3` matches `12.34`; works with leading `-` |
| Combined filters | AND semantics |
| Clear filters | Link back to unfiltered index |
| Bookmarkable | Same URL params reproduce filter |

Use factory/setup via importer CSV fixtures (tmpdir), not committed PDFs.

---

## Acceptance checklist (Step 4)

- [x] Account and CC transaction indexes accept the filter params above
- [x] Live typing on description/amount refreshes the Turbo Frame (debounced)
- [x] Date/type changes refresh immediately
- [x] Amount filter uses dollar-string matching on `amount_cents` with bound SQL
- [x] Result count + clear-filters work
- [x] Filters are bookmarkable GET params
- [x] UI follows finance-workspace components (no redesign)
- [x] Integration tests cover each filter dimension
- [x] `_table` partials reused inside the frame

---

## What shipped

### Filtering

- `FilterableTransactions` concern — shared date / description / amount scopes (`amount_display_like` uses SQLite `printf` of cents)
- `AccountTransaction.apply_filters` / `CreditCardTransaction.apply_filters` (+ section / category / subcategory)
- Controllers pass GET params through filters; type selects from distinct values on that statement

### UI / JS

- Filter forms outside `turbo-frame#transactions` (preserves input focus)
- Frame contains result count + `_table` / empty-state via `_results` partial
- Stimulus `live_filter_controller.js` — 250ms debounce on description/amount; immediate submit on date/type
- Clear filters link; finance-workspace `card-pad` toolbar

### Tests

- `test/models/account_transaction_filter_test.rb`
- `test/integration/account_statement_transactions_filter_test.rb`
- `test/integration/credit_card_statement_transactions_filter_test.rb`

### Changes along the way

1. Isolated amount `printf` matching in the concern (SQLite-shaped, easy to replace later).
2. Invalid date params fall back to unfiltered date range rather than raising.
3. Form stays outside the Turbo Frame so lookahead typing does not reset focus.

---

## Areas of concern

### Amount `printf` / `LIKE` is SQLite-shaped

Parent SPEC already flagged this as brittle for Postgres later. Step 4 should isolate the amount predicate in one method/scope so a future min/max or cents-normalized search can replace it without rewriting controllers. Document the SQLite dependency in code comments next to the scope.

### False comfort from `LIKE` on formatted dollars

`12` matches `12.34` and `112.00` and `-12.00`. That is intentional for “lookahead” UX but can surprise. Acceptable for v1; do not over-engineer tokenization unless users complain.

### Debounce + Turbo race

Fast typing can fire overlapping requests; older responses might overwrite newer ones. Mitigations: debounce 250ms; rely on Turbo’s default request handling; optionally abort via `data-turbo-action` patterns if we see flicker. Test manually in Step 6.

### Filter form outside vs inside the frame

If the form sits **outside** the frame but targets it, inputs keep focus while typing (preferred). If the whole form is inside the frame, focus can reset on each refresh—bad for lookahead. **Keep inputs outside the frame** (or use `data-turbo-permanent`); refresh only count+table inside.

### Distinct type options on large statements

Building `<select>` options via `distinct.pluck(:section)` per request is fine at personal scale. For year-end CC with many subcategories, consider grouping category first then subcategory (optional subcategory filter can depend on selected category in a later enhancement—not required if both are independent selects).

### AND vs OR semantics

All provided filters combine with **AND**. Empty params are ignored. Spec this in tests so “clear one field” behavior stays obvious.

### XSS / SQL injection

Description and amount strings must use bound parameters only. Views already escape output; do not use `html_safe` on user filter echoes. When showing “Filtered by …”, use normal ERB escaping.

### Performance on year-end PDFs

Thousands of rows + `LOWER(description) LIKE` + `printf` per request is OK for local SQLite personal use. Avoid loading all rows into Ruby for filtering. Keep `order(:date, :id)` after filters. No pagination required in v1 (may make frame updates heavy—monitor in Step 6).

### Duplicate filter logic across account vs CC

Two controllers will share date/description/amount logic but differ on type fields. Extract a concern or `Filters::` object early to avoid drift.

### UI regression risk

Step 3 set the visual language. Step 4 should not reintroduce gray scaffold buttons or unstyled forms. Add filter-specific component classes to `application.css` only if the same markup repeats.

### What success looks like before Step 5

1. Open an account statement → View transactions.  
2. Type part of a description → table narrows without full page reload.  
3. Type `12.3` in amount → matching dollar amounts remain.  
4. Set a date range and section → AND filter works; URL is shareable.  
5. Clear filters → full list returns.  
6. Same flows on a credit card statement with category (and optional subcategory).

---

## Key files to add / change (Step 4)

```
app/javascript/controllers/live_filter_controller.js
app/controllers/account_statements/transactions_controller.rb   # filter
app/controllers/credit_card_statements/transactions_controller.rb
app/models/account_transaction.rb                               # scopes (optional)
app/models/credit_card_transaction.rb
app/views/account_statements/transactions/index.html.erb        # form + frame
app/views/credit_card_statements/transactions/index.html.erb
app/views/**/transactions/_filters.html.erb                     # optional partial
app/assets/tailwind/application.css                             # only if new repeated classes
test/integration/account_statement_transactions_filter_test.rb
test/integration/credit_card_statement_transactions_filter_test.rb
SPEC_STEP_4.md                                                  # this file
```

---

## Implementation notes when coding starts

1. Implement filter scopes + integration tests before Stimulus polish if helpful—GET params work without JS.  
2. Put the form outside `turbo-frame#transactions`; frame contains count + table/empty.  
3. Register Stimulus controller via existing importmap eager load (`live_filter_controller.js`).  
4. After implementation, set Status to **Complete** and add “What shipped / changes along the way.”
