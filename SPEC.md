# Bank Statement App — Import, Schema, Summary & Transaction Pages

## Goal

Turn this near-greenfield Rails 8.1 app into a host for Bank of America **bank account statements** and **credit-card year-end statements**, using the existing path gems:

- `BankAccountStatement` (`Extractor` / `CSVExtractor`)
- `CCYearEndStatement` (`Extractor` / `CSVExtractor`)

Decisions locked in:

- **Separate models + pages** for bank vs credit-card (not polymorphic/STI)
- **Upload UI + import services** (Active Storage file → gem extractor → persisted rows)
- **Lookahead filtering** = live partial-match filter as you type (debounced Turbo Frame refresh; no autocomplete dropdown)

## Current state

- Rails shell only: no domain models, migrations, routes (except `/up`), or feature views
- Gems already in `Gemfile`; parsing must stay in gems
- Empty leftover `app/services/year_end_statements/`
- UI stack: Tailwind + Turbo + Stimulus + importmap
- Sample files available locally under `/Users/todd/Documents/BoA_*` for manual verification (not committed)

---

## Data model

### 1. `bank_account_statements`

| Column | Type | Notes |
|--------|------|-------|
| `account_name` | string | nullable (CSV imports) |
| `account_number` | string | nullable (CSV) |
| `period_start` | date | nullable (CSV) |
| `period_end` | date | nullable (CSV) |
| `page_count` | integer | nullable (CSV) |
| `beginning_balance` | decimal(12,2) | from Summary; nullable |
| `deposits` | decimal(12,2) | nullable |
| `withdrawals` | decimal(12,2) | nullable |
| `checks` | decimal(12,2) | nullable |
| `service_fees` | decimal(12,2) | nullable |
| `ending_balance` | decimal(12,2) | nullable |
| `apy_earned` | decimal(8,4) | nullable |
| `interest_paid_ytd` | decimal(12,2) | nullable |
| `source_filename` | string | original upload basename |
| `import_format` | string | `pdf` or `csv` |
| timestamps | | |

- `has_one_attached :source_file`
- `has_many :bank_account_transactions, dependent: :destroy`

Indexes: `[period_start, period_end]`, `account_number`

### 2. `bank_account_transactions`

| Column | Type | Notes |
|--------|------|-------|
| `bank_account_statement_id` | fk | required |
| `date` | date | required |
| `description` | text | required |
| `amount` | decimal(12,2) | signed; required |
| `section` | string | e.g. Deposits / Withdrawals; required |
| timestamps | | |

Indexes: `date`, `section`, `description` (for LIKE), composite useful for filters

### 3. `credit_card_statements`

| Column | Type | Notes |
|--------|------|-------|
| `statement_year` | integer | derived from earliest/latest txn year or filename; nullable if empty |
| `page_count` | integer | nullable (CSV) |
| `source_filename` | string | |
| `import_format` | string | `pdf` or `csv` |
| `total_spend` | decimal(12,2) | sum of category totals (or txns) at import |
| timestamps | | |

- `has_one_attached :source_file`
- `has_many :credit_card_transactions, dependent: :destroy`

Index: `statement_year`

### 4. `credit_card_transactions`

| Column | Type | Notes |
|--------|------|-------|
| `credit_card_statement_id` | fk | required |
| `date` | date | required |
| `description` | text | required |
| `location` | string | required from gem (can be blank string) |
| `amount` | decimal(12,2) | signed; credits negative |
| `category` | string | required |
| `subcategory` | string | required |
| timestamps | | |

Indexes: `date`, `category`, `subcategory`, `description`

**Why denormalize section/category/subcategory onto transactions:** matches gem flat `#transactions` shape, simplifies filtering and summary rollups without a groups table. Category/section totals for summary pages can be computed with `GROUP BY` or cached on the statement at import if needed.

**Money:** use `decimal`, never float. Map gem `BigDecimal` with `.to_d` / store as-is.

---

## Import flow

```
Upload form (type + PDF/CSV)
  → Active Storage attach
  → Importer service
      → choose Extractor vs CSVExtractor by extension
      → persist statement + transactions in one transaction
  → redirect to statement summary
```

### Services

- `BankAccountStatements::Importer.call(uploaded_file:)`
  - `.pdf` → `BankAccountStatement::Extractor`
  - `.csv` → `BankAccountStatement::CSVExtractor`
  - Creates `BankAccountStatement` + bulk-inserts transactions from `result.transactions`
  - Copies summary fields when present (PDF only)

- `CreditCardStatements::Importer.call(uploaded_file:)`
  - `.pdf` → `CCYearEndStatement::Extractor`
  - `.csv` → `CCYearEndStatement::CSVExtractor`
  - Creates `CreditCardStatement` + transactions
  - Sets `statement_year` from `transactions.map(&:date).map(&:year).minmax` (prefer single year; if span, use max year or mode — document as “year of latest transaction”)
  - Sets `total_spend` from sum of category totals (or txn amounts)

Both importers:

- Save tempfile from Active Storage blob for gem `filename:`
- Set `import_format`, `source_filename`
- Raise / rescue with flash-friendly errors (`ArgumentError`, `Errno::ENOENT`, unsupported extension)
- Remove empty leftover `app/services/year_end_statements/`

Active Storage: run `bin/rails active_storage:install` if tables missing, then migrate.

---

## Routes & pages

```ruby
root "home#index"

resources :bank_account_statements, only: %i[index show new create destroy] do
  resources :transactions, only: :index, module: :bank_account_statements
end

resources :credit_card_statements, only: %i[index show new create destroy] do
  resources :transactions, only: :index, module: :credit_card_statements
end
```

Optional convenience: top-level `GET /bank_account_transactions` and `GET /credit_card_transactions` for cross-statement browsing with the same filters (nice-to-have; statement-scoped pages are required).

### Home / nav

- Simple landing with links: Bank Statements | Credit Card Statements
- Shared nav in layout (replace bare `container` flex with a small header + flash)

### Statement summary pages (`#show`)

**Bank account summary**

- Account name/number, period, import format
- Balance summary table (beginning, deposits, withdrawals, checks, fees, ending, APY, interest YTD)
- Section totals (GROUP BY `section`)
- Link to “View transactions”
- Destroy / re-import not required beyond destroy

**Credit card summary**

- Statement year, filename, page count, total spend
- Category totals table; expandable or nested subcategory totals (`GROUP BY category, subcategory`)
- Link to transactions

### Statement index + upload (`#index`, `#new`/`#create`)

- List statements with key metadata and link to show
- Upload form: file field accepting `.pdf,.csv`; create posts to importer

### Transaction pages (`#index`)

Filters required:

| Filter | Behavior |
|--------|----------|
| Date from / to | exact range on `date` |
| Type | bank: `section` select; CC: `category` select (and optionally subcategory) |
| Description | **live partial match** (`ILIKE %query%` / SQLite `LIKE`) |
| Amount | **live partial match** on string form of amount (e.g. typing `12.3` matches `12.34`, `-12.30`) |

**Lookahead implementation (Stimulus + Turbo):**

- Filter form wrapped in Turbo Frame `transactions`
- Stimulus controller `live-filter`:
  - On `input` for description/amount: debounce ~200–300ms, then `form.requestSubmit()`
  - On `change` for date/type: submit immediately
- Controller responds with Turbo Frame HTML of the filtered table
- Use `GET` query params so filters are bookmarkable
- Amount filter: compare against `CAST(amount AS TEXT)` or `printf`/normalized string containing the typed digits — keep simple: `WHERE CAST(amount AS TEXT) LIKE :q` after normalizing user input (strip `$`, commas)

Also show result count and clear-filters link.

---

## UI conventions

- Tailwind utility classes; readable tables with zebra/hover
- Flash messages for import success/failure
- Money helper: `number_to_currency` (handle negatives)
- Date helper: `l(date, format: :default)`
- Keep layout mobile-friendly (stack filters on small screens) — verify desktop + mobile viewports in browser

---

## Testing (Minitest)

1. **Model** validations / associations
2. **Importer** unit tests with tmpdir CSV fixtures (inline pipe-delimited content matching gem writers) — no committed PDFs
3. **Controller/integration** tests: create via upload, show summary, filter transactions by date/type/description/amount
4. Optional skippable PDF smoke test if `/Users/todd/Documents/...` exists (match existing gem test style)

---

## Implementation order

1. Active Storage install + domain migrations + models
2. Importer services + model tests with CSV fixtures
3. Routes, controllers, summary + upload views
4. Transaction index with filters + Stimulus live-filter
5. Layout/nav polish
6. Browser verification with real Documents samples (bank PDF/CSV + CC PDF/CSV)
7. Fix any issues found; run test suite

## Out of scope

- Auth / multi-user
- Editing individual transactions
- Recategorization
- Charts/graphs (summary tables only)
- Graphite/PRs unless asked

## Key files to add

- `db/migrate/*_create_bank_account_statements.rb` (+ transactions, credit_card_*)
- `app/models/bank_account_statement.rb`, `bank_account_transaction.rb`, `credit_card_statement.rb`, `credit_card_transaction.rb`
- `app/services/bank_account_statements/importer.rb`, `app/services/credit_card_statements/importer.rb`
- Controllers under `app/controllers/` (+ nested transaction controllers)
- Views under `app/views/bank_account_statements/`, `credit_card_statements/`, nested `transactions/`
- `app/javascript/controllers/live_filter_controller.js`
- Tests under `test/models/`, `test/services/`, `test/controllers/` or `test/integration/`
