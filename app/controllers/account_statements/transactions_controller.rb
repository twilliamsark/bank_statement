# frozen_string_literal: true

module AccountStatements
  class TransactionsController < ApplicationController
    def index
      @account_statement = AccountStatement.find(params[:account_statement_id])
      @transactions = @account_statement.account_transactions.order(:date, :id)
    end
  end
end
