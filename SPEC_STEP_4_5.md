# SPEC — Step 4.5: Master Account Transactions (Cross-Statement)

Parent document: [`SPEC.md`](./SPEC.md)  
Prior steps: [`SPEC_STEP_4.md`](./SPEC_STEP_4.md) (statement-scoped filters — **reuse**)  
Related UI: [`SPEC_STEP_3.md`](./SPEC_STEP_3.md) finance-workspace standards

Status: **Complete** (accounts index + master filters green)

---

## Placement recommendation: **4.5, not 8**

| Option | Pros | Cons |
|--------|------|------|
| **4.5 (recommended)** | Reuses Step 4 filters/Stimulus/Turbo while that code is fresh; available for Step 6 browser verification; natural product gap after per-statement lists | Inserts before layout polish (5) and verification (6) |
| **8 (after 7)** | Keeps 5–7 as originally planned; treats master view as a post-MVP add-on | Step 6 won’t exercise the feature; filter abstractions may drift before reuse; users wait longer for the most useful browse surface |

**Decision for this SPEC:** implement as **Step 4.5** — immediately after statement-scoped filters, before Step 5 polish. Steps 5–7 stay as in parent SPEC (polish → browser verify including this view → fix/suite).

If preferred later, renumber to Step 8 without changing the technical content below.

---

## What Step 4.5 is

A **master transactions view for one bank account**, aggregating `AccountTransaction` rows across **all** `AccountStatement` records that belong to that account — with the **same filter/lookahead behavior as Step 4**.

“Account” here means a logical BoA deposit account identity, **not** a single imported statement file.

### Goals

1. Define how statements group into an account (see Account identity).
2. Add routes + UI to list accounts and show cross-statement transactions for one account.
3. Reuse Step 4 filter params, `FilterableTransactions`, `live_filter_controller`, Turbo Frame pattern, and finance-workspace chrome.
4. Show enough statement context per row (or via link) so users can jump back to the source statement summary.
5. Integration tests: multi-statement fixture → master list → each filter dimension + clear.

### Depends on

| Prerequisite | Why |
|--------------|-----|
| Step 1–2 | `AccountStatement` / `AccountTransaction`, imports |
| Step 3 | App chrome, helpers, table partial patterns |
| Step 4 | Filters, Stimulus live-filter, Turbo Frame `transactions` |

### Explicitly out of Step 4.5

| Deferred / out | Work |
|----------------|------|
| Step 5+ | Non-filter layout polish |
| Later | First-class `Account` AR model/table (optional refactor if grouping gets painful) |
| Later | Master CC view (year-end statements lack a stable card identity in current schema) |
| Never (v1) | Merging/editing transactions; inventing account identity for CSV rows with nil `account_number` beyond an explicit “Unknown / CSV” bucket |

---

## Account identity

### Primary key: `account_number`

Group `AccountStatement` rows where `account_number` is present and equal (normalize lightly: strip whitespace for compare/display consistency).

| Statement field | Role on master view |
|-----------------|---------------------|
| `account_number` | **Grouping key** (required for a named account page) |
| `account_name` | Display label (prefer latest non-nil name for that number) |
| `period_start` / `period_end` | Optional subtitle (“N statements · earliest–latest period”) |

### CSV / hollow metadata

CSV imports often leave `account_number` **nil**. Options (pick one in implementation; default recommended):

1. **Recommended:** Master account index only lists groups with non-nil `account_number`. CSV-only statements remain reachable via per-statement transaction pages (Step 4). Show a short note on the accounts index: “Statements without an account number (typical CSV imports) are not listed here.”
2. **Alternative:** Single bucket “Unassigned / no account number” that unions all nil-`account_number` transactions (can mix unrelated CSVs — call out risk in UI).

PDF imports (e.g. `BoA_Savings_Jan_2026.pdf`) populate `account_number` and are the happy path for this feature.

### Routing shape (suggested)

Avoid colliding with gem/`BankStatement` naming:

```ruby
# Index of accounts (grouped by account_number)
resources :accounts, only: %i[index], param: :account_number do
  resources :transactions, only: :index, module: :accounts
end
```

`param: :account_number` needs a constrained/escaped segment (slashes/spaces in BoA numbers like `"0057 4568 7822"`). Prefer:

- **Slug or opaque id in the URL**, e.g. `accounts/:id` where `id` is `Base64.urlsafe_encode64(account_number)` or a digest, **or**
- Replace spaces with a safe token in the path and decode in the controller, **or**
- Introduce a lightweight `accounts` table later with integer id (out of scope unless grouping proves awkward).

**Recommended for 4.5:** use a **URL-safe token** derived from `account_number` (e.g. `CGI.escape` / tr spaces to `+` or use `parameterize` only if reversible—prefer explicit encode/decode helpers) and keep `account_number` as the domain key in queries.

Example paths:

- `GET /accounts` — list distinct accounts  
- `GET /accounts/:account_id/transactions` — master filtered list  

Nav: add **Accounts** (or “All transactions”) link in the sticky header per Step 3 nav standards — clarify label vs existing “Accounts” that currently means statement index. **Rename carefully:**

| Current nav | After 4.5 |
|-------------|-----------|
| “Accounts” → `/account_statements` | Prefer **“Statements”** for statement index |
| (new) | **“Accounts”** → `/accounts` master index |

Update home cards copy to match.

---

## Feature parity with Step 4

Same filters and UX:

| Param | Behavior |
|-------|----------|
| `date_from` / `date_to` | Inclusive on `account_transactions.date` |
| `section` | Exact match; options = distinct sections **across statements for this account** |
| `description` | Live partial match (debounced) |
| `amount` | Live partial match on dollar `printf` of `amount_cents` |
| Clear filters | Bookmarkable GET; clear link |

Also reuse:

- Form **outside** `turbo-frame#transactions`; frame = count + table/empty  
- `live_filter_controller.js` (no new Stimulus controller unless needed)  
- `FilterableTransactions` / `AccountTransaction.apply_filters`  
- Finance-workspace `card-pad`, `data-table`, `empty-state`, `btn-*`

### Extra columns / context (master-only)

Per-statement index can omit statement identity; master view should add:

- **Statement period** (or `source_filename`) column, and/or  
- Link to `account_statement_path(statement)`  

Keep the shared `_table` partial extensible (local variable `show_statement_link: true`) or a thin `_master_table` that wraps the same cells plus one column—avoid duplicating amount/date markup.

### Ordering

Default: `order("account_transactions.date, account_transactions.id")` ascending (same as Step 4). Optional later: sort by period—out of scope.

### Counts

- Unfiltered: total txns for this account across statements  
- Filtered: “X matches of Y transactions” (same copy pattern as Step 4)

---

## Planned deliverables

### Backend

- Query: `AccountTransaction.joins(:account_statement).where(account_statements: { account_number: number })` then `AccountTransaction.apply_filters(...)`  
- Accounts index: distinct `account_number` with aggregated statement count, txn count, latest `account_name`, min/max period  
- Helpers: encode/decode account id for URLs; `display_text` / `cents_to_currency` unchanged  

### Frontend

- `AccountsController#index`  
- `Accounts::TransactionsController#index`  
- Views under `app/views/accounts/` and `app/views/accounts/transactions/`  
- Nav + home label tweaks  

### Tests

- Two PDF-like statements (or AR setup) sharing the same `account_number`, different periods → master list contains both sets  
- Different `account_number` → not included  
- Nil `account_number` statements excluded from index (if following recommended option)  
- Filter dimensions (date, section, description, amount) on the master path  
- Turbo Frame / clear filters smoke via integration GET params  

---

## Acceptance checklist (Step 4.5)

- [x] Placement treated as 4.5 in parent `SPEC.md` implementation order  
- [x] `/accounts` lists accounts grouped by `account_number`  
- [x] Master transactions page unions all statements for that account  
- [x] Step 4 filters + live-filter + Turbo Frame behavior parity  
- [x] Statement context link/column present  
- [x] Nav/home labels distinguish Statements vs Accounts  
- [x] CSV-without-number policy implemented and noted in UI  
- [x] Integration tests green  

---

## What shipped

### Backend

- `Accounts::Id` — URL-safe Base64 encode/decode; `normalize` strips spaces for grouping
- `AccountSummary` read-model — groups statements by normalized number; prefers spaced display number
- `AccountsController#index`, `Accounts::TransactionsController#index`
- Routes: `GET /accounts`, `GET /accounts/:account_id/transactions`

### UI

- Accounts index with CSV-without-number callout
- Master transactions: shared `shared/account_transaction_filters`, Turbo Frame, statement period column/link
- Nav: **Accounts** | **Statements** | **Credit cards**; home card for Accounts

### Tests

- `test/services/accounts/id_test.rb`
- `test/integration/accounts_test.rb` — grouping across spacing variants, filters, nav labels

### Changes along the way

1. Spacing variants (`0057 4568 7822` vs `005745687822`) group as one account via `REPLACE` / normalize.
2. Shared bank filter partial extracted for statement-scoped and master views.
3. `show_statement:` option on account transaction table for master context links.

---

## Areas of concern

### Account number formatting

BoA numbers may include spaces (`"0057 4568 7822"`). Inconsistent spacing across imports would split one account into two groups. Normalize on write (importer) and/or on read (group using `REPLACE(account_number, ' ', '')` while displaying the canonical spaced form). **Prefer normalizing in the importer going forward** and a one-time display/group normalize in 4.5 queries.

### URL safety

Raw account numbers in paths are awkward. Encode/decode bugs = 404s or wrong account. Centralize in `Accounts::Id` (or similar) and test round-trips including spaces.

### Nav label collision

Today “Accounts” means statement list. Renaming without a redirect/confusion note will feel like a regression. Do rename + home card copy in the same PR as the feature.

### Duplicated filter UI

Copy-pasting Step 4 filter partials will drift. Extract shared filter partials/helpers where account vs statement only differ by `url:` and type field (`section` only for bank). CC master view is out of scope—don’t over-abstract for CC yet.

### Performance

Cross-statement joins + `LIKE`/`printf` on years of data stay acceptable for personal SQLite. Still filter in SQL; don’t load all txns into Ruby. Indexes on `account_statements.account_number` already exist from Step 1.

### Checksum dedupe vs master list

Txn-level checksums already prevent re-import duplicates globally. Master view should not unique-by-checksum again (intra-file dupes remain visible). No extra dedupe layer.

### Credit cards

Year-end CC statements have no `account_number` in schema. A “master CC” view would need a different identity (filename year, future card last-four, etc.). **Out of scope for 4.5** — document as a follow-on so this step stays bank-account-focused.

### Step 6 verification

Once 4.5 lands before 6, browser verification should include: import two PDFs for the same account (or seed two statements) → master list → exercise filters. Update Step 6 checklist when implementing.

---

## Parent SPEC touch-ups (when implementing)

1. Insert step **4.5** in Implementation order.  
2. Amend Step 4 “Never (v1) … cross-statement global transaction indexes” — that line is superseded for **per-account** master views (still no single global all-accounts mega-list required).  
3. Optional: add top-level `GET /accounts/...` under Routes & pages.

---

## Key files to add (Step 4.5)

```
app/controllers/accounts_controller.rb
app/controllers/accounts/transactions_controller.rb
app/models/concerns/ or app/services/accounts/id.rb   # URL encode/decode
app/views/accounts/index.html.erb
app/views/accounts/transactions/index.html.erb
app/views/accounts/transactions/_filters.html.erb     # or shared partial
app/views/accounts/transactions/_results.html.erb
app/views/layouts/application.html.erb                # nav labels
app/views/home/index.html.erb                         # copy
config/routes.rb
test/integration/accounts_test.rb
test/integration/account_transactions_master_filter_test.rb
SPEC_STEP_4_5.md                                      # this file
SPEC.md                                               # order + routes note
```

---

## Implementation notes when coding starts

1. Confirm account-number normalization rules before writing routes.  
2. Extract shared bank filter partial from statement vs account if duplication appears in the first PR.  
3. Keep CC out of this step.  
4. After shipping, set Status to **Complete** and add “What shipped / changes along the way.”
