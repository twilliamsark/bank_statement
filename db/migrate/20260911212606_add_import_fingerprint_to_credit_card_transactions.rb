# frozen_string_literal: true

class AddImportFingerprintToCreditCardTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :credit_card_transactions, :import_fingerprint, :string
  end
end
