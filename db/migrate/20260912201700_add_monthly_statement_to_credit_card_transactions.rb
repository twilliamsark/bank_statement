# frozen_string_literal: true

class AddMonthlyStatementToCreditCardTransactions < ActiveRecord::Migration[8.1]
  def change
    change_column_null :credit_card_transactions, :credit_card_statement_id, true

    add_reference :credit_card_transactions, :monthly_credit_card_statement,
                  null: true,
                  foreign_key: true
  end
end
