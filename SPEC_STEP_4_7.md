# SPEC — Step 4.7: Credit Card Account Name (User-Assigned Identity)

Parent document: [`SPEC.md`](./SPEC.md)  
Prior CC UI: [`SPEC_STEP_3.md`](./SPEC_STEP_3.md)  
Bank parallel (derived identity): [`SPEC_STEP_4_5.md`](./SPEC_STEP_4_5.md)  
Follow-ons: [`SPEC_STEP_4_8.md`](./SPEC_STEP_4_8.md) (master CC txns), [`SPEC_STEP_4_9.md`](./SPEC_STEP_4_9.md) (CC account summary)

Status: **Not started** (spec only)

---

## Placement

**4.7** sits after bank account identity (4.5/4.6) and before layout polish (5) / browser verify (6). Year-end CC PDFs have no gem-provided card id; this step adds a **user-specified** identity so later steps can mirror bank master/summary views.

Order: **4.5 → 4.6 → 4.7 → 4.8 → 4.9 → 5…**

---

## What Step 4.7 is

Introduce a persisted **`CreditCardAccount`** with a user-chosen **name**. On every credit-card statement import, the user must either:

1. **Select** an existing credit card account, or  
2. **Enter a new name** (creates the account, then attaches the statement)

Every `CreditCardStatement` belongs to exactly one `CreditCardAccount` going forward.

### Goals

1. Migration: `credit_card_accounts` (`name`, timestamps); `credit_card_statements.credit_card_account_id` FK.
2. Model `CreditCardAccount` — `has_many :credit_card_statements`; unique name (case-insensitive preferred).
3. Associate importer + `CreditCardStatementsController#create` / `#new` with account selection UI.
4. Light **CC accounts index** (`/credit_card_accounts`) listing name, statement count, txn count.
5. Backfill strategy for any existing statements that lack an account.
6. Nav/home: distinguish **Credit cards** (accounts) vs statement list if needed — see Nav below.
7. Tests for create-with-existing, create-with-new-name, validation, uniqueness, backfill.

### Depends on

| Prerequisite | Why |
|--------------|-----|
| Step 2–3 | `CreditCardStatements::Importer`, CC upload UI |
| Step 3 UI standards | Form/index chrome |

### Explicitly out of Step 4.7

| Deferred to | Work |
|-------------|------|
| Step 4.8 | Master CC transactions across statements for one account |
| Step 4.9 | CC account summary (category rollups) |
| Later | Rename account UI polish beyond basic edit (optional minimal rename OK in 4.7 if cheap) |
| Later | Reassign statement to a different account after import |
| Never (v1) | Inferring card identity from PDF/gem |

---

## Data model

### `credit_card_accounts`

| Column | Type | Notes |
|--------|------|-------|
| `name` | string | required; unique (recommend unique index on `LOWER(name)` or normalize before save) |
| timestamps | | |

### `credit_card_statements` (change)

| Column | Type | Notes |
|--------|------|-------|
| `credit_card_account_id` | fk | **required** after backfill |

Associations:

```ruby
# CreditCardAccount
has_many :credit_card_statements, dependent: :restrict_with_exception # or :destroy — prefer restrict if statements matter
has_many :credit_card_transactions, through: :credit_card_statements

# CreditCardStatement
belongs_to :credit_card_account
```

**Destroy policy (pick one, document in code):**

- **Recommended:** `dependent: :restrict_with_error` on account — must delete/move statements first.  
- Alternative: destroying account destroys statements/txns (dangerous; avoid for v1).

---

## Import UX

On `credit_card_statements#new`:

1. **Credit card account** (required)
   - Radio or select: “Existing account” → dropdown of `CreditCardAccount.order(:name)`
   - “New account” → text field `name`
2. **File** (required) — unchanged accept list

`#create` flow:

1. Resolve account: find by id **or** `find_or_create_by`-style create with validated name (prefer explicit create + uniqueness error handling, not silent find_or_create across case variants).
2. Call importer with file.
3. Set `statement.credit_card_account = account` (inside importer or immediately after in controller — **prefer passing `credit_card_account:` into the importer** so one DB transaction owns statement + txns + association).

Flash on success unchanged (imported/skipped counts). On missing account choice: alert and re-render `new`.

### Importer API extension

```ruby
CreditCardStatements::Importer.call(
  io:, filename:,
  credit_card_account: # CreditCardAccount
)
```

Raise `Imports::Error` if account blank.

---

## Backfill (existing data)

If any `CreditCardStatement` rows exist without an account:

1. Migration adds FK **nullable** first (or dual-step migration).
2. Rake task or one-shot in migration: create account `"Unassigned"` (or prompt in UI) and attach orphans — **for this personal app, auto-create `Unassigned` and assign is acceptable**.
3. Second migration (or same after data): `null: false` on FK.

Document in SPEC that re-import under a real name later may require reassign (out of 4.7) or delete + re-import.

---

## Nav / home

| Label | Path | Meaning |
|-------|------|---------|
| **Credit cards** | `/credit_card_accounts` | User-named cards (new primary) |
| **CC statements** (optional secondary) | `/credit_card_statements` | Flat statement list (keep for ops/debug) |

**Recommended:** Nav “Credit cards” → accounts index. Accounts index rows link to statement list filtered by account **or** (until 4.9) to `credit_card_statements_path` with a query `?credit_card_account_id=` and/or show statements nested under account. Minimal 4.7: account show stub listing member statements + link to import with account preselected.

Home card “Credit cards” → `/credit_card_accounts`.

---

## Planned deliverables

### Routes (sketch)

```ruby
resources :credit_card_accounts, only: %i[index show] # show = statement list for that card until 4.9 upgrades it
resources :credit_card_statements, only: %i[index show new create destroy] do
  resources :transactions, only: :index, module: :credit_card_statements
end
```

Preselect: `new_credit_card_statement_path(credit_card_account_id: account.id)`.

### Tests

| Case | Expectation |
|------|-------------|
| Import with new name | Creates account + statement; FK set |
| Import with existing id | Reuses account; no duplicate name |
| Duplicate name (case variant) | Validation error / Imports::Error |
| Missing account + file | Alert; no statement |
| Backfill | Orphans attached; FK non-null |

---

## Acceptance checklist (Step 4.7)

- [ ] `CreditCardAccount` persisted with unique name  
- [ ] Every new CC import requires existing or new account  
- [ ] Importer/controller associates statement in one transaction  
- [ ] `/credit_card_accounts` index works  
- [ ] Nav/home point at CC accounts  
- [ ] Existing statements backfilled; FK required  
- [ ] Tests green  

---

## Areas of concern

### Name uniqueness and normalization

Strip whitespace; store canonical display name; compare case-insensitively to avoid “Sapphire” vs “sapphire”.

### Importer transaction boundary

Attach account inside the same AR transaction as statement create so failures don’t leave an empty account (empty accounts from abandoned “new name” then failed file upload: either create account only after successful parse, or allow empty accounts and clean up — **prefer resolve account after successful extract, before persist**, or create account in the same transaction as persist only after extract succeeds).

### Asymmetry with bank accounts

After **4.6**, bank accounts are also persisted with an FK — but bank identity is **find-or-created from gem `account_name`**, while CC identity is **chosen/entered by the user** at import (year-end PDFs have no card name). UI copy for CC should say “Name this card,” not “Account number.”

### Statement index clutter

Keep flat `/credit_card_statements` but lead users through accounts. Filter statement index by `credit_card_account_id` when provided.

### Step 6

Browser-verify: create “Travel card”, import year-end PDF, confirm account index and statement show membership.

---

## Key files

```
db/migrate/*_create_credit_card_accounts.rb
db/migrate/*_add_credit_card_account_to_statements.rb
app/models/credit_card_account.rb
app/models/credit_card_statement.rb
app/services/credit_card_statements/importer.rb
app/controllers/credit_card_accounts_controller.rb
app/controllers/credit_card_statements_controller.rb
app/views/credit_card_accounts/*
app/views/credit_card_statements/new.html.erb
config/routes.rb
test/models/credit_card_account_test.rb
test/integration/credit_card_account_import_test.rb
SPEC_STEP_4_7.md
```
