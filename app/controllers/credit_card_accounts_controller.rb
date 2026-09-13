# frozen_string_literal: true

class CreditCardAccountsController < ApplicationController
  def index
    @credit_card_accounts = CreditCardAccount.order(:name)
      .includes(:credit_card_statements, :credit_card_transactions, :monthly_credit_card_statements, :monthly_credit_card_transactions)
  end

  def show
    @credit_card_account = CreditCardAccount.find(params[:id])
    @monthly_statements = @credit_card_account.monthly_credit_card_statements
      .includes(:unreconciled_transactions)
      .order(period_end: :desc, created_at: :desc)
      .to_a
    @unreconciled_monthly_statement = @monthly_statements
      .detect { |statement| statement.unreconciled_transactions.any? }
    @year_end_statements = @credit_card_account.credit_card_statements
      .includes(:credit_card_transactions)
      .order(statement_year: :desc, created_at: :desc)
    txns = @credit_card_account.all_credit_card_transactions
    @category_totals = txns.group(:category, :subcategory).sum(:amount_cents)
    @total_spend_cents = txns.sum(:amount_cents)
    @transaction_count = txns.count
    trailing_three_year_spend_cents = txns.where(date: (Date.current - 3.years)..).sum(:amount_cents)
    @three_year_avg_spend_cents = (trailing_three_year_spend_cents / 3.0).round
  end
end


