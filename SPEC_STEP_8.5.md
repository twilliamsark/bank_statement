# SPEC — Step 8.5: Monthly Statement List + Summary Page

Parent: [`SPEC_STEP_8.md`](./SPEC_STEP_8.md) (overall Step 8 design)  
Prior: [`SPEC_STEP_8.1.md`](./SPEC_STEP_8.1.md)–[`SPEC_STEP_8.4.md`](./SPEC_STEP_8.4.md)  
Depends on: `MonthlyCreditCardStatement` + import from 8.1; committed monthly `CreditCardTransaction`s from 8.3 for rich totals (show page must still work with only staging / empty committed sets)

Status: **Not started**

---

## Goal

Make monthly credit-card statements a first-class browseable surface, parallel to year-end statements:

1. A clear **Monthly CC Statements** entry point (button/link) from the credit-card UI.
2. A real **index** of monthly statements with an **Import Monthly Statement** button.
3. A real **summary `#show`** page for a monthly statement (period, file meta, gem summary balances, links into reconcile / committed transactions).

**Out of this chunk:** fingerprint dedupe, free-text categories, editing committed txn categories.

---

## Decisions for 8.5

| Topic | Decision |
| ----- | -------- |
| Mirror year-end UX | Same general pattern as `credit_card_statements#index` / `#show`, but monthly copy and fields |
| Import CTA | **Import Monthly Statement** on monthly index (and empty state); keep accounts-page CTA from 8.1 |
| Summary money | Persist core gem `summary` fields as cents on `MonthlyCreditCardStatement` (nullable for CSV) |
| After import landing | Unchanged from 8.1: create still redirects to **unreconciled** list; `#show` is for browsing afterward |
| Destroy | Deleting a monthly statement destroys staging rows; committed monthly `CreditCardTransaction`s depend on FK policy (`dependent: :destroy` recommended, matching year-end) |

---

## Data model additions

Extend `monthly_credit_card_statements` with summary columns from `CCAccountStatement` `result.summary` (PDF; CSV leaves nil):

| Column | Type | Gem source |
| ------ | ---- | ---------- |
| `previous_balance_cents` | integer | `summary.previous_balance` |
| `payments_and_credits_cents` | integer | `summary.payments_and_credits` |
| `purchases_and_adjustments_cents` | integer | `summary.purchases_and_adjustments` |
| `fees_charged_cents` | integer | `summary.fees_charged` |
| `interest_charged_cents` | integer | `summary.interest_charged` |
| `new_balance_cents` | integer | `summary.new_balance` |
| `total_credit_line_cents` | integer | `summary.total_credit_line` |
| `total_credit_available_cents` | integer | `summary.total_credit_available` |
| `cash_credit_line_cents` | integer | `summary.cash_credit_line` |
| `cash_credit_available_cents` | integer | `summary.cash_credit_available` |
| `statement_closing_date` | date | `summary.statement_closing_date` |
| `days_in_billing_cycle` | integer | `summary.days_in_billing_cycle` |
| `current_payment_due_cents` | integer | `summary.current_payment_due` |
| `total_minimum_payment_due_cents` | integer | `summary.total_minimum_payment_due` |
| `payment_due_date` | date | `summary.payment_due_date` |
| `fees_ytd_cents` | integer | `summary.fees_ytd` |
| `interest_ytd_cents` | integer | `summary.interest_ytd` |

All money fields nullable; convert via `Money.cents` in the importer.

Update `MonthlyCreditCardStatements::Importer` (from 8.1) to copy these when `result.summary` is present.

Optional nicety: helper on the model for display period label (`period_start`–`period_end`, or closing date).

---

## Routes & UI

Routes already sketched in 8.1 (`index`, `show`, `new`, `create`, `destroy`) — **implement `#index` and `#show` for real** in this chunk (not stubs).

### Entry points (“Monthly CC Statement button”)

On `credit_card_accounts#index` (and empty state as appropriate):

- Keep **Import Year End Statement** / **Import Monthly Statement** from 8.1.
- Add a browse link analogous to today’s “All CC statements”, e.g. **Monthly statements** → `monthly_credit_card_statements_path`.

On `credit_card_accounts#show`:

- Add **Import Monthly Statement** (pre-selected account) alongside year-end import.
- Optionally list recent monthly statements for this card, or a link to filtered monthly index.

On `monthly_credit_card_statements#index`:

- Primary button: **Import Monthly Statement**
- Table: card name, period (or closing date), filename, format, new balance (if present), staging count and/or committed txn count, **View** link
- Empty state with import CTA
- Optional filter by `credit_card_account_id` (mirror year-end statements index)

### Summary `#show`

Header:

- Back link to card (or monthly index)
- Title: period summary (e.g. `Aug 2026 statement` / `period_start–period_end`)
- Subtitle: card name · filename · format · page count

Actions:

- **Reconcile** / **Unreconciled** → unreconciled list for this statement (if any staging rows remain; still linkable if empty with empty state)
- **View transactions** → committed monthly txns for this statement (nested transactions index, or filter; can land as empty until 8.3 has been used)
- **Delete** with confirm (destroys statement + dependent rows)

Body:

- Hero / cards for key balances: at least **Previous balance**, **Payments & credits**, **Purchases & adjustments**, **New balance** (nil-safe “—” for CSV)
- Secondary grid for credit line / available, payment due / due date, fees & interest (statement + YTD) as space allows
- Note when summary is unavailable (CSV import), same pattern as bank CSV hollow-summary messaging
- If committed `CreditCardTransaction`s exist for this monthly statement: optional category/subcategory totals table (same idea as year-end statement show)
- If staging rows remain: callout with count + link to reconcile

### Nav

Ensure monthly index/show keep “Credit cards” nav active (`nav_section_active?`).

---

## Transactions under a monthly statement

Minimum for 8.5:

```ruby
# nested
resources :monthly_credit_card_statements do
  resources :transactions, only: %i[index], module: :monthly_credit_card_statements
end
```

- Lists `CreditCardTransaction.where(monthly_credit_card_statement_id: …)`
- Reuse existing CC transaction table/filter partials where practical
- Empty state until Save Reconciled (8.3) has committed rows

If wiring filters is heavy, ship a simple read-only table first; filters can match year-end statement transactions in a follow-on.

---

## Explicitly out of Step 8.5

| Out | Notes |
| --- | ----- |
| Auto Reconcile / Save Reconciled / dropdowns | 8.2–8.4 |
| Fingerprint dedupe on re-import | Out of Step 8 |
| Staging `posting_date` / `section` / `reference_number` | Still deferred |
| Renaming year-end model | Out of Step 8 |

---

## Tests (minimum)

- Importer persists summary cents from PDF gem result; CSV leaves summary fields nil
- Index lists monthly statements; shows **Import Monthly Statement**
- Accounts index (or show) exposes **Monthly statements** browse link
- Show renders period/file meta and nil-safe summary amounts
- Show links to unreconciled list; destroy removes statement
- Transactions index scoped to monthly statement (empty or with committed fixtures)

---

## Suggested implementation order

1. Migration: summary columns on `monthly_credit_card_statements`
2. Update importer to map `result.summary`
3. `index` + `show` controllers/views
4. Entry-point links/buttons on credit card accounts UI
5. Nested monthly transactions index (basic)
6. Tests

---

## Done when

- User can open a **Monthly statements** list and import from there
- User can open a monthly statement **summary** page with balances (PDF) or honest CSV empty-summary messaging
- Summary page links into reconcile (staging) and committed transactions
- Monthly statements feel as real in the UI as year-end statements, not only an unreconciled side path
