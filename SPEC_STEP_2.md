# SPEC — Step 2: Importer Services (Gems → Cents → Checksum Dedupe)

Parent document: [`SPEC.md`](./SPEC.md)  
Prior step: [`SPEC_STEP_1.md`](./SPEC_STEP_1.md) (complete — schema, models, `Money`, `checksum_for`)

Status: **Complete** (CSV + PDF importer tests green)

---

## What Step 2 is

Step 2 turns uploaded (or file-path) PDF/CSV bytes into **persisted statements and transactions** by calling the existing gems, converting money to cents, and applying **cross-import checksum dedupe**.

No HTTP controllers, routes, or HTML yet — those are Step 3. Step 2 must still return a result object rich enough for Step 3 flashes (`imported_count`, `skipped_duplicate_count`).

### Goals

1. Implement **`AccountStatements::Importer`** wrapping gem `BankAccountStatement::{Extractor,CSVExtractor}`.
2. Implement **`CreditCardStatements::Importer`** wrapping gem `CCYearEndStatement::{Extractor,CSVExtractor}`.
3. At the gem boundary: map `BigDecimal` **dollars → integer cents** via `Money.cents` (and leave `apy_earned` as a rate).
4. Compute transaction **checksums** with Step 1 helpers; **skip** rows whose checksum already exists in the DB; **allow** duplicate lines within a single import file.
5. Persist parent statement + new transactions in **one DB transaction**; attach the source file when an upload/io is provided.
6. Surface **flash-friendly errors** (unsupported extension, blank file, gem `ArgumentError` / missing file).
7. Cover behavior with **Minitest** using tmpdir **CSV fixtures** (no committed PDFs in-repo) plus **real PDF smoke tests** against local Documents samples (see below).

### Real PDF fixtures (local only — names only, not committed)

Integration/smoke tests use these files when present on disk under the developer’s Documents folder:

| Importer | Filename |
|----------|----------|
| `AccountStatements::Importer` | `BoA_Savings_Jan_2026.pdf` |
| `CreditCardStatements::Importer` | `BoA_CC_YearEndSummary_2025.pdf` |

Resolved path pattern: `/Users/todd/Documents/<filename>` (or `ENV["HOME"]/Documents/<filename>`). Tests **skip** if the file is missing. Do **not** commit PDF contents or binary fixtures into the repo.
### Depends on Step 1

| Prerequisite | Why |
|--------------|-----|
| `AccountStatement` / `AccountTransaction` / CC models | Persistence targets |
| `*_cents` columns + `checksum` | Storage shape |
| `Money.cents` / `Money.dollars` | Gem boundary conversion |
| `AccountTransaction.checksum_for` / `CreditCardTransaction.checksum_for` | Dedupe fingerprint |
| Active Storage on statements | `source_file` attach |

### Explicitly out of Step 2

| Deferred to | Work |
|-------------|------|
| Step 3 | Routes, controllers, multipart upload forms, summary HTML, flash rendering |
| Step 4 | Transaction filter UI / Stimulus |
| Step 5+ | Layout, browser E2E, upload size limits, background jobs |
| Never (v1) | Editing txns, recategorization, statement-level file checksum reject |

---

## Planned deliverables

### Services

```
app/services/account_statements/importer.rb
app/services/credit_card_statements/importer.rb
```

Optional shared helpers (only if duplication hurts):

```
app/services/imports/tempfile_for.rb          # blob/io → path for gem filename:
app/services/imports/error.rb                 # ImportError with message
app/services/imports/result.rb                # statement, imported_count, skipped_duplicate_count
```

Suggested public API (either keyword style is fine; pick one and use consistently):

```ruby
AccountStatements::Importer.call(uploaded_file:)
# or
AccountStatements::Importer.call(io:, filename:)
```

`uploaded_file` should accept what Step 3 will pass (e.g. `ActionDispatch::Http::UploadedFile` or an Active Storage attachable). Tests can pass a `File` / `Tempfile` plus original filename.

### Branching by extension

| Extension | Account importer | Credit card importer |
|-----------|------------------|----------------------|
| `.pdf` | `BankAccountStatement::Extractor` | `CCYearEndStatement::Extractor` |
| `.csv` | `BankAccountStatement::CSVExtractor` | `CCYearEndStatement::CSVExtractor` |
| other / blank | raise `Imports::Error` (or equivalent) | same |

Case-insensitive extension; decide whether `.CSV` / path with query junk is normalized via `File.extname(filename).downcase`.

Gems require a **filesystem path** (`filename:`). Importers must write a tempfile (or use `uploaded_file.path` when already on disk), call the gem, then clean up.

### Account statement mapping

From gem `Result` → `AccountStatement`:

| Gem field | AR attribute | Notes |
|-----------|--------------|--------|
| — | `source_filename` | basename of upload |
| — | `import_format` | `"pdf"` or `"csv"` |
| `page_count` | `page_count` | nil on CSV |
| `account_name` | `account_name` | nil on CSV |
| `account_number` | `account_number` | nil on CSV |
| `period_start` / `period_end` | same | nil on CSV |
| `summary.beginning_balance` etc. | `beginning_balance_cents` etc. | via `Money.cents`; nil-safe |
| `summary.apy_earned` | `apy_earned` | **not** cents |
| each `result.transactions` | `AccountTransaction` | see below |

Per transaction:

| Gem field | AR |
|-----------|-----|
| `date` | `date` |
| `description` | `description` |
| `section` | `section` |
| `amount` (BigDecimal $) | `amount_cents` via `Money.cents` |
| computed | `checksum` via `AccountTransaction.checksum_for(...)` |

### Credit card statement mapping

| Gem / derived | AR attribute | Notes |
|---------------|--------------|--------|
| — | `source_filename`, `import_format` | as above |
| `page_count` | `page_count` | nil on CSV |
| year of **latest** transaction date | `statement_year` | document in code; nil if no txns |
| sum of category totals (preferred) or txn amounts | `total_spend_cents` | convert category `total` via `Money.cents` then sum; define whether credits reduce total (gem credits are negative — summing amounts is correct) |

Per transaction: `date`, `description`, `location`, `category`, `subcategory`, `amount` → `amount_cents`, `checksum`.

### Checksum skip algorithm (required)

1. Before inserting, load existing checksums for **that** transactions table into a Ruby `Set`  
   e.g. `AccountTransaction.distinct.pluck(:checksum)` (personal scale OK).
2. For each gem transaction **in file order**:
   - cents + checksum
   - if checksum ∈ **pre-import** Set → skip (`skipped_duplicate_count += 1`)
   - else insert (`imported_count += 1`)
   - **do not** add the new checksum to the Set during this run  
     → second identical line in the same file still inserts
3. Always create the parent statement (even if every txn is skipped).
4. Entire create/attach/insert runs inside `ActiveRecord::Base.transaction` so failures roll back.

### Result object

Return something Step 3 can use without digging into AR:

```ruby
# example shape
Imports::Result.new(
  statement:,                 # AccountStatement or CreditCardStatement
  imported_count:,            # Integer
  skipped_duplicate_count:    # Integer
)
```

### Errors

Raise a single app-level error type (e.g. `Imports::Error`) with a safe message for flash, wrapping or replacing:

- unsupported extension
- blank/missing filename
- gem `ArgumentError`
- `Errno::ENOENT`
- unexpected parse failures worth catching (avoid swallowing programming bugs)

Do not leave partial statements on failure (DB transaction).

### Tests (Minitest)

| Case | Expectation |
|------|-------------|
| Account CSV import | Statement with nil account/period/summary; N txns; cents match; checksums set |
| Account CSV with two identical lines | Two DB rows, same checksum, `imported_count == 2` |
| Re-import same account CSV | New statement row OK; `imported_count == 0` (or only novel rows); `skipped_duplicate_count` > 0 |
| CC CSV import | `statement_year`, `total_spend_cents`, categorized txns |
| CC intra-file dupes / re-import | Same rules as account |
| Bad extension | Raises; no rows |
| Money | Gem `12.34` → `amount_cents` `1234` |
| Optional PDF | Skip unless `/Users/todd/Documents/BoA_*.pdf` exists |

Use tmpdir + pipe-delimited CSV matching gem writer headers (`date|section|description|amount` and CC headers). Prefer injecting or calling real `CSVExtractor` against written files.

### Naming reminder (from Step 1)

| Constant | Role |
|----------|------|
| `BankAccountStatement::*` | **Gem only** — never an AR class |
| `BankStatement` | Rails **application** module |
| `AccountStatement` / `AccountTransaction` | **AR** persistence for bank/account statements |
| `CCYearEndStatement::*` | Gem |
| `CreditCardStatement` / `CreditCardTransaction` | AR |

Importer namespaces: `AccountStatements::Importer`, `CreditCardStatements::Importer`.

---

## Acceptance checklist (Step 2)

- [x] Both importers call the correct gem class by extension
- [x] All money from gems stored as `*_cents` (except `apy_earned`)
- [x] Pre-import checksum Set skip works; intra-file duplicates still insert
- [x] Parent statement created even when all txns skipped
- [x] Result exposes `imported_count` / `skipped_duplicate_count`
- [x] Failures raise flash-friendly errors and roll back
- [x] Source file attached when import is given a path or io
- [x] CSV service tests green; PDF smoke tests use Documents samples (skip if missing)
- [x] Still **no** routes/controllers/views

---

## What shipped

### Services

| File | Role |
|------|------|
| `app/services/imports/error.rb` | `Imports::Error` |
| `app/services/imports/result.rb` | `Imports::Result` (`statement`, `imported_count`, `skipped_duplicate_count`) |
| `app/services/imports/source_file.rb` | Path/io normalization, extension → `pdf`/`csv`, Active Storage attach |
| `app/services/account_statements/importer.rb` | Bank gem → `AccountStatement` / `AccountTransaction` |
| `app/services/credit_card_statements/importer.rb` | CC gem → `CreditCardStatement` / `CreditCardTransaction` |

### API

```ruby
AccountStatements::Importer.call(path: "/path/to/file.pdf")
AccountStatements::Importer.call(io: file, filename: "file.csv")
CreditCardStatements::Importer.call(path: "...")
```

### Tests

- `test/services/account_statements/importer_test.rb` — CSV cents/checksum/dupes/re-import; PDF `BoA_Savings_Jan_2026.pdf`
- `test/services/credit_card_statements/importer_test.rb` — CSV year/spend/dupes/re-import; PDF `BoA_CC_YearEndSummary_2025.pdf`

### Changes along the way

1. **Active Storage `closed stream`** — attaching with `File.open { }` closed the handle before Active Storage finished reading. Fixed by attaching `StringIO.new(File.binread(path))`.
2. **PDF fixtures named in this SPEC** — local Documents filenames only; binaries not in repo; tests skip if absent.
3. **CC `total_spend_cents`** — prefers sum of gem category totals (cents); falls back to sum of imported txn cents if no categories.

---

## Areas of concern

### Gem vs AR naming (high confusion risk)

Importers are the first code that touches **both** `BankAccountStatement::Extractor` and `AccountStatement`. Easy to mistype constants or put gem objects in the DB. Keep an explicit mapping layer (private methods like `build_account_transaction(gem_txn)`) and never pass gem `Data` objects into `create!`.

### Tempfiles and the gem `filename:` API

Gems want a path on disk. Pitfalls:

- Uploaded file path may disappear after the request (less relevant until Step 3, but design for it now)
- Must use a suffix that preserves `.pdf` / `.csv` so extension detection and any gem sniffing work
- Ensure tempfile is flushed before `Extractor.call`
- Ensure unlink in `ensure` even when the gem raises

### CSV imports create “hollow” account statements

Bank CSV extractors intentionally leave account/period/summary **nil**. Importers must not invent metadata. Step 3 UI must tolerate sparse summaries; otherwise users will think import failed. Consider setting only what the gem provides and documenting “PDF preferred for full summary” in UI later.

### Statement row always created on re-import

Re-importing the same file creates a **new** `AccountStatement` / `CreditCardStatement` even when every txn is skipped. That matches SPEC (txn-level dedupe, not file-level). Concern: statement index will fill with empty/near-empty re-imports. Mitigations deferred: statement-level source checksum, or refuse create when `imported_count.zero?` — **not** in Step 2 unless we explicitly change SPEC. Call this out in Step 3 UX (show skipped counts).

### Checksum false skips across accounts

Payload omits account number. Identical lines on two accounts collide. Personal use: low risk. If it happens, fix by extending payload (and backfilling checksums) — a breaking change.

### Intra-file vs cross-import semantics are easy to implement wrong

Wrong implementations to avoid:

1. Adding each new checksum to the Set mid-run → incorrectly collapses intra-file dupes  
2. Unique DB index on checksum → same bug at the database  
3. Scoping “existing” only to the new statement → never skips on re-import  
4. Skipping based on statement filename → not what SPEC asks for  

Tests must lock (1) and (3) especially.

### `total_spend_cents` and `statement_year` heuristics

- Year of **latest** txn can disagree with the PDF title year if dates span boundaries  
- Summing category totals vs summing txn amounts can diverge if gem category totals and lines disagree  
- Prefer category totals when `result.categories` is present; document fallback  
- Empty transaction list: `statement_year` nil, `total_spend_cents` 0 or nil — pick one and test it

### Transactional attach + bulk insert performance

Wrapping everything in one AR transaction is correct for atomicity. Large year-end PDFs may insert thousands of rows synchronously — fine for v1 personal use; request timeouts become Step 3/6 concerns (background job follow-on in parent SPEC risks).

### Error wrapping vs bug swallowing

Rescue gem/`Errno`/`ArgumentError` for user-facing import failures. Do **not** rescue `StandardError` broadly or validation errors will look like “import failed” without fixing the mapper.

### Active Storage attach timing

Attach inside the same DB transaction as the statement create when possible so a failed txn insert does not leave an orphan statement with a file. Confirm Active Storage attachment records roll back with the statement on SQLite.

### Dual CSV delimiter reality

Gems default to pipe `|` and can sniff commas. Tests should use the same format the gem writers emit. If a user uploads a random spreadsheet CSV, gem header validation may fail — map that to a clear `Imports::Error` message.

### Security (acknowledged, not Step 2 scope)

Still no auth, size limits, or PDF sandboxing. Step 2 will execute parsers on attacker-controlled files once Step 3 exposes upload. Do not treat Step 2 completion as “safe to deploy.”

### What success looks like before Step 3

From console or a runner:

```ruby
result = AccountStatements::Importer.call(...)
result.imported_count
result.skipped_duplicate_count
result.statement.account_transactions.count
```

Re-running the same CSV increases statement count by 1 and txn count by 0 (if nothing new).

---

## Key files to add (Step 2)

```
app/services/account_statements/importer.rb
app/services/credit_card_statements/importer.rb
app/services/imports/*                    # optional shared error/result/tempfile
test/services/account_statements/importer_test.rb
test/services/credit_card_statements/importer_test.rb
SPEC_STEP_2.md                            # this file
```

---

## Implementation notes when coding starts

1. Prefer real `CSVExtractor` over stubbing gem internals — characterizes actual delimiter/header behavior.  
2. Keep mapping methods tiny and table-driven where possible.  
3. Update this file’s Status to **Complete** and add a “What shipped / changes along the way” section after implementation (same pattern as `SPEC_STEP_1.md`).
