# frozen_string_literal: true

class AddPotentialDuplicateToUnreconciledTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :unreconciled_transactions, :potential_duplicate, :boolean, null: false, default: false
    add_index :unreconciled_transactions, [ :monthly_credit_card_statement_id, :potential_duplicate ],
              name: "idx_unreconciled_on_statement_and_potential_duplicate"
  end
end
