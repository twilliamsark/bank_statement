# frozen_string_literal: true

class CreditCardAccountsController < ApplicationController
  def index
    @credit_card_accounts = CreditCardAccount.order(:name)
      .includes(:credit_card_statements, :credit_card_transactions)
  end

  def show
    @credit_card_account = CreditCardAccount.find(params[:id])
    @statements = @credit_card_account.credit_card_statements
      .includes(:credit_card_transactions)
      .order(statement_year: :desc, created_at: :desc)
    txns = @credit_card_account.credit_card_transactions
    @category_totals = txns.group(:category, :subcategory).sum(:amount_cents)
    @total_spend_cents = txns.sum(:amount_cents)
    @transaction_count = txns.count
    years = @statements.filter_map(&:statement_year)
    @years_covered = years.minmax if years.any?
  end
end
