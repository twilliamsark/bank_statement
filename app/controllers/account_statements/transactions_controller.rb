# frozen_string_literal: true

module AccountStatements
  class TransactionsController < ApplicationController
    def index
      @account_statement = AccountStatement.find(params[:account_statement_id])
      base = @account_statement.account_transactions
      @total_count = base.count
      @transactions = AccountTransaction.apply_filters(base, filter_params).order(:date, :id)
      @sections = base.distinct.order(:section).pluck(:section)
      @filtered = filter_params.values.any?(&:present?)
    end

    private

    def filter_params
      params.permit(:date_from, :date_to, :section, :description, :amount)
    end
  end
end
