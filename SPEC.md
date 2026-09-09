# Bank Statement App — Import, Schema, Summary & Transaction Pages

## Query used to generate SPEC.md

We want a Rails application, use the existing Bank of America bank_statement application, whose data comes from reading bank statements and credit card statements.

Use the gems BankAccountStatement and CCYearEndStatement, they are already in the gemfile. HowTo can be found at: https://github.com/twilliamsark/bank_account_statements/blob/main/HOW_TO.md and https://github.com/twilliamsark/cc_year_end_statement/blob/main/HOW_TO.md respectively.

Import can either be in PDF or CSV. Both libraries handle both formats.

We need

- db schema for both statements and transactions
- statement summary pages
- transaction pages
- the transaction pages need filtering on date and type
- the transaction pages need lookahead filtering on description and amount

# SPEC.md

## Goal

Turn this near-greenfield Rails 8.1 app into a host for Bank of America **bank account statements** and **credit-card year-end statements**, using the existing path gems:

- `BankAccountStatement` (`Extractor` / `CSVExtractor`)
- `CCYearEndStatement` (`Extractor` / `CSVExtractor`)

Decisions locked in:

- **Separate models + pages** for bank vs credit-card (not polymorphic/STI)
- **Upload UI + import services** (Active Storage file → gem extractor → persisted rows)
- **Lookahead filtering** = live partial-match filter as you type (debounced Turbo Frame refresh; no autocomplete dropdown)
- **Money in cents** — all dollar amounts persist as signed integers (`*_cents`); convert to/from `BigDecimal` dollars only at the gem import/export boundary and for display
- **Transaction checksums** — each stored transaction has a content checksum; importers skip rows whose checksum already exists in the DB, but **do not** dedupe within a single import file (duplicate lines in one file are all stored)
- **Bank AR model names** — ActiveRecord classes and tables are `AccountStatement` / `AccountTransaction` (`account_statements` / `account_transactions`). `BankAccountStatement` is the gem module; `BankStatement` is the Rails application module — both names are unavailable for AR. Credit-card AR models stay `CreditCardStatement` / `CreditCardTransaction` (no clash with `CCYearEndStatement`).

## Current state

- Rails shell only: no domain models, migrations, routes (except `/up`), or feature views
- Gems already in `Gemfile`; parsing must stay in gems
- Empty leftover `app/services/year_end_statements/`
- UI stack: Tailwind + Turbo + Stimulus + importmap
- Sample files available locally under `/Users/todd/Documents/BoA_*` for manual verification (not committed)

---

## Data model

### 1. `account_statements`

| Column                    | Type         | Notes                                               |
| ------------------------- | ------------ | --------------------------------------------------- |
| `account_name`            | string       | nullable (CSV imports)                              |
| `account_number`          | string       | nullable (CSV)                                      |
| `period_start`            | date         | nullable (CSV)                                      |
| `period_end`              | date         | nullable (CSV)                                      |
| `page_count`              | integer      | nullable (CSV)                                      |
| `beginning_balance_cents` | integer      | from Summary; nullable; signed cents                |
| `deposits_cents`          | integer      | nullable                                            |
| `withdrawals_cents`       | integer      | nullable                                            |
| `checks_cents`            | integer      | nullable                                            |
| `service_fees_cents`      | integer      | nullable                                            |
| `ending_balance_cents`    | integer      | nullable                                            |
| `apy_earned`              | decimal(8,4) | **not** cents — percentage from statement; nullable |
| `interest_paid_ytd_cents` | integer      | nullable                                            |
| `source_filename`         | string       | original upload basename                            |
| `import_format`           | string       | `pdf` or `csv`                                      |
| timestamps                |              |                                                     |

- ActiveRecord model: **`AccountStatement`**
- `has_one_attached :source_file`
- `has_many :account_transactions`, `dependent: :destroy`

Indexes: `[period_start, period_end]`, `account_number`

### 2. `account_transactions`

| Column                 | Type    | Notes                                                                      |
| ---------------------- | ------- | -------------------------------------------------------------------------- |
| `account_statement_id` | fk      | required                                                                   |
| `date`                 | date    | required                                                                   |
| `description`          | text    | required                                                                   |
| `amount_cents`         | integer | signed cents; required                                                     |
| `section`              | string  | e.g. Deposits / Withdrawals; required                                      |
| `checksum`             | string  | content fingerprint; required; **not** unique (intra-import dupes allowed) |
| timestamps             |         |                                                                            |

Indexes: `date`, `section`, `description` (for LIKE), `checksum` (non-unique, for “already stored?” lookups)

ActiveRecord model: **`AccountTransaction`**.

### 3. `credit_card_statements`

| Column              | Type    | Notes                                                                |
| ------------------- | ------- | -------------------------------------------------------------------- |
| `statement_year`    | integer | derived from earliest/latest txn year or filename; nullable if empty |
| `page_count`        | integer | nullable (CSV)                                                       |
| `source_filename`   | string  |                                                                      |
| `import_format`     | string  | `pdf` or `csv`                                                       |
| `total_spend_cents` | integer | sum of category totals (or txns) at import; signed cents             |
| timestamps          |         |                                                                      |

- `has_one_attached :source_file`
- `has_many :credit_card_transactions, dependent: :destroy`

Index: `statement_year`

### 4. `credit_card_transactions`

| Column                     | Type    | Notes                                         |
| -------------------------- | ------- | --------------------------------------------- |
| `credit_card_statement_id` | fk      | required                                      |
| `date`                     | date    | required                                      |
| `description`              | text    | required                                      |
| `location`                 | string  | required from gem (can be blank string)       |
| `amount_cents`             | integer | signed cents; credits negative                |
| `category`                 | string  | required                                      |
| `subcategory`              | string  | required                                      |
| `checksum`                 | string  | content fingerprint; required; **not** unique |
| timestamps                 |         |                                               |

Indexes: `date`, `category`, `subcategory`, `description`, `checksum` (non-unique)

**Why denormalize section/category/subcategory onto transactions:** matches gem flat `#transactions` shape, simplifies filtering and summary rollups without a groups table. Category/section totals for summary pages can be computed with `GROUP BY` or cached on the statement at import if needed.

### Money (cents)

- Persist **all dollar amounts** as signed **integer cents** (`amount_cents`, `*_cents` summary fields). Never use float; never store dollars as `decimal` in these tables (except `apy_earned`, which is a rate).
- **Gem boundary:** extractors return `BigDecimal` dollars. Importers convert with a shared helper, e.g. `Money.cents(big_decimal) -> Integer` via `(big_decimal * 100).round` (document rounding mode; bank amounts are already 2dp).
- **Display / UI:** convert cents → dollars with `Money.dollars(cents) -> BigDecimal` (or `cents / 100.to_d`) and `number_to_currency`.
- **Export back to gems** (if ever writing CSV via gem writers): convert cents → `BigDecimal` dollars before calling the gem.
- Shared module: `app/models/concerns/money_cents.rb` or `app/lib/money.rb` used by importers, models, and helpers.

### Transaction checksums (cross-import dedupe)

**Purpose:** skip transactions that are **already stored** from a prior import. Duplicate lines **inside a single import file** must still all be inserted.

**Checksum payload (canonical string, then SHA-256 hex or similar):**

- Bank: `date|section|description|amount_cents` (ISO date, exact description text, integer cents)
- Credit card: `date|category|subcategory|description|location|amount_cents`

Do **not** include `statement_id` in the checksum (same logical txn re-imported on a new statement row should still match). Do **not** include import filename.

**Import algorithm:**

1. Load existing checksums for that transactions table into a Set (`AccountTransaction.distinct.pluck(:checksum)` or scoped query — full table Set is fine at personal scale).
2. For each gem transaction in order:
   - Convert amount → `amount_cents`; compute `checksum`.
   - If `checksum` is in the **pre-import** existing Set → skip (already stored).
   - Else → insert row (including checksum).
   - **Do not** add newly inserted checksums to the existing Set during this run — so a second identical line in the same file still inserts.
3. Create the parent statement even if every txn is skipped; flash should report `imported` vs `skipped_duplicate` counts.
4. **No UNIQUE DB constraint** on `checksum` — uniqueness would incorrectly block legitimate intra-file duplicates.

Helper: `AccountTransaction.checksum_for(date:, section:, description:, amount_cents:)` and `CreditCardTransaction.checksum_for(...)`, used by importers and tests.

## Import flow

```
Upload form (type + PDF/CSV)
  → Active Storage attach
  → Importer service
      → choose Extractor vs CSVExtractor by extension
      → map gem BigDecimal dollars → integer cents
      → compute txn checksums; skip rows already in DB (allow intra-file dupes)
      → persist statement + new transactions in one DB transaction
  → redirect to statement summary (flash imported / skipped counts)
```

### Services

- `AccountStatements::Importer.call(uploaded_file:)`
  - `.pdf` → `BankAccountStatement::Extractor` (gem)
  - `.csv` → `BankAccountStatement::CSVExtractor` (gem)
  - Creates `AccountStatement`; converts summary `BigDecimal` fields → `*_cents`
  - Maps each `result.transactions` row through cents + checksum; inserts only if checksum not already stored
  - Copies summary fields when present (PDF only)

- `CreditCardStatements::Importer.call(uploaded_file:)`
  - `.pdf` → `CCYearEndStatement::Extractor`
  - `.csv` → `CCYearEndStatement::CSVExtractor`
  - Creates `CreditCardStatement` + transactions (same cents + checksum rules)
  - Sets `statement_year` from `transactions.map(&:date).map(&:year).minmax` (prefer single year; if span, use max year or mode — document as “year of latest transaction”)
  - Sets `total_spend_cents` from sum of category totals (converted to cents) or sum of imported txn `amount_cents`

Both importers:

- Save tempfile from Active Storage blob for gem `filename:`
- Set `import_format`, `source_filename`
- Raise / rescue with flash-friendly errors (`ArgumentError`, `Errno::ENOENT`, unsupported extension)
- Remove empty leftover `app/services/year_end_statements/`
- Return a small result object: `statement`, `imported_count`, `skipped_duplicate_count`
  Active Storage: run `bin/rails active_storage:install` if tables missing, then migrate.

---

## Routes & pages

```ruby
root "home#index"

resources :account_statements, only: %i[index show new create destroy] do
  resources :transactions, only: :index, module: :account_statements
end

resources :credit_card_statements, only: %i[index show new create destroy] do
  resources :transactions, only: :index, module: :credit_card_statements
end
```

Optional convenience: top-level `GET /account_transactions` and `GET /credit_card_transactions` for cross-statement browsing with the same filters (nice-to-have; statement-scoped pages are required).

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

| Filter         | Behavior                                                                                                               |
| -------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Date from / to | exact range on `date`                                                                                                  |
| Type           | bank: `section` select; CC: `category` select (and optionally subcategory)                                             |
| Description    | **live partial match** (`ILIKE %query%` / SQLite `LIKE`)                                                               |
| Amount         | **live partial match** on the **dollar** display form of `amount_cents` (e.g. typing `12.3` matches `12.34`, `-12.30`) |

**Lookahead implementation (Stimulus + Turbo):**

- Filter form wrapped in Turbo Frame `transactions`
- Stimulus controller `live-filter`:
  - On `input` for description/amount: debounce ~200–300ms, then `form.requestSubmit()`
  - On `change` for date/type: submit immediately
- Controller responds with Turbo Frame HTML of the filtered table
- Use `GET` query params so filters are bookmarkable
- Amount filter: normalize user input (strip `$`, commas); match against SQL formatting of cents as dollars with bound parameters, e.g. SQLite `printf('%.2f', amount_cents / 100.0) LIKE :q` (keep parameterized — never interpolate). Prefer this over matching raw integer cents so typing `12.3` stays natural.
- Display amounts via money helper from `amount_cents`
  Also show result count and clear-filters link.

---

## UI conventions

- Tailwind utility classes; readable tables with zebra/hover
- Flash messages for import success/failure
- Money helper: cents → `number_to_currency` (handle negatives)
- Date helper: `l(date, format: :default)`
- Keep layout mobile-friendly (stack filters on small screens) — verify desktop + mobile viewports in browser

---

## Testing (Minitest)

1. **Model** validations / associations; checksum helper stability; money cents round-trip
2. **Importer** unit tests with tmpdir CSV fixtures (inline pipe-delimited content matching gem writers) — no committed PDFs
   - Converts gem dollars → `amount_cents` / summary `*_cents`
   - Intra-file duplicate lines → multiple rows with the same checksum
   - Second import of the same file → `imported_count` 0 (or only novel rows), `skipped_duplicate_count` > 0
3. **Controller/integration** tests: create via upload, show summary, filter transactions by date/type/description/amount
4. Optional skippable PDF smoke test if `/Users/todd/Documents/...` exists (match existing gem test style)

---

## Implementation order

1. Active Storage install + domain migrations + models (**include `*_cents` integer money columns, `checksum` on both transaction tables, non-unique checksum indexes, and shared `Money` cents helpers**)
2. Importer services + model/service tests with CSV fixtures (**gem `BigDecimal` → cents mapping; checksum skip-vs-allow-intra-file behavior; flash-ready imported/skipped counts**)
3. Routes, controllers, summary + upload views (**display via cents→dollars helpers; show skipped-duplicate flash**)
4. Transaction index with filters + Stimulus live-filter (**amount lookahead against dollar formatting of `amount_cents`**)
4.5. Master account transactions view — all statements for one `account_number`, same filters as Step 4 ([`SPEC_STEP_4_5.md`](./SPEC_STEP_4_5.md))
4.6. Persist bank `Account` from importer `account_name` (FK on statements) + account-level summary detail ([`SPEC_STEP_4_6.md`](./SPEC_STEP_4_6.md); depends on / retargets 4.5)
4.7. Credit card account name — user-assigned CC identity; required on import ([`SPEC_STEP_4_7.md`](./SPEC_STEP_4_7.md))
4.8. Master credit card transactions — all statements for one CC account, same filters as Step 4 ([`SPEC_STEP_4_8.md`](./SPEC_STEP_4_8.md); depends on 4.7)
4.9. Credit card account summary — category rollups per CC account ([`SPEC_STEP_4_9.md`](./SPEC_STEP_4_9.md); depends on 4.7–4.8)
5. Layout/nav polish
6. Browser verification with real Documents samples (bank PDF/CSV + CC PDF/CSV) — **re-import same file and confirm duplicates are skipped; confirm a file that itself contains duplicate lines still stores both on first import**; include bank/CC account master + summary flows if 4.5–4.9 are done
7. Fix any issues found; run test suite

### Step notes for the two adopted recommendations

These are **not** separate late steps — they land in Steps 1–2 (schema + importers) and are verified in Steps 3, 4, and 6.

| Recommendation              | Primary steps                                                                                                   | What “done” means                                                                     |
| --------------------------- | --------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| Store amounts as cents      | **1** (columns + `Money` helper), **2** (convert at gem boundary), **3–4** (display/filter)                     | No dollar `decimal` money columns except `apy_earned`; UI and filters work in dollars |
| Transaction checksum dedupe | **1** (`checksum` + index), **2** (skip already-stored; allow intra-file dupes), **6** (manual re-import check) | Re-import skips; first import of a file with two identical lines stores two rows      |

## Out of scope

- Auth / multi-user
- Editing individual transactions
- Recategorization
- Charts/graphs (summary tables only)
- Graphite/PRs unless asked

## Key files to add

- `db/migrate/*_create_bank_account_statements.rb` (+ rename to `account_*`, credit_card_*) — money as `*_cents` integers; `checksum` on transaction tables
- `app/models/account_statement.rb`, `account_transaction.rb`, `credit_card_statement.rb`, `credit_card_transaction.rb`
- `lib/money.rb` — dollars↔cents conversion
- Checksum helpers on transaction models
- `app/services/account_statements/importer.rb`, `app/services/credit_card_statements/importer.rb`
- Controllers under `app/controllers/` (+ nested transaction controllers)
- Views under `app/views/account_statements/`, `credit_card_statements/`, nested `transactions/`
- `app/javascript/controllers/live_filter_controller.js`
- Tests under `test/models/`, `test/services/`, `test/controllers/` or `test/integration/`

---

## Mid/long-term risks — security & architectural stability

The plan is solid for a personal BoA import host. Mid/long-term, the weak spots are mostly **trust boundaries** and **assumptions that will harden into the schema**.

### Security

**No auth is the largest gap.** The SPEC correctly leaves multi-user out of scope, but the app will hold account numbers, balances, and full spend history in SQLite + Active Storage. Anyone who can hit the process can read and upload. That is fine on `localhost` only; it becomes a serious issue the moment the app is bound to a LAN, tunneled, or deployed with Kamal. Mid-term you will want at least one of: bind to `127.0.0.1`, HTTP basic/`has_secure_password`, or session auth before any non-local exposure.

**Upload + PDF parsing is an attack surface.** Importers feed user files into `PDF::Reader` and CSV parsers. Risks: huge files (DoS / memory), extension spoofing (`.pdf` that is not a PDF), maliciously crafted PDFs, and unbounded transaction counts. The plan does not specify size limits, content-type checks, or virus/structural validation. Add caps (file size, page count, row count) and always derive format from sniffed type + extension, not the client alone.

**Financial data at rest is unencrypted.** Disk Active Storage + SQLite means statement PDFs and DB rows are plaintext on disk. Fine for a single-user machine with FileVault; weak for shared hosts, backups copied elsewhere, or cloud volumes. Longer term: encrypted credentials/storage, careful backup handling, and redacting `account_number` in logs/UI where possible.

**Filter queries are safe only if parameterized.** `LIKE` / `CAST(amount AS TEXT) LIKE` is fine with bound parameters; string interpolation would be an injection bug. Worth calling out in the transaction-filter implementation so it does not regress.

**No abuse controls.** Repeated uploads, Turbo filter spam, and destroy-without-reauth are acceptable for solo use; they are not for anything networked.

### Architectural stability

**Denormalized taxonomy is a trade-off that will calcify.** Putting `section` / `category` / `subcategory` on each transaction matches the gems and makes filtering easy. It makes later features harder: rename a category, merge subcategories, or attach budgets without backfills. If those ever matter, you will want group tables or a tagging model; migrating later is messy but doable.

**Two parallel domains forever.** Separate bank vs CC models/pages avoid premature abstraction (good). Cross-account “all spending” search, unified dashboards, or shared rules engines will mean duplicated filter/controller/view logic or a third read-model. Accept duplication until a real unified report appears; do not invent STI early.

**CSV imports permanently lose bank metadata.** That is honest to the gem API, but the UI will show sparse summaries and users may not understand why. Mid-term you may need manual metadata entry or “PDF preferred” guidance so CSV is not the primary path.

**`statement_year` and `total_spend_cents` are derived heuristics.** Latest-txn year and summed totals can disagree with the PDF branding or category header totals if data is partial. Store provenance (`import_format`, optional source-file checksum later) and treat derived fields as cached, not gospel.

**Transaction checksums are adopted (v1).** Cross-import skip of already-stored txn checksums is in scope; statement-level file checksum / reject-entire-file idempotency is still optional. Checksums that omit account identity can theoretically collide across accounts with identical lines — acceptable for a single-household app; revisit if multi-account false skips appear.

**Synchronous parse-in-request.** Large year-end PDFs can blow request timeouts. Solid Queue is already in the app; moving import to a background job is the stable path once files get big—schema can stay the same if you add `processing`/`failed`/`ready` status early (even if unused at first).

**Amount lookahead still formats dollars in SQL.** Storing cents removes float/decimal drift at rest; filter UX still uses dollar-string `LIKE` on `printf` of cents. A future improvement remains min/max amount filters for portability beyond SQLite.
**Tight coupling to BoA gem Result shapes.** Keeping parsing in gems is the right boundary. Stability depends on treating gem `Data.define` objects as an anti-corruption layer inside importers—map explicitly to attributes so gem field renames do not leak into controllers/views.

**Destruction model is blunt.** `dependent: :destroy` plus Active Storage purge is fine; there is no soft-delete or import audit trail. For financial records, append-only imports + “hide” often age better than hard delete.

### What not to change for v1

- Separate models/pages for v1
- Gem-owned parsing
- Upload → importer → summary flow
- Live Turbo filters for a personal app

### Follow-ons (not Step 1 blockers)

1. **Local-only / auth gate** before any deploy
2. **Upload size/page/row limits** (txn checksum dedupe and cents storage are now in v1 scope — see Decisions locked in)
3. **`status` on statements** so jobs can be added without a redesign
4. **Replace text amount LIKE** with min/max on cents (keep description live match)
5. **Explicit importer mapping layer** + tests against gem fixtures so gem churn stays contained
6. **Optional statement-level source-file checksum** to warn/reject whole-file re-uploads (complements per-txn checksums)

**Net:** The plan is architecturally appropriate for a single-user BoA workstation app. The mid-term risks are **unauthenticated sensitive data**, **unbounded upload/parse**, and **denormalized/duplicated domain shapes** that will resist unified reporting and recategorization—not the choice to avoid STI or keep two statement types. Cents-at-rest and per-transaction checksums address two of the earlier stability follow-ons inside Steps 1–2.

**SPEC.md:** _updated so checksum-based dedupe and cents storage are baked into the data model and implementation steps._
