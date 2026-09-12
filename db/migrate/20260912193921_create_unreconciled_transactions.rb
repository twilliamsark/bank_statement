# frozen_string_literal: true

class CreateUnreconciledTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :unreconciled_transactions do |t|
      t.references :monthly_credit_card_statement, null: false, foreign_key: true
      t.date :date, null: false
      t.text :description, null: false
      t.integer :amount_cents, null: false
      t.string :category
      t.string :subcategory
      t.string :import_fingerprint, null: false

      t.timestamps
    end

    add_index :unreconciled_transactions, :amount_cents
    add_index :unreconciled_transactions, :import_fingerprint
  end
end
