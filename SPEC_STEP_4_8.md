# SPEC — Step 4.8: Master Credit Card Transactions (Cross-Statement)

Parent document: [`SPEC.md`](./SPEC.md)  
Depends on: [`SPEC_STEP_4_7.md`](./SPEC_STEP_4_7.md) (CC account identity)  
Bank parallel: [`SPEC_STEP_4_5.md`](./SPEC_STEP_4_5.md)  
Filters: [`SPEC_STEP_4.md`](./SPEC_STEP_4.md)

Status: **Not started** (spec only)

---

## Placement

**4.8** immediately after **4.7**. Reuses Step 4 filter/Stimulus/Turbo patterns and the bank master-txn design from 4.5, scoped by `credit_card_account_id` instead of derived `account_number`.

---

## What Step 4.8 is

A **master transactions view for one credit card account**, aggregating `CreditCardTransaction` rows across **all** `CreditCardStatement`s for that `CreditCardAccount` — with the **same filter/lookahead behavior as Step 4** (CC field set).

### Goals

1. Nested route: `GET /credit_card_accounts/:credit_card_account_id/transactions`.
2. Reuse `FilterableTransactions` + CC-specific category/subcategory filters (`CreditCardTransaction.apply_filters`).
3. Same UX: form outside Turbo Frame; live description/amount; date/category/subcategory; clear filters; pagination + filter-aware **Total** (already on statement-scoped CC lists).
4. Statement context column/link (period year or `source_filename` → statement show).
5. Wire from CC account index/show (4.7): “Transactions” → master list.
6. Integration tests: two statements same account → union; other account excluded; each filter dimension.

### Depends on

| Prerequisite | Why |
|--------------|-----|
| Step 4 | Filters, `live_filter_controller`, Turbo Frame |
| Step 4.7 | `CreditCardAccount`, FK on statements |
| Pagination/total | Already on CC statement txn pages — reuse partials |

### Explicitly out of Step 4.8

| Out | Notes |
|-----|--------|
| Step 4.9 | Category summary / rollup page |
| Cross-card global mega-list | Stay per-account |
| Bank account changes | Unrelated |

---

## Feature parity

| Param | Behavior |
|-------|----------|
| `date_from` / `date_to` | Inclusive on txn `date` |
| `category` | Exact; options distinct across this card’s statements |
| `subcategory` | Exact; distinct across this card |
| `description` | Live partial match |
| `amount` | Live dollar-string match on `amount_cents` |

Query sketch:

```ruby
base = account.credit_card_transactions # through: statements
filtered = CreditCardTransaction.apply_filters(base, params)
# paginate + sum(:amount_cents) as on existing controllers
```

### UI

- Finance-workspace: shared/adapted filter partial for CC (extract `shared/credit_card_transaction_filters` if not already shared).
- Table: reuse CC `_table` with `show_statement: true` (year / filename + link).
- Breadcrumb: ← Credit card account (4.7 show or index).

### Pagination & total

Same as current transaction lists: 50/page; footer **Total** = sum of filtered `amount_cents` across all matching rows (not page-only).

---

## Acceptance checklist (Step 4.8)

- [ ] Master CC txn path for one `CreditCardAccount`  
- [ ] Unions all statements for that account only  
- [ ] Step 4 filter + live-filter + Turbo Frame parity  
- [ ] Statement context link/column  
- [ ] Pagination + filter-aware total  
- [ ] Linked from CC account UI (4.7)  
- [ ] Integration tests green  

---

## Areas of concern

### Filter partial duplication

Account (bank) and CC filter forms already diverge (section vs category). Prefer one CC shared partial used by statement-scoped and master CC indexes.

### Large year-end volumes

One card × multiple years can be huge — pagination is mandatory; keep filtering in SQL.

### Category options

Distinct across all statements for the account may be a long list — acceptable for v1.

### Nav clarity

“Transactions” on a card should mean master (4.8), not a random single statement.

---

## Key files

```
app/controllers/credit_card_accounts/transactions_controller.rb
app/views/credit_card_accounts/transactions/*
app/views/shared/_credit_card_transaction_filters.html.erb  # optional extract
config/routes.rb
test/integration/credit_card_account_transactions_test.rb
SPEC_STEP_4_8.md
```
