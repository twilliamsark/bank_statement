# SPEC — Step 4.6: Account-Level Summary Detail

Parent document: [`SPEC.md`](./SPEC.md)  
Statement-level parallel: [`SPEC_STEP_3.md`](./SPEC_STEP_3.md) (`AccountStatementsController#show`)  
Account identity / master txns: [`SPEC_STEP_4_5.md`](./SPEC_STEP_4_5.md) (`AccountSummary`, `/accounts`)

Status: **Complete** (persisted Account + summary show green)

---

## Placement

Numbered **4.6** because it builds on Step **4.5** (accounts index + master transactions). It also **upgrades bank account identity** from derived `AccountSummary` groups to **persisted `Account` rows** with an FK on statements — using the importer’s `account_name` as the find-or-create key — then adds the summary show page on top.

Suggested order:

1. … Steps 1–3, 4, **4.5** (done)  
2. **4.6** — persist `Account` + FK + summary show (+ retarget 4.5 routes to real records)  
3. Steps 4.7–4.9, 5–7  

---

## What Step 4.6 is

Two tightly related outcomes:

### A. Persist bank accounts (identity upgrade)

Stop treating accounts as ephemeral groups of `account_number`. Introduce a real **`accounts`** table. On each **bank** import (PDF path that supplies metadata):

1. Read `account_name` from the gem result.  
2. **Find or create** an `Account` by that name (normalized; see rules).  
3. A **new** name never seen before → **new** `Account`.  
4. Set `account_statement.account_id` FK so all statements for that logical account belong to one row.

This mirrors the spirit of CC **4.7** (FK to an account), except the bank name is **supplied by the importer/gem**, not typed by the user at upload time.

Also store `account_number` on `Account` when the gem provides it (update if currently blank; do not key uniqueness primarily on number — **name is the identity key** per product decision).

### B. Account summary show page

Add **`GET /accounts/:id`** with the same *kind* of detail as statement show, rolled up across statements for that persisted account:

| Statement show (Step 3) | Account show (Step 4.6) |
|-------------------------|-------------------------|
| Account name / number / period / pages | Persisted name / number / period **coverage** / statement count |
| Balance table from one PDF summary | **Aggregated** balances (rules below) |
| Section totals for one statement | Section totals across **all** account transactions |
| Link to statement transactions | Link to **master** account transactions (4.5, retargeted to `account_id`) |
| Destroy statement | Destroy account only with clear policy (prefer **restrict** while statements exist) |

### Goals

1. Migration: `accounts` (`name` required unique, `account_number` optional); `account_statements.account_id` FK.  
2. Find-or-create `Account` inside `AccountStatements::Importer` from gem `account_name` (PDF).  
3. Backfill existing statements into `Account` rows; replace `AccountSummary` / `Accounts::Id` URL tokens with integer `Account` ids where practical.  
4. Retarget `/accounts` index + master transactions to `Account`.  
5. Add `AccountsController#show` summary UI (balances, section totals, member statements).  
6. CSV / nil-`account_name` policy (below).  
7. Tests: new name → new account; same name → reuse; rollups; backfill.

### Depends on

| Prerequisite | Why |
|--------------|-----|
| Step 2–3 | Importer + statement show template |
| Step 4.5 | Accounts UI + master txn patterns to retarget |

### Explicitly out of Step 4.6

| Out | Notes |
|-----|--------|
| User picking bank account on upload | Name comes from gem; not a dropdown like CC 4.7 |
| Editing balances | Read-only rollups |
| Credit-card account summary | Steps **4.7–4.9** |
| Merging two accounts after a name typo/drift | Manual ops / later admin |
| Inventing names for CSV with nil `account_name` | No silent fake accounts (see CSV policy) |

---

## Planned deliverables

### Data model

**`accounts`**

| Column | Type | Notes |
|--------|------|-------|
| `name` | string | required; **unique** (case-insensitive / normalized) — find-or-create key from gem `account_name` |
| `account_number` | string | optional; filled from gem when present |
| timestamps | | |

**`account_statements`**

| Column | Type | Notes |
|--------|------|-------|
| `account_id` | fk | nullable only for legacy CSV-without-name; PDF imports set always |

```ruby
# Account
has_many :account_statements, dependent: :restrict_with_error
has_many :account_transactions, through: :account_statements

# AccountStatement
belongs_to :account, optional: true  # optional only if CSV policy allows nil
```

### Find-or-create rules (importer)

1. After gem extract, if `account_name` present (normalized strip; recommend case-insensitive match):  
   `Account.find_or_create_by_normalized_name!(name)`  
2. If gem `account_number` present and account’s number blank → set it; if both present and differ, **keep existing number** and optionally log (do not split accounts on number alone).  
3. Assign `statement.account = account` in the same DB transaction as persist.  
4. **New distinct name** on a later import → **new** `Account` (by design).

### CSV / missing name

Gem CSV extract leaves `account_name` / `account_number` nil. Policy:

- **Do not** auto-create an account named `"Unknown"`.  
- Leave `account_id` nil; statement remains on `/account_statements` only.  
- Accounts index note: statements without an account (typical CSV) are not listed — same spirit as 4.5’s unnumbered callout.

Optional later: let user assign a CSV statement to an account (out of scope for 4.6).

### Backfill (from current 4.5 data)

1. For each distinct normalized `account_name` among statements where name present → create `Account`.  
2. Else group by normalized `account_number` and create `Account` with `name:` derived from number or `"Account #{number}"` if name missing.  
3. Set FKs.  
4. Remove or thin `AccountSummary` / Base64 `Accounts::Id` in favor of `Account.find(params[:id])`.

### Routes

```ruby
resources :accounts, only: %i[index show] do
  resources :transactions, only: :index, module: :accounts
end
```

- `GET /accounts` → list `Account` records  
- `GET /accounts/:id` → summary  
- `GET /accounts/:account_id/transactions` → master txns (4.5 behavior, FK-scoped)  

### Controller

`AccountsController#show`:

```ruby
@account = Account.find(params[:id])
@statements = @account.account_statements.order(period_end: :desc, period_start: :desc)
@section_totals = @account.account_transactions.group(:section).sum(:amount_cents)
@balance_rollup = Accounts::BalanceRollup.call(@statements)
```

### Balance aggregation rules (required)

Statement balance fields are **period snapshots**, not additive ledger lines. Use:

| Field | Account-level rule |
|-------|--------------------|
| `beginning_balance_cents` | From the statement with the **earliest** `period_start` (tie-break: earliest `period_end`, then `id`). If that value is nil → “—” |
| `ending_balance_cents` | From the statement with the **latest** `period_end` (tie-break: latest `period_start`, then `id`). If nil → “—” |
| `deposits_cents` | **Sum** of non-nil statement `deposits_cents` |
| `withdrawals_cents` | **Sum** of non-nil `withdrawals_cents` |
| `checks_cents` | **Sum** of non-nil `checks_cents` |
| `service_fees_cents` | **Sum** of non-nil `service_fees_cents` |
| `interest_paid_ytd_cents` | From the **latest** statement only (YTD is point-in-time). Nil → “—” |
| `apy_earned` | From the **latest** statement only (rate, not cents). Nil → “—” |

Document in UI with a short muted note under Balances, e.g.  
“Beginning/ending balances are from the earliest/latest statement period; deposits and withdrawals are sums across imported statements.”

If **no** statement in the group has any non-nil balance fields (unlikely if only numbered PDFs appear on `/accounts`), show the balances table with all “—” and the same amber-style note used for CSV hollow summaries.

### Section totals

- Source of truth: **transactions**, not statement summary columns  
- `group(:section).sum(:amount_cents)` over `@account.transactions`  
- Same table UX as statement show  

### Statements list (account-only section)

Table or stacked cards:

| Column | Content |
|--------|---------|
| Period | `period_start` – `period_end` |
| Format | pdf/csv badge |
| Transactions | count |
| | Link “View statement” → `account_statement_path` |

Order: newest period first.

### Page chrome (finance-workspace)

- `page-title` = account name; subtitle = number · N statements · coverage dates  
- Stat cards: account number, period coverage, statement count (replace statement “pages”)  
- Primary button: **View transactions** → `account_transactions_path(@account)`  
- Secondary optional: none required  
- Reuse `card-pad`, `data-table`, `btn-primary`, amber callout pattern from Step 3 UI standards  

### Accounts index tweak

List persisted `Account` rows. Primary **View** → summary show; optional secondary **Transactions**.

### Tests

| Case | Expectation |
|------|-------------|
| Import PDF with new `account_name` | Creates `Account` + FK on statement |
| Second import same name (any period) | Reuses same `Account`; two statements |
| Different `account_name` | Second `Account` |
| Two statements same account, different periods | Summary earliest beginning / latest ending; summed deposits/withdrawals |
| Section totals | Sum of all txns by section for that account |
| Latest YTD / APY | From latest-period statement only |
| CSV without name | No new account; `account_id` nil |
| Index / CTA | Show + master transactions wired to `Account` id |

Use AR setup and/or importer with stubbed gem result; optional real PDF.

---

## Acceptance checklist (Step 4.6)

- [x] Persisted `Account` with unique normalized name  
- [x] Importer find-or-creates by gem `account_name`; sets statement FK  
- [x] New importer name → new account  
- [x] 4.5 index + master txns scoped via `account_id` (not only derived `AccountSummary`)  
- [x] `GET /accounts/:id` renders account summary  
- [x] Balance rollup follows the rules table  
- [x] Section totals from all account transactions  
- [x] Member statements listed with links  
- [x] Primary CTA to master transactions  
- [x] CSV-without-name policy honored  
- [x] Integration/model tests green  

---

## What shipped

- `accounts` table (`name`, `name_key`, `account_number`) + `account_statements.account_id`
- `Account.find_or_create_from_import!` used by `AccountStatements::Importer` when gem provides `account_name`
- Backfill migration for existing named/numbered statements
- `/accounts` index and master txns retargeted to persisted `Account` (removed `AccountSummary` / `Accounts::Id`)
- `/accounts/:id` summary: balance rollup, section totals, member statements, CTA to transactions
- `Accounts::BalanceRollup` with unit tests

---

## Areas of concern

### Beginning/ending are not additive

Summing `beginning_balance_cents` across months double-counts the world. The earliest/latest rule is mandatory; encode it in a dedicated `Accounts::BalanceRollup` (or `AccountSummary` methods) with unit tests so the show template stays dumb.

### Gaps in imported periods

If Jan and Mar are imported but Feb is missing, “coverage” still shows Jan–Mar and summed deposits omit February activity that was never imported. Call this out in the muted note (“based on imported statements only”).

### Mixed PDF + numbered edge cases

`/accounts` currently excludes nil `account_number`. If a future change attaches numbers to CSVs with nil balances, rollup must tolerate nils (sum skips nil; earliest/latest may be “—”).

### Interest YTD / APY semantics

YTD on a January statement vs December statement differ; showing **latest only** matches “where the account stands now” better than summing. APY is a rate—never sum.

### Overlap with statement show

Avoid large duplicated ERB: extract shared partials for balance table and section totals that accept locals (`balances:` hash/object, `section_totals:`). Statement show can be refactored to use them in the same PR if low-risk; otherwise duplicate once and note follow-up.

### Name drift from the PDF

BoA might change product wording (“Your Savings” vs “Your Advantage Savings”). **Name-as-key** then creates a second `Account` and splits history. Mitigations (optional later): manual merge; or secondary match on `account_number` when name differs. **v1 accepts split on name change** — document in UI/help if needed.

Prefer matching **normalized name** (strip, collapse spaces, case-insensitive) to reduce trivial duplicates.

### account_number vs name

Number is still valuable for display and debugging. It is **not** the primary find-or-create key in this design. If two PDFs share a number but differ in name, v1 creates two accounts (edge case — call out in tests if desired).

### Navigation regression

Accounts index should land on summary (4.6); keep **View transactions** prominent on the show page.

### Retargeting 4.5

Master txn URLs today use Base64 `Accounts::Id`. Migrating to integer `Account` ids will break bookmarks — acceptable pre-production. Remove `AccountSummary` once FK path is solid.

### Step 6

Import two PDFs for the same product name; confirm one `Account`, summary rollups, and master txns.

---

## Parent SPEC touch-ups (when implementing)

1. Keep **4.6** in Implementation order after 4.5.  
2. Under Routes & pages, add account `show` alongside accounts index / nested transactions.  

---

## Key files to add / change

```
db/migrate/*_create_accounts.rb
db/migrate/*_add_account_id_to_account_statements.rb
app/models/account.rb
app/models/account_statement.rb                 # belongs_to :account
app/services/account_statements/importer.rb     # find-or-create Account
app/services/accounts/balance_rollup.rb
app/controllers/accounts_controller.rb          # index via Account; add #show
app/controllers/accounts/transactions_controller.rb  # scope via account_id
app/views/accounts/show.html.erb
app/views/accounts/index.html.erb
config/routes.rb
test/models/account_test.rb
test/services/accounts/balance_rollup_test.rb
test/integration/account_summary_show_test.rb
test/integration/accounts_test.rb               # update for persisted Account
SPEC_STEP_4_6.md
```

---

## Implementation notes when coding starts

1. Ship `Account` + importer find-or-create + backfill before summary UI.  
2. Retarget 4.5 index/master txns to `Account`.  
3. Implement `Accounts::BalanceRollup` + `#show`.  
4. After shipping, set Status to **Complete** and add “What shipped / changes along the way.”
