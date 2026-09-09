# frozen_string_literal: true

module CreditCardStatements
  class TransactionsController < ApplicationController
    def index
      @credit_card_statement = CreditCardStatement.find(params[:credit_card_statement_id])
      base = @credit_card_statement.credit_card_transactions
      @total_count = base.count
      @transactions = CreditCardTransaction.apply_filters(base, filter_params).order(:date, :id)
      @categories = base.distinct.order(:category).pluck(:category)
      @subcategories = base.distinct.order(:subcategory).pluck(:subcategory)
      @filtered = filter_params.values.any?(&:present?)
    end

    private

    def filter_params
      params.permit(:date_from, :date_to, :category, :subcategory, :description, :amount)
    end
  end
end
