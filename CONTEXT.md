# Bank Statement

Personal Rails host for Bank of America bank and credit-card statement imports, summaries, and reconciliation.

## Language

### Bank

**Account**:
A named bank account identity that owns bank statements and their transactions.
_Avoid_: Bank account (as the AR model name — that is the gem), Customer

**AccountStatement**:
One imported bank PDF/CSV statement period under an Account.
_Avoid_: BankStatement (application/module name clash)

**AccountTransaction**:
A single bank movement belonging to an AccountStatement, with a section and checksum.

### Credit card

**CreditCardAccount**:
A user-named credit card identity that owns year-end statements, monthly statements, and all committed card transactions.

**CreditCardStatement**:
A **year-end** credit-card statement import (gem `CCYearEndStatement`). UI copy says “year-end”; the model name stays as-is.
_Avoid_: YearEndStatement (as the AR model)

**MonthlyCreditCardStatement**:
A **monthly** credit-card statement import (gem `CCAccountStatement`), with period/summary metadata and both staging and committed rows.

**CreditCardTransaction**:
The shared final credit-card transaction row for both year-end and monthly parents. Always has category and subcategory. Exactly one of year-end or monthly parent FK is set.

**UnreconciledTransaction**:
A staging row from a monthly import until it is categorized and saved into a CreditCardTransaction. May be flagged as a potential duplicate.
_Avoid_: CreditCardTransactionReconciliation (parent Step 8 draft name), to-be-reconciled

### Matching & identity

**checksum**:
Content fingerprint used to skip bank/year-end rows already stored from a prior import. Credit-card checksum includes category, subcategory, and location. Intra-file duplicates are still inserted.

**import_fingerprint**:
`MD5(date | description[0, 21] | amount_cents)`. Stored on staging and committed credit-card transactions. Used for **potential duplicate** detection on monthly import — not for category matching.

**category match prefix**:
The first **21** characters of a description (`description[0, 21]`). Used only by Auto Reconcile category fill.

**Auto Reconcile**:
Fills category and subcategory on eligible UnreconciledTransactions from committed CreditCardTransactions on the **same CreditCardAccount** when `amount_cents` and the category match prefix agree and all matching rows share one `(category, subcategory)` pair. Match source includes **year-end and previously committed monthly** rows. A mix of year-end and monthly matches still counts if the pair is unanimous. Potential duplicates and already-complete rows are skipped.

**potential duplicate**:
Boolean on an UnreconciledTransaction set at monthly import when its import_fingerprint is already known for that card (staging or committed, including later lines in the same file). Blocks Auto Reconcile and Save Reconciled until cleared by hand.

**Save Reconciled**:
Copies staging rows that have both category and subcategory and are not potential duplicates into CreditCardTransaction under the monthly statement, then deletes those staging rows.

**ready to save**:
Derived eligibility: not a potential duplicate and both category and subcategory present. There is no separate `reconciled` column.
_Avoid_: reconciled (as a persisted flag — eligibility is derived)
