class CreateBankAccountStatements < ActiveRecord::Migration[8.1]
  def change
    create_table :bank_account_statements do |t|
      t.string :account_name
      t.string :account_number
      t.date :period_start
      t.date :period_end
      t.integer :page_count
      t.integer :beginning_balance_cents
      t.integer :deposits_cents
      t.integer :withdrawals_cents
      t.integer :checks_cents
      t.integer :service_fees_cents
      t.integer :ending_balance_cents
      t.decimal :apy_earned, precision: 8, scale: 4
      t.integer :interest_paid_ytd_cents
      t.string :source_filename
      t.string :import_format

      t.timestamps
    end

    add_index :bank_account_statements, [ :period_start, :period_end ]
    add_index :bank_account_statements, :account_number
  end
end
