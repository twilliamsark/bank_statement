# frozen_string_literal: true

class AccountsController < ApplicationController
  def index
    @accounts = Account.order(:name).includes(:account_statements, :account_transactions)
    @unassigned_statement_count = AccountStatement.where(account_id: nil).count
  end

  def show
    @account = Account.find(params[:id])
    @statements = @account.account_statements
      .includes(:account_transactions)
      .order(period_end: :desc, period_start: :desc, id: :desc)
    @section_totals = @account.account_transactions.group(:section).sum(:amount_cents)
    @balance_rollup = Accounts::BalanceRollup.call(@statements)
  end
end
