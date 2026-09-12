I need a STEP 8 SPEC for:

Overall Goal: import monthly credit card transactions via monthly PDF credit card statement (new Import Monthly Statement screen).

The 'Import Statement' button on /credit_card_accounts needs to be renamed to 'Import Year End Statement'

A new gem has been imported in the same vein as CCYearEndStatement.

A new 'fingerprint' method has been added to CCAccountStatement::Extractor::Transaction and CCYearEndStatement::Extractor::Transaction.

Goal: Monthly cc transactions will need to be tied back to their monthly statements. So likely a model MonthlyCreditCardStatement will be needed. And a monthly_credit_card_statement fk on CreditCardTransaction will be needed.

Goal: Monthly CC transactions should live in the same model as year end CC transactions.

Problem: monthly credit card statements do not include a category or subcategory.

For these monthly cc transactions we will need a reconcilation transaction model. Show the user a list of these with each row having date, description, amount. with dropdowns for category and subcategory (populated from the list of possibilities in the credit_card_transactions table)

If a candidate monthly cc transaction has the same amount and shares the first 21 characters of their description with a yearly cc transaction. Then the category and subcategory from that yearly cc transaction should be set on the transaction to be reconciled and the transaction should be marked as reconciled.

For those monthly cc transactions that do not find a match. The user will have to pick the category and subcategory. This should probably be handled via a to_be_reconciled model. Show the user a list of these with each row having date, description, amound and a dropdown for category and a dropdown for subcategory. Once both dropdowns are set the row should be marked as reconciled

An import button at the top and bottom will create a CreditCardTransaction for each imported row that is marked as reconciled. they should then be removed from the reconcilation transaction table. Leaving just the unreconciled ones.

Thoughts please
