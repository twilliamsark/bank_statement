# frozen_string_literal: true

class RenameBankAccountTablesToAccountTables < ActiveRecord::Migration[8.1]
  def change
    rename_table :bank_account_statements, :account_statements
    rename_table :bank_account_transactions, :account_transactions

    rename_column :account_transactions, :bank_account_statement_id, :account_statement_id
  end
end
