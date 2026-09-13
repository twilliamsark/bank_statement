# frozen_string_literal: true

class AddSummaryFieldsToMonthlyCreditCardStatements < ActiveRecord::Migration[8.1]
  def change
    change_table :monthly_credit_card_statements, bulk: true do |t|
      t.integer :previous_balance_cents
      t.integer :payments_and_credits_cents
      t.integer :purchases_and_adjustments_cents
      t.integer :fees_charged_cents
      t.integer :interest_charged_cents
      t.integer :new_balance_cents
      t.integer :total_credit_line_cents
      t.integer :total_credit_available_cents
      t.integer :cash_credit_line_cents
      t.integer :cash_credit_available_cents
      t.date :statement_closing_date
      t.integer :days_in_billing_cycle
      t.integer :current_payment_due_cents
      t.integer :total_minimum_payment_due_cents
      t.date :payment_due_date
      t.integer :fees_ytd_cents
      t.integer :interest_ytd_cents
    end
  end
end
