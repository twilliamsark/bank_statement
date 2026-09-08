# SPEC — Step 1: Active Storage, Schema, Models, Money & Checksums

Parent document: [`SPEC.md`](./SPEC.md)

Status: **Complete** (as of implementation; 22 related tests green)

---

## What Step 1 is

Step 1 builds the **persistable domain only**. No importers, routes, controllers, views, or Stimulus filters.

### Goals

1. Install **Active Storage** so statements can later attach uploaded PDF/CSV files.
2. Create **four domain tables** for bank (account) statements/transactions and credit-card statements/transactions.
3. Persist **all dollar amounts as signed integer cents** (`*_cents`), with a shared conversion helper at the gem/UI boundary.
4. Add a **`checksum`** column on each transaction row (non-unique index) plus `checksum_for` helpers so Step 2 can skip already-stored transactions while still allowing duplicate lines inside a single import file.
5. Ship **ActiveRecord models**, validations, associations, and **Minitest** coverage for associations, money round-trip, and checksum behavior.

### Explicitly out of Step 1

| Deferred to | Work |
|-------------|------|
| Step 2 | Importers; gem extractors; skip-already-stored checksum algorithm; imported/skipped counts |
| Step 3 | Routes, controllers, upload UI, summary pages |
| Step 4 | Transaction index + live filters |
| Step 5+ | Layout polish, browser verification, suite cleanup |

---

## What shipped

### Migrations

| Migration | Purpose |
|-----------|---------|
| `*_create_active_storage_tables.active_storage.rb` | Blobs, attachments, variants |
| `*_create_bank_account_statements.rb` | Original create (later renamed) |
| `*_create_bank_account_transactions.rb` | Original create (later renamed) |
| `*_create_credit_card_statements.rb` | CC statement table |
| `*_create_credit_card_transactions.rb` | CC transaction table |
| `*_rename_bank_account_tables_to_account_tables.rb` | Rename bank tables + FK to `account_*` |

### Final schema (bank / account side)

**`account_statements`**

- Metadata: `account_name`, `account_number`, `period_start`, `period_end`, `page_count`, `source_filename`, `import_format`
- Money (integer cents): `beginning_balance_cents`, `deposits_cents`, `withdrawals_cents`, `checks_cents`, `service_fees_cents`, `ending_balance_cents`, `interest_paid_ytd_cents`
- Rate (not cents): `apy_earned` `decimal(8,4)`
- Indexes: `[period_start, period_end]`, `account_number`

**`account_transactions`**

- `account_statement_id` (FK, required)
- `date`, `description`, `section`, `amount_cents`, `checksum` (all required)
- Indexes: `date`, `section`, `description`, `checksum` (**non-unique**)

### Final schema (credit card side)

**`credit_card_statements`**

- `statement_year`, `page_count`, `source_filename`, `import_format`, `total_spend_cents`
- Index: `statement_year`

**`credit_card_transactions`**

- `credit_card_statement_id` (FK)
- `date`, `description`, `location` (default `""`), `amount_cents`, `category`, `subcategory`, `checksum`
- Indexes: `date`, `category`, `subcategory`, `description`, `checksum` (**non-unique**)

### Models

| Class | Table | Notes |
|-------|-------|--------|
| `AccountStatement` | `account_statements` | `has_one_attached :source_file`; `has_many :account_transactions, dependent: :destroy` |
| `AccountTransaction` | `account_transactions` | `belongs_to :account_statement`; `checksum_for`; auto-assign checksum if blank |
| `CreditCardStatement` | `credit_card_statements` | Same attachment / destroy pattern |
| `CreditCardTransaction` | `credit_card_transactions` | `checksum_for` includes location; blank location allowed |

### Money helper

`lib/money.rb` (autoloaded via `config.autoload_lib`):

- `Money.cents(dollars) → Integer` — `BigDecimal` dollars → cents, `ROUND_HALF_UP`
- `Money.dollars(cents) → BigDecimal` — cents → dollars
- `nil` in → `nil` out

Intended use: convert **at the gem boundary** (Step 2) and for display (Step 3+). Models store integers only.

### Checksum helpers (ready for Step 2; skip logic not implemented yet)

Canonical payload → SHA-256 hex:

- **Account:** `date|section|description|amount_cents` (ISO date)
- **Credit card:** `date|category|subcategory|description|location|amount_cents`

Rules already encoded in schema/tests:

- **No UNIQUE constraint** on `checksum` — intra-file duplicate lines may share a checksum and all be stored
- Models may auto-fill `checksum` when blank; importers should still compute explicitly for clarity

### Tests

- `test/lib/money_test.rb`
- `test/models/account_statement_test.rb`
- `test/models/account_transaction_test.rb`
- `test/models/credit_card_statement_test.rb`
- `test/models/credit_card_transaction_test.rb`

Coverage includes: associations + dependent destroy, Active Storage attach, validations, checksum stability/sensitivity, multiple rows with the same checksum, money round-trip.

Also removed empty leftover `app/services/year_end_statements/`.

---

## Changes made along the way

These diverged from the first draft of `SPEC.md` during Step 1 implementation. Parent `SPEC.md` was updated to match.

### 1. Cents and checksums pulled into Step 1 (by design)

Originally Step 1 was “Active Storage + migrations + models.” Two mid/long-term recommendations were adopted into v1 and folded into Steps 1–2:

- Store money as **integer cents**
- Store a **transaction checksum** for cross-import dedupe (allowing intra-import duplicates)

Step 1 owns columns, indexes, `Money`, and `checksum_for`. Step 2 owns the import skip algorithm.

### 2. ActiveRecord naming collisions (forced rename)

Planned AR name `BankAccountStatement` **collides with the gem module** `BankAccountStatement`.

Attempted rename to `BankStatement` / `BankTransaction` **collides with the Rails application module** `BankStatement` (`config/application.rb`).

**Settled names:**

| Layer | Name |
|-------|------|
| Gem (parsing) | `BankAccountStatement::*` |
| Rails app module | `BankStatement` |
| AR models (bank) | `AccountStatement` / `AccountTransaction` |
| AR models (CC) | `CreditCardStatement` / `CreditCardTransaction` (no clash with `CCYearEndStatement`) |

### 3. Table rename to match AR models

Tables were first created as `bank_account_statements` / `bank_account_transactions` (SPEC-aligned with gem wording). After settling on `AccountStatement` / `AccountTransaction`, tables and FK were renamed:

- `bank_account_statements` → `account_statements`
- `bank_account_transactions` → `account_transactions`
- `bank_account_statement_id` → `account_statement_id`

Models no longer need `self.table_name` or explicit `foreign_key:` overrides.

Historical create migrations still use the old table names; the follow-up rename migration brings the DB to the final shape. Fresh `db:migrate` from zero is fine (create then rename).

### 4. Route/service naming in SPEC nudged toward `account_statements`

SPEC routes/services examples were updated from `bank_account_statements` toward `account_statements` / `AccountStatements::Importer` so URLs and namespaces track the AR models. Step 3 should follow that unless a deliberate public URL preference says otherwise.

### 5. `apy_earned` left as decimal

Not all “numeric statement fields” are money. APY is a **percentage rate**, stored as `decimal(8,4)`, not cents.

---

## Areas of concern

### Naming cognitive load

Three different “bank statement” identities exist:

1. Gem: `BankAccountStatement`
2. App: `BankStatement::Application`
3. Persistence: `AccountStatement`

New contributors (and future Step 2 importers) must map carefully: **gem Result → `AccountStatement` / `AccountTransaction`**. Consider a short comment at the top of the Step 2 importer and avoiding `BankAccount*` as an AR or controller name.

### Migration history is slightly awkward

Create migrations still say `create_table :bank_account_statements` then a rename runs. That is correct for already-migrated DBs but noisy for readers. Optional cleanup later: squash/replace creates to use `account_*` directly and reset local DBs (only safe while there is no precious data).

### Checksum collision / scope

Checksums omit account number and statement id (by SPEC). Two different accounts with an identical date/section/description/amount would share a checksum; a later import could skip a legitimately new row. Acceptable for a single-household app; revisit if multi-account false skips appear.

Checksums also do not version the algorithm. Changing the payload format later requires a backfill or dual-read strategy.

### Checksum not unique ≠ “dedupe done”

Step 1 only **stores** checksums. Without Step 2’s pre-import Set + skip logic, re-creating rows in console/tests will happily insert duplicates. Do not assume the DB enforces cross-import idempotency.

### Money rounding

`Money.cents` uses half-up at the cent. Gem amounts are expected to be 2 decimal places already; pathological third decimals are rounded. Tests document `0.125` → `13` cents. If a gem ever emits more precision, confirm product expectation.

### SQLite index on `description` (text)

Filter-oriented indexes on `description` are fine at personal scale on SQLite; they are not a substitute for a dedicated search engine if the corpus grows large.

### Active Storage without upload limits

Attachments work; Step 1 adds no file size/type caps. Those remain a follow-on security item before any non-local deploy (see `SPEC.md` risks).

### `import_format` validation vs nullability

Models allow `nil` `import_format` but only `pdf`/`csv` when present. Importers (Step 2) should always set it; incomplete console-created rows may omit it.

### Dependent destroy + attachments

Destroying a statement destroys transactions; Active Storage purge behavior should be verified in Step 3 destroy flows (purge vs orphan blobs).

### What Step 2 must not forget

1. Convert gem `BigDecimal` dollars → `*_cents` via `Money.cents`
2. Load **pre-import** checksum Set; skip hits; **do not** add new checksums to the Set mid-run
3. Return `imported_count` / `skipped_duplicate_count`
4. Keep parsing in gems; map explicitly into `Account*` / `CreditCard*` attributes (anti-corruption layer)

---

## Acceptance checklist (Step 1)

- [x] Active Storage installed and migrated
- [x] Four domain tables exist with cents columns and non-unique checksum indexes
- [x] Tables named `account_statements` / `account_transactions` (plus credit_card_*)
- [x] `Money.cents` / `Money.dollars` available
- [x] Models validate, associate, attach files, auto-checksum when blank
- [x] Same checksum allowed on multiple transaction rows
- [x] Model + money tests green
- [x] No importers/UI (correctly deferred)

---

## Key files

```
db/migrate/*_create_active_storage_tables.active_storage.rb
db/migrate/*_create_bank_account_statements.rb
db/migrate/*_create_bank_account_transactions.rb
db/migrate/*_create_credit_card_statements.rb
db/migrate/*_create_credit_card_transactions.rb
db/migrate/*_rename_bank_account_tables_to_account_tables.rb
db/schema.rb
lib/money.rb
app/models/account_statement.rb
app/models/account_transaction.rb
app/models/credit_card_statement.rb
app/models/credit_card_transaction.rb
test/lib/money_test.rb
test/models/account_*_test.rb
test/models/credit_card_*_test.rb
SPEC.md                    # parent; updated for naming/cents/checksums
SPEC_STEP_1.md             # this file
```
