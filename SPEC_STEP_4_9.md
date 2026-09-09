# SPEC — Step 4.9: Credit Card Account Summary

Parent document: [`SPEC.md`](./SPEC.md)  
Depends on: [`SPEC_STEP_4_7.md`](./SPEC_STEP_4_7.md), [`SPEC_STEP_4_8.md`](./SPEC_STEP_4_8.md)  
Bank parallel: [`SPEC_STEP_4_6.md`](./SPEC_STEP_4_6.md)  
Statement-level CC summary: [`SPEC_STEP_3.md`](./SPEC_STEP_3.md) (`CreditCardStatementsController#show`)

Status: **Complete** (CC account summary rollups green)

---

## Placement

**4.9** completes the CC account triad (identity → master txns → summary), parallel to bank **4.5 → 4.6**. Implement after 4.8 so the summary CTA can link to master transactions.

---

## What Step 4.9 is

Upgrade / add **`CreditCardAccountsController#show`** into a summary page matching the *kind* of detail on a single CC statement show, rolled up across all statements for that card:

| CC statement show (Step 3) | CC account show (Step 4.9) |
|----------------------------|----------------------------|
| Statement year, filename, pages, total spend | Account **name**; years covered; statement count; **aggregated** total spend |
| Category / subcategory totals | Totals across **all** account transactions |
| Link to statement transactions | Link to **master** account transactions (4.8) |
| Destroy statement | No destroy-account; list member statements |

### Goals

1. `GET /credit_card_accounts/:id` as full summary (replace or upgrade the 4.7 stub).
2. Category/subcategory totals: `group(:category, :subcategory).sum(:amount_cents)` over all account txns.
3. Aggregate `total_spend_cents` display rule (below).
4. Member statements table (year, filename, format, spend, link).
5. Primary CTA → 4.8 master transactions; index “View” → summary.
6. Finance-workspace styling; tests for rollups.

### Depends on

| Prerequisite | Why |
|--------------|-----|
| Step 3 | CC statement show as UX template |
| Step 4.7 | `CreditCardAccount` |
| Step 4.8 | Master txn path for CTA |

### Explicitly out of Step 4.9

| Out | Notes |
|-----|--------|
| Bank summary changes | Unrelated (4.6) |
| Editing category taxonomy | Read-only |
| Charts | Still out of parent SPEC scope |

---

## Aggregation rules

CC statements store `total_spend_cents` (from import) and have no beginning/ending balances like bank PDFs.

| Metric | Rule |
|--------|------|
| **Total spend (header)** | **Sum of `amount_cents`** over all `credit_card_transactions` for the account (source of truth). Optionally show note if sum diverges from sum of statement `total_spend_cents` (category-header vs txn drift). |
| **Category / subcategory totals** | `group(:category, :subcategory).sum(:amount_cents)` on account transactions |
| **Years covered** | `minmax` of statement `statement_year` and/or txn dates’ years |
| **Statement count** | `credit_card_statements.count` |

Do **not** invent bank-style beginning/ending balances for cards.

Muted note example:  
“Totals are based on imported transactions for this card across all year-end statements.”

---

## Planned deliverables

### Controller

```ruby
@account = CreditCardAccount.find(params[:id])
@statements = @account.credit_card_statements.order(statement_year: :desc, created_at: :desc)
@category_totals = @account.credit_card_transactions.group(:category, :subcategory).sum(:amount_cents)
@total_spend_cents = @account.credit_card_transactions.sum(:amount_cents)
```

Prefer `has_many :credit_card_transactions, through: :credit_card_statements` on `CreditCardAccount` (from 4.7).

### Page chrome

- Title = account name  
- Subtitle = N statements · years · total spend highlight card  
- **View transactions** → `credit_card_account_transactions_path(@account)`  
- Statements table: year, file, format, txn count or statement total, link to statement show  

### Accounts index

Row primary action → summary show; optional secondary “Transactions”.

### Tests

| Case | Expectation |
|------|-------------|
| Two statements same card | Category totals = union of both; header total = sum of all txn cents |
| Other card excluded | Totals unaffected |
| Statements list | Both linked |
| CTA | Links to 4.8 master path |

---

## Acceptance checklist (Step 4.9)

- [x] CC account show renders summary detail  
- [x] Category/subcategory totals across all statements  
- [x] Header total from transactions (filter-independent; all txns for account)  
- [x] Member statements listed  
- [x] CTA to master transactions (4.8)  
- [x] Index links to show  
- [x] Integration tests green  

---

## What you get

- **`/credit_card_accounts/:id`** summary with total spend from **all txn cents** for the card
- Category / subcategory totals across every imported year-end for that card
- Years covered, statement count, member statements table
- **View transactions** → master list (4.8)

---

## Areas of concern

### `total_spend_cents` on statements vs txn sum

Importer may set statement `total_spend_cents` from category headers. Account header should use **txn sum** for consistency with category tables and credits/refunds. Optionally display both if they differ by more than a cent.

### Multi-year category noise

Many subcategories across years — same table UX as statement show; sorting by category then subcategory.

### Overlap with 4.7 stub show

If 4.7 shipped a minimal show, 4.9 replaces it in place — avoid a second URL.

### Destroy account

Still restricted (4.7 policy). Summary page does not add delete-account.

### Step 6

Import two years under one named card; confirm summary totals and drill into master txns + filters.

---

## Key files

```
app/controllers/credit_card_accounts_controller.rb   # #show summary
app/views/credit_card_accounts/show.html.erb
app/views/credit_card_accounts/index.html.erb        # link to show
app/models/credit_card_account.rb                    # through association
test/integration/credit_card_account_summary_test.rb
SPEC_STEP_4_9.md
```
