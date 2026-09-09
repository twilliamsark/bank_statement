# frozen_string_literal: true

module CreditCardStatements
  class TransactionsController < ApplicationController
    def index
      @credit_card_statement = CreditCardStatement.find(params[:credit_card_statement_id])
      @transactions = @credit_card_statement.credit_card_transactions.order(:date, :id)
    end
  end
end
