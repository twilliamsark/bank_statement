# frozen_string_literal: true

module Accounts
  class TransactionsController < ApplicationController
    def index
      @account = Account.find(params[:account_id])
      base = @account.account_transactions
      @total_count = base.count
      filtered = AccountTransaction.apply_filters(base, filter_params)
      @filtered_count = filtered.count
      @amount_total_cents = filtered.sum(:amount_cents)
      @pagination = Pagination.new(page: params[:page], total_count: @filtered_count)
      @transactions = filtered
        .includes(:account_statement)
        .order(:date, :id)
        .offset(@pagination.offset)
        .limit(@pagination.limit)
      @sections = base.distinct.order(:section).pluck(:section)
      @filtered = filter_params.values.any?(&:present?)
    end

    private

    def filter_params
      params.permit(:date_from, :date_to, :section, :description, :amount)
    end
  end
end
