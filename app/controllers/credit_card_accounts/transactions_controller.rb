# frozen_string_literal: true

module CreditCardAccounts
  class TransactionsController < ApplicationController
    def index
      @credit_card_account = CreditCardAccount.find(params[:credit_card_account_id])
      base = @credit_card_account.credit_card_transactions
      @total_count = base.count
      filtered = CreditCardTransaction.apply_filters(base, filter_params)
      @filtered_count = filtered.count
      @amount_total_cents = filtered.sum(:amount_cents)
      @pagination = Pagination.new(page: params[:page], total_count: @filtered_count)
      @transactions = filtered
        .includes(:credit_card_statement)
        .order(:date, :id)
        .offset(@pagination.offset)
        .limit(@pagination.limit)
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
