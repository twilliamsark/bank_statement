# SPEC — Step 3: Routes, Controllers, Upload & Statement Summary UI

Parent document: [`SPEC.md`](./SPEC.md)  
Prior steps: [`SPEC_STEP_1.md`](./SPEC_STEP_1.md) (schema/models), [`SPEC_STEP_2.md`](./SPEC_STEP_2.md) (importers)

Status: **Complete** (integration tests green)

---

## What Step 3 is

Step 3 is the first **HTTP/UI surface**: browse statements, upload PDF/CSV through the Step 2 importers, and show **statement summary** pages. Money is displayed from integer cents; import flashes report **imported** vs **skipped duplicate** counts.

Live transaction filtering (Stimulus debounce / Turbo Frame lookahead) is **Step 4**. Step 3 should still wire nested `transactions#index` routes and a “View transactions” link — the index may be a simple unfiltered table or a thin stub that Step 4 enhances.

### Goals

1. Add routes: `root`, `account_statements`, `credit_card_statements`, nested `transactions#index`.
2. Implement controllers that call Step 2 importers on `create` and destroy statements on `destroy`.
3. Build **index / new / show** views for both statement types (Tailwind tables, multipart upload).
4. Show **summary** content on `#show` (balances/sections for account; year/categories for CC).
5. Display money via cents → dollars helpers (`Money.dollars` + `number_to_currency`); tolerate nil CSV metadata.
6. Flash success/alert including `imported_count` / `skipped_duplicate_count` (and errors from `Imports::Error`).
7. Minimal home page + usable flash rendering (full nav polish can lean on Step 5, but flashes must work).
8. Controller/integration tests: upload CSV via Rack test upload → redirect to show with expected summary fields.

### Depends on Steps 1–2

| Prerequisite | Why |
|--------------|-----|
| `AccountStatement` / `CreditCardStatement` (+ transactions) | Records to list/show/destroy |
| `Money.dollars` | Display |
| `AccountStatements::Importer` / `CreditCardStatements::Importer` | `create` action |
| `Imports::Result` / `Imports::Error` | Flash copy / rescue |
| Active Storage `source_file` | Optional “filename” display; destroy should remove attachment with record |

### Explicitly out of Step 3

| Deferred to | Work |
|-------------|------|
| Step 4 | Live description/amount filters, Turbo Frame refresh, Stimulus `live-filter`, date/type filter UX polish |
| Step 5 | Shared header nav polish, responsive filter layout, remove unused hello controller |
| Step 6 | Browser E2E with real Documents PDFs |
| Never (v1) | Auth, edit transactions, charts, statement-level reject-on-zero-import |

---

## Planned deliverables

### Routes

```ruby
root "home#index"

resources :account_statements, only: %i[index show new create destroy] do
  resources :transactions, only: :index, module: :account_statements
end

resources :credit_card_statements, only: %i[index show new create destroy] do
  resources :transactions, only: :index, module: :credit_card_statements
end
```

Optional (not required for Step 3): top-level cross-statement transaction indexes.

### Controllers

| Controller | Actions |
|------------|---------|
| `HomeController` | `index` |
| `AccountStatementsController` | `index`, `show`, `new`, `create`, `destroy` |
| `CreditCardStatementsController` | same |
| `AccountStatements::TransactionsController` | `index` (minimal list OK) |
| `CreditCardStatements::TransactionsController` | `index` (minimal list OK) |

**`create` flow:**

1. Require `params[:file]` (or nested strong params) — multipart.
2. Call importer with `io:` + `filename:` (from upload) or equivalent.
3. On success: redirect to statement `show` with flash, e.g.  
   `"Imported %{imported} transactions (%{skipped} skipped as duplicates)."`
4. On `Imports::Error`: redirect to `new` (or render `new`) with `flash.now[:alert]` / `flash[:alert]`.
5. On missing file: same alert path.

**`destroy`:** `statement.destroy!` → redirect to index with notice. Confirm via `data-turbo-confirm`.

### Views

**Home**

- Links to Account Statements and Credit Card Statements indexes.

**Account statements**

- `index` — table: period / account name / import format / txn count / link to show; “Import” button.
- `new` — form `multipart: true`, file field `accept=".pdf,.csv,application/pdf,text/csv"`.
- `show` — header metadata; balance summary table (nil-safe for CSV); section totals (`GROUP BY section` / Ruby group); link to transactions; destroy.

**Credit card statements**

- `index` — year / filename / total spend / txn count.
- `new` — same upload pattern.
- `show` — year, page count, total spend; category / subcategory totals; link to transactions; destroy.

**Transactions (minimal for Step 3)**

- Unfiltered table of the statement’s transactions (date, description, type fields, amount from cents).
- Enough that “View transactions” is not a dead link; Step 4 adds filters.

### Display helpers

- Prefer an `ApplicationHelper` (or dedicated helper) e.g. `cents_to_currency(cents)` → `number_to_currency(Money.dollars(cents))` with nil → “—” or blank.
- Dates: `l(date)` when present.
- Negatives: withdrawals/credits should read as negative currency (Rails `number_to_currency` handles signed values).

### Layout / flash (minimum bar)

- Render `notice` and `alert` in the layout (or a shared partial).
- Step 5 may restyle nav; Step 3 must not leave users without feedback after import/destroy.

### UI conventions (from parent SPEC)

- Tailwind utility classes; readable tables with zebra/hover.
- Mobile-friendly enough that primary actions are reachable (Step 5/6 deepen viewport checks).

### Tests

| Case | Expectation |
|------|-------------|
| Account CSV upload `POST create` | Creates statement; redirects to show; flash mentions imported count |
| Show page | Asserts key summary text / amounts (from cents) |
| CC CSV upload | Same pattern; show includes year / spend |
| Destroy | Removes statement + transactions; redirects to index |
| Bad/missing file | Alert flash; no statement created |
| Nested transactions index | 200 OK listing rows for that statement |

Use tmpdir CSV content (same shape as Step 2 fixtures). Do not commit PDFs; optional system/browser PDF checks wait for Step 6.

---

## Acceptance checklist (Step 3)

- [x] Root and both statement resource routes work
- [x] Can upload account CSV and CC CSV through the UI and land on summary
- [x] Summary shows cents-converted money; CSV hollow metadata does not crash the page
- [x] Flash shows imported vs skipped counts after import
- [x] Index lists statements; destroy removes statement + txns
- [x] “View transactions” reaches a working nested index (filters optional until Step 4)
- [x] Integration/controller tests green
- [x] No Stimulus live-filter requirement yet (Step 4)

---

## What shipped

### Routes / controllers / views

- `root` → `HomeController#index`
- `AccountStatementsController` + `CreditCardStatementsController` — index/show/new/create/destroy
- Nested `*::TransactionsController#index` with table partials ready for Step 4 Turbo Frames
- Tailwind summary/upload pages; CSV hollow-summary note on account show
- `cents_to_currency` / `display_date` / `display_text` helpers
- Shared flash partial in layout

### Tests

- `test/integration/account_statements_test.rb`
- `test/integration/credit_card_statements_test.rb`

### Changes along the way

1. Import flash special-cases zero imports with skips: “No new transactions (N skipped as duplicates).”
2. Transaction table extracted to `_table` partials for Step 4.
3. Index uses `includes` + `.size` to avoid N+1 count queries.
4. **UI refresh (“finance workspace” theme)** — after the first functional UI shipped, look-and-feel was upgraded beyond the bare Step 3 scaffold: sticky header nav, teal/slate brand tokens, shared component classes (`btn-primary`, `card-pad`, `data-table`, empty states), gradient home hero, and calmer summary/import/transaction pages. Styles live in `app/assets/tailwind/application.css` (`@theme` + `@layer components`). This overlaps some of Step 5’s “layout/nav polish” intent; Step 5 can focus on remaining chrome/responsive filter polish rather than inventing a new visual language.

### UI standards going forward (depend on the finance-workspace refresh)

Later steps (**especially Step 4 filters** and **Step 5 polish**) should extend this system, not replace it.

| Standard | Expectation |
|----------|-------------|
| **Theme source of truth** | Brand/canvas/ink/muted/line colors and shared components live in `app/assets/tailwind/application.css`. Prefer adding a `@layer components` class over one-off utility soup when the same pattern appears twice. |
| **Do not `@apply` custom components into other custom components** | Tailwind v4 rejects `@apply btn` inside `.btn-primary`. Duplicate the base utility list or extract shared tokens only via `@theme`. |
| **Buttons** | Primary actions → `btn-primary`; secondary/cancel → `btn-secondary`; destructive → `btn-danger`. Avoid raw `bg-gray-900` button classes on new UI. |
| **Surfaces** | Cards/panels → `card` / `card-pad`. Tables → `data-table-wrap` + `data-table`. Empty lists → `empty-state`. |
| **Page chrome** | Titles → `page-title` + optional `page-subtitle`; section labels → `eyebrow` or `stat-label`. Keep content inside the existing `app-main` max width (`max-w-6xl`). |
| **Nav** | Sticky header in `layouts/application.html.erb` is the app chrome. New top-level sections get a nav link with the same active-state pattern (`bg-brand-50 text-brand-800` when current). |
| **Flash** | Use `shared/flash` only; don’t invent alternate toast markup per feature. |
| **Money / dates / blanks** | Always `cents_to_currency`, `display_date`, `display_text` (or extend those helpers)—never print raw cents or leave nil holes. |
| **Step 4 filter UI** | Filter bars should sit above the existing `_table` partials, use `card-pad` or a light toolbar strip, stack on small screens, and keep primary filter submit affordances on `btn-primary` / text links in brand teal. Turbo Frame should wrap the **table** (and result count), not the whole page shell/nav. |
| **Step 5 scope** | Assume the visual language is set. Focus on responsive filter layout, any remaining density/spacing tweaks, and removing dead Stimulus (e.g. `hello_controller`)—not a second redesign. |
| **Copy tone** | Calm, operational finance workspace (clear labels, short helper text). Prefer “Summary balances unavailable from CSV…” style callouts (amber pill) over loud banners for non-error states. |

---

## Areas of concern

### Hollow CSV summaries look “broken”

Account CSV imports leave account/period/balances nil (Step 2). The show page must use nil-safe display (“—” / “Not available from CSV”) and ideally a short note that **PDF imports include full summary**. Otherwise users will file false bug reports.

### Re-import creates another statement row

Checksum dedupe is **transaction**-level. Re-uploading the same file creates a new statement with `imported_count: 0` and high `skipped_duplicate_count`. Step 3 **must** surface those counts in the flash. Consider copy like: “No new transactions (42 skipped as duplicates).” Index clutter from empty re-imports remains a known SPEC tradeoff (not fixed here).

### Large PDF uploads on the request cycle

Year-end PDFs can be large and parse/insert thousands of rows synchronously (Step 2). The `create` action may be slow or time out in development. Acceptable for v1 personal use; do not block Step 3 on Solid Queue. Mention slow imports in UI only if easy (e.g. disable double-submit).

### Multipart + Turbo

File uploads should use a normal full-page form post (Turbo handles multipart). Avoid forcing `data-turbo="false"` unless something breaks; if Turbo + file upload misbehaves, disable Turbo on that form only.

### Strong params / param name consistency

Pick one file param name (`:file` or `account_statement[source_file]`) and keep both statement types consistent. Importer expects `io:` + `filename:` — map from `ActionDispatch::Http::UploadedFile` (`upload.tempfile` / `upload.path` + `upload.original_filename`). Prefer `Importer.call(io: upload, filename: upload.original_filename)` so `Imports::SourceFile` writes a suffix-correct tempfile.

### Double-submit / duplicate clicks

Users may click Import twice → two statement rows and confusing skip counts. Mitigate lightly (button disable via Stimulus later, or `data-turbo-submits-with`). Not a hard blocker.

### Destroy vs Active Storage purge

`dependent: :destroy` on transactions is in place; confirm attachment blobs are purged (or orphaned harmlessly on Disk service). Add a test that destroy removes the statement record; blob purge can be asserted if straightforward.

### Amount display consistency

All views should go through one helper so `1234` cents never prints as `$1234`. Watch section/category totals: aggregate in cents in Ruby/SQL, convert once for display.

### Section / category totals on show

Compute with `group(:section).sum(:amount_cents)` (and CC group by category/subcategory). Do not re-parse the PDF. Totals should include only **stored** transactions (already deduped against prior imports).

### Nested transactions controller ownership

Step 3 adds the controller/route; Step 4 will expand the same action with filters. Avoid painting yourself into a corner (e.g. hard-coded full-page-only markup without a partial for the table). A `_transactions_table` partial now makes Step 4’s Turbo Frame easier.

### Naming collisions (still)

Controllers/views are `AccountStatementsController` / `account_statements` — good. Never name a controller after the gem (`BankAccountStatement`). Home link labels can say “Bank account statements” in prose while routes stay `account_statements`.

### Security unchanged

Upload UI exposes PDF/CSV parsing to whoever can hit the app. Still no auth or file size limits. Step 3 makes the risk reachable over HTTP — keep local-only assumptions explicit.

### Layout `mt-28` / bare flex

Current layout is a default scaffold (`mt-28`, flex main). Summaries may look oddly spaced until Step 5. Prefer readable content over perfect chrome in Step 3; do not spend the step on a design system.

### What success looks like before Step 4

1. Visit `/` → open Account Statements → Import CSV → see summary with section totals and flash counts.  
2. Click View transactions → see rows.  
3. Same for credit card CSV.  
4. Destroy returns to index; record gone.  
5. Re-import same CSV → new statement, flash shows skips, txn table globally does not double-count prior checksums.

---

## Key files to add (Step 3)

```
config/routes.rb
app/controllers/home_controller.rb
app/controllers/account_statements_controller.rb
app/controllers/credit_card_statements_controller.rb
app/controllers/account_statements/transactions_controller.rb
app/controllers/credit_card_statements/transactions_controller.rb
app/helpers/application_helper.rb          # cents_to_currency, etc.
app/views/home/index.html.erb
app/views/account_statements/{index,new,show}.html.erb
app/views/credit_card_statements/{index,new,show}.html.erb
app/views/account_statements/transactions/index.html.erb
app/views/credit_card_statements/transactions/index.html.erb
app/views/layouts/application.html.erb     # flash at minimum
app/views/shared/_flash.html.erb           # optional
test/controllers/**/*_test.rb
# and/or
test/integration/*_test.rb
SPEC_STEP_3.md                             # this file
```

---

## Implementation notes when coding starts

1. Reuse Step 2 CSV fixture patterns in integration tests (inline pipe-delimited files as `Rack::Test::UploadedFile` or `fixture_file_upload`).  
2. Keep show templates nil-safe from day one.  
3. Extract a transactions table partial to reduce Step 4 churn.  
4. After implementation, set Status to **Complete** and add “What shipped / changes along the way” (same pattern as Steps 1–2).
