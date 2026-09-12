# frozen_string_literal: true

module MonthlyCreditCardStatements
  class UnreconciledTransactionsController < ApplicationController
    def index
      @monthly_credit_card_statement = MonthlyCreditCardStatement
        .includes(:credit_card_account)
        .find(params[:monthly_credit_card_statement_id])
      @unreconciled_transactions = @monthly_credit_card_statement
        .unreconciled_transactions
        .order(:date, :id)
    end
  end
end
