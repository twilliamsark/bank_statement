class CreateBankAccountTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :bank_account_transactions do |t|
      t.references :bank_account_statement, null: false, foreign_key: true
      t.date :date, null: false
      t.text :description, null: false
      t.integer :amount_cents, null: false
      t.string :section, null: false
      t.string :checksum, null: false

      t.timestamps
    end

    add_index :bank_account_transactions, :date
    add_index :bank_account_transactions, :section
    add_index :bank_account_transactions, :description
    add_index :bank_account_transactions, :checksum
  end
end
