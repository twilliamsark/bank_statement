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
  end
end
