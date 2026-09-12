# SPEC — Step 8.1: UnreconciledTransaction + Monthly Import UI

Parent: [`SPEC_STEP_8.md`](./SPEC_STEP_8.md) (overall Step 8 design)  
Next: [`SPEC_STEP_8.2.md`](./SPEC_STEP_8.2.md) (Auto Reconcile)  
Related: [`SPEC_STEP_8.5.md`](./SPEC_STEP_8.5.md) (monthly statement list + summary page)

Status: **Complete**

---

## Goal

Introduce staging for monthly credit-card statement rows:

1. Create the **`UnreconciledTransaction`** model (and the **`MonthlyCreditCardStatement`** parent it belongs to), including an **`import_fingerprint`** column on each staging row.
2. Add an **Import Monthly Statement** flow that extracts PDF/CSV via `CCAccountStatement` and creates `UnreconciledTransaction` rows **with blank `category` / `subcategory`** and a computed fingerprint.
3. Show an **Unreconciled Transactions** UI that lists those rows and includes an import statement button.

**Out of this chunk:** Auto-fill of category/subcategory (Step 8.2), commit into `CreditCardTransaction`, dependent dropdowns for manual reconcile, XOR parent FK changes on `CreditCardTransaction`.

---

## Decisions for 8.1

| Topic | Decision |
| ----- | -------- |
| Staging model name | `UnreconciledTransaction` / `unreconciled_transactions` |
| Monthly parent | `MonthlyCreditCardStatement` / `monthly_credit_card_statements` |
| Categories on import | Always **null** — do not auto-match in 8.1 |
| `import_fingerprint` on staging | **Yes** — store at import; do **not** dedupe yet |
| Fingerprint prefix length | `description[0, 21]` (align app helper + backfill year-end rows if changed) |
| Gem extractors | `.pdf` → `CCAccountStatement::Extractor`; `.csv` → `CCAccountStatement::CSVExtractor` |
| Date field | `date` ← gem `transaction_date` |
| Amount | Persist as signed integer cents via existing `Money` helper |

---

## Data model

### 1. `monthly_credit_card_statements` (new)

Minimal parent so staging rows have a home and the import has somewhere to attach the file.

| Column | Type | Notes |
| ------ | ---- | ----- |
| `credit_card_account_id` | fk | required |
| `period_start` | date | nullable (CSV) |
| `period_end` | date | nullable (CSV) |
| `account_name` | string | nullable |
| `account_number` | string | nullable |
| `page_count` | integer | nullable |
| `source_filename` | string | original upload basename |
| `import_format` | string | `pdf` / `csv` |
| timestamps | | |

- `has_one_attached :source_file`
- `belongs_to :credit_card_account`
- `has_many :unreconciled_transactions, dependent: :destroy`

`CreditCardAccount` gains `has_many :monthly_credit_card_statements`.

Core summary cents columns from the gem are **deferred to Step 8.5** (summary `#show`). 8.1 only needs enough parent columns for import + staging.

### 2. `unreconciled_transactions` (new)

| Column | Type | Notes |
| ------ | ---- | ----- |
| `monthly_credit_card_statement_id` | fk | required |
| `date` | date | from `transaction_date`; required |
| `description` | text | required |
| `amount_cents` | integer | required; signed cents |
| `category` | string | **nullable** (blank after import in 8.1) |
| `subcategory` | string | **nullable** (blank after import in 8.1) |
| `import_fingerprint` | string | required on create; see below |
| timestamps | | |

Indexes: `monthly_credit_card_statement_id`; optional `[amount_cents]` for later match lookups in 8.2; optional non-unique index on `import_fingerprint`.

**`import_fingerprint` (required in 8.1):**

- Persist on every staging row at import time.
- Algorithm matches the app helper (align to **21-char** prefix while doing this):

```ruby
MD5("#{date}|#{description.to_s[0, 21]}|#{amount_cents}")
```

- Prefer a shared helper (e.g. `CreditCardTransaction.import_fingerprint_for` fixed to `[0, 21]`, or a concern used by both models).
- **Do not** use it to skip duplicate staging rows or commits in 8.1 — storage only; dedupe is a later step.
- If fixing `CreditCardTransaction.import_fingerprint_for` from `[..21]` → `[0, 21]`, **backfill** existing year-end `credit_card_transactions.import_fingerprint` values in the same migration/data fix.

**Not in 8.1 schema (defer):** `posting_date`, `reference_number`, `section`, `reconciled`, `match_source`. Keep the staging table to the columns listed above unless a later chunk needs extras.

Validations:

- Presence: `date`, `description`, `amount_cents`, `monthly_credit_card_statement`, `import_fingerprint`
- `category` / `subcategory` may be blank
- Assign `import_fingerprint` in a `before_validation` (when blank) from date/description/amount_cents
---

## Import service

### `MonthlyCreditCardStatements::Importer`

Mirror the shape of `CreditCardStatements::Importer`:

1. Resolve `CreditCardAccount` (existing or create-from-name), same UX pattern as year-end.
2. Extract via gem by file extension.
3. In one DB transaction:
   - Create `MonthlyCreditCardStatement` + attach source file.
   - For each gem transaction → create `UnreconciledTransaction` with:
     - `date` = `transaction_date`
     - `description`
     - `amount_cents` (via `Money.cents`)
     - `import_fingerprint` assigned (model callback or explicit helper call)
     - `category` / `subcategory` left **nil**
4. Return result: `statement`, `staged_count` (no `CreditCardTransaction` creation).

**Do not** run category matching in this importer (that is Step 8.2).  
**Do not** skip staging creates when an `import_fingerprint` already exists (dedupe later).

---

## Routes & UI

### Rename / CTAs on credit card accounts

On `credit_card_accounts#index` (and empty state as appropriate):

- Existing primary import CTA → **Import Year End Statement** (same `new_credit_card_statement_path`)
- Add **Import Monthly Statement** → `new_monthly_credit_card_statement_path`

### Resources (8.1 minimum)

```ruby
resources :monthly_credit_card_statements, only: %i[index show new create destroy] do
  resources :unreconciled_transactions, only: %i[index], module: :monthly_credit_card_statements
end
```

Exact nesting can be adjusted; required behavior:

1. **Import Monthly Statement (`#new` / `#create`)** — account picker + `.pdf,.csv` upload; on success redirect to the unreconciled list for that statement.
2. **Unreconciled Transactions list** — for a monthly statement:
   - Header: card name, period (if present), filename, row count
   - **Import statement** affordance visible (link/button back to monthly import, and/or the accounts-page CTA already renamed)
   - Table columns: **date**, **description**, **amount**, **category**, **subcategory**
   - After a fresh import, category and subcategory cells are **blank**

Nav: extend `nav_section_active?` so monthly routes keep “Credit cards” highlighted.

---

## Explicitly out of Step 8.1

| Out | Notes |
| --- | ----- |
| Auto Reconcile / category match algorithm | Step 8.2 |
| Manual category/subcategory dropdowns + PATCH | Later chunk |
| Commit reconciled rows → `CreditCardTransaction` | Later chunk |
| Making `credit_card_statement_id` nullable / monthly FK on final txns | Later chunk |
| Monthly statement index/summary `#show` polish | Step 8.5 |
| `import_fingerprint` **potential-duplicate** flagging | Step 8.6 (column itself **is** in 8.1; 8.1 stores only) |
| Free-text categories | Out of Step 8 |

---

## Tests (minimum)

- Migration / model: `UnreconciledTransaction` belongs to monthly statement; category/subcategory optional; `import_fingerprint` present
- Fingerprint helper uses `description[0, 21]` (not `[..21]`); staging row fingerprint matches that helper
- Importer: PDF or CSV (fixture or gem-shaped stub) creates `MonthlyCreditCardStatement` + N `UnreconciledTransaction` rows with nil category/subcategory and non-blank `import_fingerprint`
- Integration: accounts index shows **Import Year End Statement** and **Import Monthly Statement**
- Integration: successful monthly create redirects to unreconciled list; blank category/subcategory columns rendered

---

## Suggested implementation order

1. Migrations: `monthly_credit_card_statements`, `unreconciled_transactions` (incl. `import_fingerprint`); fingerprint helper fix + year-end backfill if needed
2. Models + associations on `CreditCardAccount`
3. `MonthlyCreditCardStatements::Importer`
4. Controllers/routes/views: rename year-end CTA, monthly new/create, unreconciled index
5. Tests

---

## Done when

- User can import a monthly PDF/CSV for a credit card account
- Staging rows exist as `UnreconciledTransaction` with date / description / amount / `import_fingerprint` and empty category + subcategory
- UI lists those rows and exposes an import statement entry point
- No auto-categorization has run yet
- Fingerprints are stored but **not** used for dedupe yet
