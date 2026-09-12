# frozen_string_literal: true

class BackfillCreditCardTransactionImportFingerprints < ActiveRecord::Migration[8.1]
  def up
    say_with_time "Backfill credit_card_transactions.import_fingerprint with 21-char prefix" do
      CreditCardTransaction.reset_column_information
      CreditCardTransaction.find_each do |txn|
        fingerprint = Digest::MD5.hexdigest(
          [ txn.date.to_s, txn.description.to_s[0, 21], txn.amount_cents.to_i ].join("|")
        )
        txn.update_columns(import_fingerprint: fingerprint)
      end
    end
  end

  def down
    # Irreversible data fix; leaving fingerprints in place is safe.
  end
end
