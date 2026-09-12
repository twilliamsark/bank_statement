# STEP 8 SPEC — Import Monthly Credit Card Statements + Reconciliation

Parent: Steps 1–7 complete (`SPEC.md` marked Complete). Step 8 is a **new scope** beyond v1.

**Implementation is chunked** (do not treat this file as a single build checklist):

| Chunk | Spec | Scope |
| ----- | ---- | ----- |
| 8.1 | [`SPEC_STEP_8.1.md`](./SPEC_STEP_8.1.md) | `UnreconciledTransaction` (+ `import_fingerprint`) + `MonthlyCreditCardStatement` + monthly import UI (blank categories) |
| 8.2 | [`SPEC_STEP_8.2.md`](./SPEC_STEP_8.2.md) | **Auto Reconcile** button (amount + 21-char description match) |
| 8.2.1 | [`SPEC_STEP_8.2.1.md`](./SPEC_STEP_8.2.1.md) | Card summary: monthly statements above year-end + View Unreconciled entry points |
| 8.3 | [`SPEC_STEP_8.3.md`](./SPEC_STEP_8.3.md) | Monthly FK on `CreditCardTransaction` + **Save Reconciled** (copy + delete staging) |
| 8.4 | [`SPEC_STEP_8.4.md`](./SPEC_STEP_8.4.md) | Per-row category/subcategory dropdowns so remaining rows can be saved |
| 8.4.1 | [`SPEC_STEP_8.4.1.md`](./SPEC_STEP_8.4.1.md) | Live filters on unreconciled list (same pattern as CC transactions) |
| 8.4.2 | [`SPEC_STEP_8.4.2.md`](./SPEC_STEP_8.4.2.md) | Jump-to-page dropdown on CC + unreconciled pagination |
| 8.5 | [`SPEC_STEP_8.5.md`](./SPEC_STEP_8.5.md) | Monthly statements index + summary `#show` + browse/Import entry points |
| 8.6 | [`SPEC_STEP_8.6.md`](./SPEC_STEP_8.6.md) | Fingerprint **potential duplicate** flag on import; must clear before reconcile/save |
| Later | TBD | Items still in parent Step 8 but not covered by 8.1–8.6 |

This document remains the locked overall design. Chunk specs may simplify naming/sequencing (e.g. staging model `UnreconciledTransaction`, Auto Reconcile as an explicit button instead of import-time auto-fill).

---

## Decisions already locked (from you)

| Topic                | Decision                                                                   |
| -------------------- | -------------------------------------------------------------------------- |
| Shared txn model     | Monthly and year-end rows both end as `CreditCardTransaction`              |
| Monthly parent       | New `MonthlyCreditCardStatement` + FK on `CreditCardTransaction`           |
| Uncategorized home   | **Staging table** until Import commits reconciled rows                     |
| Category auto-fill   | Match year-end txns by **amount + first 21 description chars** (no date)   |
| `import_fingerprint` | Category matching does **not** use it; **potential-duplicate** flagging is Step 8.6 |
| Date field           | Use gem `transaction_date` as `date`                                       |
| Match scope          | Same `CreditCardAccount` only                                              |
| UI rename            | `/credit_card_accounts` “Import statement” → **Import Year End Statement** |
| New screen           | **Import Monthly Statement** (+ reconciliation UI)                         |

---

## Thoughts / design notes (read first)

### What works well in your sketch

1. **Staging before `CreditCardTransaction`** keeps the hard invariant: final CC txns always have `category` + `subcategory`. Monthly PDFs never invent fake categories.
2. **One txn table** keeps account rollups, filters, and existing transaction pages working once rows are imported.
3. **Amount + `description[0, 21]`** for category suggestion is the right _semantic_ match between year-end merchant text and monthly merchant text. Keeping **`import_fingerprint` (includes date)** for a later dedupe step avoids overloading one key for two jobs.
4. **Import button only commits reconciled rows** gives a clear human checkpoint; unreconciled stay in staging.

### Gaps / sharpenings for the SPEC

1. **Two different “match” concepts — name them separately in the SPEC**
   - **Category match key:** `[description[0, 21], amount_cents]` — fills category/subcategory from a year-end txn on the same card.
   - **`import_fingerprint`:** `MD5("#{date}|#{description[0, 21]}|#{amount_cents}")` — reserved for **later** cross-import duplicate detection. Do not use it for Step 8 category fill.
   - Align app helper with the monthly gem: gem uses `description[0, 21]` (21 chars). Current app `import_fingerprint_for` uses `description[..21]` (22 chars). **Step 8 should fix the app helper to `[0, 21]`** and backfill existing fingerprints in the migration/data fix.

2. **Year-end gem fingerprint is not in the installed copy**
   - Monthly gem `CCAccountStatement::Extractor::Transaction#fingerprint` exists.
   - Installed `cc_year_end_statement` (`…/cc_year_end_statement-cd649b8ef470`) still defines `Transaction` **without** `#fingerprint`.
   - App already has `CreditCardTransaction.import_fingerprint_for` + column. Step 8 can proceed using the **app** helper for any fingerprint work; optionally `bundle update cc_year_end_statement` if you want gem parity. Not a blocker for reconciliation.

3. **Parent statement XOR on `CreditCardTransaction`**
   - Today `credit_card_statement_id` is `null: false`.
   - Add nullable `monthly_credit_card_statement_id`.
   - Make `credit_card_statement_id` nullable.
   - Validate **exactly one** of the two FKs is present.
   - Update `CreditCardAccount`: today `has_many :credit_card_transactions, through: :credit_card_statements` will miss monthly rows — add `has_many :monthly_credit_card_statements` and a combined transactions association (or two `through`s + a method/`unscope` union used by account show).

4. **Ambiguous category matches**
   - Same account may have multiple year-end rows sharing amount + desc prefix with **different** category/subcategory.
   - Spec rule: if all matching year-end rows agree on `(category, subcategory)`, auto-fill and mark reconciled; if they disagree, leave unreconciled for manual pick. If they agree, any match is fine.

5. **Dependent subcategory dropdown**
   - Categories/subcategories come from **distinct values already in `credit_card_transactions`** (typically year-end seeded).
   - Subcategory options should filter by selected category (Turbo/Stimulus), not a flat global list.

6. **Monthly-only fields**
   - Gem gives: `transaction_date`, `posting_date`, `description`, `reference_number`, `amount`, `section`.
   - Persist on staging: `date` ← `transaction_date`, `posting_date`, `section`, `reference_number`, `description`, `amount_cents`.
   - On commit to `CreditCardTransaction`: map `date`, `description`, `amount_cents`, `category`, `subcategory`; `location` = `""`; do **not** require new columns for section/reference on the final txn in Step 8 (keep staging as the place that retains monthly extras). Optional later: add columns.

7. **Reconciliation UI shape**
   - After upload, redirect to the monthly statement’s **reconcile** page (not straight to a summary of real txns).
   - Show **all remaining staging rows** (reconciled + unreconciled), visually distinct.
   - Auto-matched rows: category/subcategory pre-filled, marked reconciled, still editable until Import.
   - Unmatched: empty dropdowns; when **both** are set → `reconciled: true` (PATCH via Turbo).
   - **Import reconciled** buttons at top **and** bottom: create `CreditCardTransaction` for each reconciled staging row, delete those staging rows, leave unreconciled in place. Flash counts.

8. **Dedupe of monthly re-imports**
   - Explicitly **out of Step 8** (uses `import_fingerprint` later). Re-uploading the same PDF may create duplicate staging rows. Call that out so it isn’t treated as a bug mid-step.

9. **Checksum**
   - Existing year-end `checksum` includes category/subcategory/location. Monthly committed rows get a checksum **after** categories are known (same helper). No change to checksum algorithm required.

---

## Goal

Add monthly BoA credit-card statement import via `CCAccountStatement` (`Extractor` / `CSVExtractor`), stage extracted rows for category reconciliation against existing year-end `CreditCardTransaction`s on the same card, then commit reconciled rows into the shared `credit_card_transactions` table under a new `MonthlyCreditCardStatement`.

---

## Gem boundary

| Format | Extractor                          |
| ------ | ---------------------------------- |
| `.pdf` | `CCAccountStatement::Extractor`    |
| `.csv` | `CCAccountStatement::CSVExtractor` |

HOW_TO: gem path `…/cc_account_statements-95404dfd5c4b/HOW_TO.md`.

Useful `Result` fields: `account_name`, `account_number`, `period_start`, `period_end`, `page_count`, `summary` (balances etc.), `sections`, `transactions`.

Flat txn fields: `transaction_date`, `posting_date`, `description`, `reference_number`, `amount` (`BigDecimal`), `section`. **No category/subcategory.**

---

## Data model

### 1. `monthly_credit_card_statements` (new)

| Column                                          | Type          | Notes                                                                                                                                                                                                                                                                                           |
| ----------------------------------------------- | ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `credit_card_account_id`                        | fk            | required                                                                                                                                                                                                                                                                                        |
| `period_start`                                  | date          | nullable (CSV)                                                                                                                                                                                                                                                                                  |
| `period_end`                                    | date          | nullable (CSV)                                                                                                                                                                                                                                                                                  |
| `account_name`                                  | string        | from PDF; nullable                                                                                                                                                                                                                                                                              |
| `account_number`                                | string        | nullable                                                                                                                                                                                                                                                                                        |
| `page_count`                                    | integer       | nullable                                                                                                                                                                                                                                                                                        |
| `source_filename`                               | string        |                                                                                                                                                                                                                                                                                                 |
| `import_format`                                 | string        | `pdf` / `csv`                                                                                                                                                                                                                                                                                   |
| summary money fields (optional but recommended) | integer cents | mirror gem summary where useful: `previous_balance_cents`, `payments_and_credits_cents`, `purchases_and_adjustments_cents`, `fees_charged_cents`, `interest_charged_cents`, `new_balance_cents`, … — can start minimal (`period_*` + file meta) and add summary columns if show page needs them |
| timestamps                                      |               |                                                                                                                                                                                                                                                                                                 |

- `has_one_attached :source_file`
- `has_many :credit_card_transaction_reconciliations, dependent: :destroy`
- `has_many :credit_card_transactions` (committed rows)

### 2. `credit_card_transaction_reconciliations` (staging)

| Column                             | Type    | Notes                                                          |
| ---------------------------------- | ------- | -------------------------------------------------------------- |
| `monthly_credit_card_statement_id` | fk      | required                                                       |
| `date`                             | date    | from `transaction_date`                                        |
| `posting_date`                     | date    | nullable                                                       |
| `description`                      | text    | required                                                       |
| `reference_number`                 | string  | nullable                                                       |
| `section`                          | string  | e.g. Purchases and Adjustments                                 |
| `amount_cents`                     | integer | required                                                       |
| `category`                         | string  | nullable until filled                                          |
| `subcategory`                      | string  | nullable until filled                                          |
| `reconciled`                       | boolean | default `false`; true when both category + subcategory present |
| `match_source`                     | string  | optional: `auto` / `manual` for UI/debug                       |
| timestamps                         |         |                                                                |

Indexes: `monthly_credit_card_statement_id`, `reconciled`, `[amount_cents]` (for match lookups).

**Reconciled rule:** `reconciled == true` iff `category` and `subcategory` both present (enforce in model callback/validation). Clearing either sets `reconciled` false.

### 3. Changes to `credit_card_transactions`

| Change                             | Notes                                                                                                                    |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `credit_card_statement_id`         | become **nullable**                                                                                                      |
| `monthly_credit_card_statement_id` | new nullable fk                                                                                                          |
| XOR validation                     | exactly one parent statement                                                                                             |
| `import_fingerprint`               | already added (WIP migration); fix helper to `description[0, 21]`; index optional non-unique; **backfill** existing rows |
| category/subcategory               | remain **required** on this table (only created after reconcile)                                                         |

### 4. Association updates

- `CreditCardAccount` `has_many :monthly_credit_card_statements`
- Account transaction counts/lists must include monthly-committed txns (not only `through: :credit_card_statements`)

---

## Services

### `MonthlyCreditCardStatements::Importer`

Mirror `CreditCardStatements::Importer`:

1. Resolve `CreditCardAccount` (existing or create-from-name), same UX pattern as year-end.
2. Extract via gem by extension.
3. In one DB transaction:
   - Create `MonthlyCreditCardStatement` + attach file.
   - For each gem txn → create staging row (`date` = `transaction_date`, cents conversion via `Money.cents`).
   - Run **auto-categorize** (below).
4. Return result: `statement`, `staged_count`, `auto_reconciled_count` (no final `CreditCardTransaction` yet).

### `CreditCardTransactionReconciliations::AutoCategorize` (or private importer step)

For each staging row on account `A`:

1. Build key: `description[0, 21]` + `amount_cents`.
2. Find year-end-backed `CreditCardTransaction`s for account `A` (`where.not(credit_card_statement_id: nil)` or `joins` year-end statements) with same amount and `LEFT(description, 21)` / Ruby-side prefix match at personal scale.
3. If matching rows’ `(category, subcategory)` pairs are unanimous → set both, `reconciled = true`, `match_source = "auto"`.
4. Else leave unreconciled.

### `CreditCardTransactionReconciliations::Commit`

Given a `MonthlyCreditCardStatement`:

- For each staging row with `reconciled: true`:
  - Create `CreditCardTransaction` with `monthly_credit_card_statement_id`, null year-end fk, categories, `location: ""`, checksum + import_fingerprint assigned by model.
  - Destroy staging row.
- Return `imported_count`; unreconciled remain.

**Step 8 does not skip staging rows via `import_fingerprint`.** Document as follow-on.

---

## Routes & UI

### Rename (year-end)

On `credit_card_accounts#index` (and empty state / per-row Import links as appropriate):

- Primary CTA: **Import Year End Statement** → existing `new_credit_card_statement_path`
- Add primary/secondary: **Import Monthly Statement** → `new_monthly_credit_card_statement_path`
- Per-row year-end “Import” label → “Import year-end” (or keep short if space is tight, but page-level CTA must be unambiguous)

Year-end `new` title already says “year-end”; keep that.

### New resources

```ruby
resources :monthly_credit_card_statements, only: %i[index show new create destroy] do
  resource :reconciliation, only: %i[show update], module: :monthly_credit_card_statements
  # show = reconcile UI; update = commit reconciled rows (Import buttons)
  resources :transaction_reconciliations, only: %i[update], module: :monthly_credit_card_statements
  # PATCH one staging row’s category/subcategory
end
```

(Exact nesting names can be bikeshedped in the SPEC file; behavior above is required.)

### Screens

1. **Import Monthly Statement (`#new`)** — same account picker pattern as year-end; accept `.pdf,.csv`.
2. **Reconcile (`reconciliation#show`)**
   - Header: card name, period, filename, counts (`N reconciled / M total`).
   - Buttons top + bottom: **Import reconciled** (disabled if zero reconciled).
   - Table columns: date, description, amount, category select, subcategory select, status.
   - Optional: show `section` as muted secondary text under description.
3. **Monthly statement `#show`** (after some commits) — period summary + link back to reconcile if staging rows remain + link to transactions filtered/scoped to this monthly statement.
4. **Nav** — “Credit cards” active state should include monthly routes (extend `nav_section_active?` paths).

### Stimulus / Turbo

- Changing category refreshes subcategory options (only subs seen with that category in `credit_card_transactions`).
- When both selects have values → PATCH row → mark reconciled → update row status without full page reload.
- Import uses normal form POST with `data-turbo-submits-with`.

---

## Category / subcategory option source

```ruby
CreditCardTransaction.distinct.order(:category).pluck(:category)
CreditCardTransaction.where(category: selected).distinct.order(:subcategory).pluck(:subcategory)
```

If the account has no year-end data yet, dropdowns are empty — flash guidance: import a year-end statement first (or allow free-text later; **out of Step 8** — selects only).

---

## Fingerprint helper fix (in Step 8, small)

Align with monthly gem:

```ruby
def self.import_fingerprint_for(date:, description:, amount_cents:)
  payload = [date.to_s, description.to_s[0, 21], amount_cents.to_i].join("|")
  Digest::MD5.hexdigest(payload)
end
```

Backfill `import_fingerprint` for existing year-end rows. Still **unused for monthly commit dedupe** in this step.

Add a separate pure helper for category matching (do not overload fingerprint):

```ruby
def self.category_match_prefix(description)
  description.to_s[0, 21]
end
```

---

## Tests (minimum)

- Monthly importer stages rows; auto-reconcile when unanimous same-account year-end match on amount + prefix.
- Disagreement among year-end matches → left unreconciled.
- PATCH sets category+subcategory → reconciled.
- Commit creates `CreditCardTransaction`s with `monthly_credit_card_statement_id`, deletes reconciled staging rows only.
- XOR validation on parent FKs.
- `import_fingerprint_for` uses 21-char prefix.
- Integration: rename CTA visible; monthly new → reconcile path happy path with fixture PDF/CSV if available under test fixtures (or gem-shaped stubs like year-end tests).

---

## Explicitly out of Step 8

| Out                                                          | Notes                                         |
| ------------------------------------------------------------ | --------------------------------------------- |
| Auto-skipping/deleting duplicate monthly imports             | 8.6 **flags** potential duplicates instead; no auto-skip/delete |
| Free-text category entry                                     | Selects from existing txn values only         |
| Renaming `CreditCardStatement` → YearEnd…                    | Keep existing name; UI copy clarifies         |
| Editing categories on already-committed monthly txns         | Not required                                  |
| Matching across different credit cards                       | Same account only                             |
| Browser E2E with real BoA PDFs                               | Follow-on verification step (like old Step 6) |

---

## Suggested implementation order (for `SPEC_STEP_8.md` checklist)

1. Schema: monthly statements, staging, nullable year-end fk + monthly fk, fingerprint fix/backfill/index
2. Models + validations + account associations
3. Auto-categorize + monthly importer service
4. Commit service
5. Controllers/routes/views (rename CTAs, import, reconcile, commit)
6. Turbo/Stimulus for dependent dropdowns + row PATCH
7. Tests
8. Amend parent `SPEC.md` “Project status” / add Step 8 pointer

---

## Open micro-choices (defaults if you accept the SPEC as-is)

| Item                          | Default in SPEC                                                                     |
| ----------------------------- | ----------------------------------------------------------------------------------- |
| Staging model name            | `CreditCardTransactionReconciliation`                                               |
| Monthly summary cents columns | Include core summary fields from gem `summary` on the monthly statement for `#show` |
| Ambiguous auto-match          | Leave unreconciled                                                                  |
| Import with zero reconciled   | Button disabled + no-op safe                                                        |

---

## Approval outcome

On approve, implement by **writing `SPEC_STEP_8.md`** (and a short parent `SPEC.md` status tweak) — not the feature code — unless you ask to execute the step immediately after.
