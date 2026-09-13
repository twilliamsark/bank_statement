# frozen_string_literal: true

module CreditCardAccounts
  class TransactionsController < ApplicationController
    before_action :set_credit_card_account
    before_action :set_edit_category_options
    before_action :set_transaction, only: :update

    def index
      load_transactions_index
    end

    def update
      attrs = credit_card_transaction_params
      if attrs[:category].blank? || attrs[:subcategory].blank?
        return respond_with_validation_error("Category and subcategory are required.")
      end

      @transaction.update!(attrs)
      load_transactions_index

      respond_to do |format|
        format.turbo_stream
        format.html do
          redirect_to credit_card_account_transactions_path(@credit_card_account, filter_params.to_h.compact_blank)
        end
      end
    end

    private

    def set_credit_card_account
      @credit_card_account = CreditCardAccount.find(params[:credit_card_account_id])
    end

    def set_transaction
      @transaction = @credit_card_account.all_credit_card_transactions.find(params[:id])
    end

    def set_edit_category_options
      pairs = CreditCardTransaction.distinct.order(:category, :subcategory).pluck(:category, :subcategory)
      @edit_categories = pairs.map(&:first).uniq
      @subcategories_by_category = pairs
        .group_by(&:first)
        .transform_values { |rows| rows.map(&:last).uniq }
    end


    def load_transactions_index
      base = @credit_card_account.all_credit_card_transactions
      @total_count = base.count
      filtered = CreditCardTransaction.apply_filters(base, filter_params)
      @filtered_count = filtered.count
      @amount_total_cents = filtered.sum(:amount_cents)
      @pagination = Pagination.new(page: params[:page], total_count: @filtered_count)
      @transactions = filtered
        .includes(:credit_card_statement, :monthly_credit_card_statement)
        .order(:date, :id)
        .offset(@pagination.offset)
        .limit(@pagination.limit)
      @categories = base.distinct.order(:category).pluck(:category)
      @subcategories = base.distinct.order(:subcategory).pluck(:subcategory)
      @filtered = filter_params.to_h.values.any?(&:present?)
    end

    def filter_params
      params.permit(:date_from, :date_to, :category, :subcategory, :description, :amount)
    end

    def credit_card_transaction_params
      params.require(:credit_card_transaction).permit(:category, :subcategory).to_h.transform_values(&:presence)
    end

    def respond_with_validation_error(message)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            helpers.dom_id(@transaction),
            partial: "credit_card_accounts/transactions/row",
            locals: { txn: @transaction }
          ), status: :unprocessable_entity

        end
        format.html do
          redirect_to credit_card_account_transactions_path(@credit_card_account, filter_params.to_h.compact_blank),
                      alert: message
        end
      end
    end
  end
end
