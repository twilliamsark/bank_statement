# frozen_string_literal: true

module MonthlyCreditCardStatements
  class UnreconciledTransactionsController < ApplicationController
    before_action :set_monthly_credit_card_statement
    before_action :set_category_options
    before_action :set_unreconciled_transaction, only: :update

    def index
      load_unreconciled_index
    end

    def update
      @unreconciled_transaction.update!(unreconciled_transaction_params)
      load_unreconciled_index

      respond_to do |format|
        format.turbo_stream
        format.html do
          redirect_to monthly_credit_card_statement_unreconciled_transactions_path(@monthly_credit_card_statement)
        end
      end
    end

    private

    def set_monthly_credit_card_statement
      @monthly_credit_card_statement = MonthlyCreditCardStatement
        .includes(:credit_card_account)
        .find(params[:monthly_credit_card_statement_id])
    end

    def set_unreconciled_transaction
      @unreconciled_transaction = @monthly_credit_card_statement.unreconciled_transactions
        .find(params[:id])
    end

    def set_category_options
      @categories = CreditCardTransaction.distinct.order(:category).pluck(:category)
      @subcategories_by_category = CreditCardTransaction
        .distinct
        .order(:category, :subcategory)
        .pluck(:category, :subcategory)
        .group_by(&:first)
        .transform_values { |pairs| pairs.map(&:last) }
    end

    def load_unreconciled_index
      @unreconciled_transactions = @monthly_credit_card_statement
        .unreconciled_transactions
        .order(:date, :id)
      @ready_to_save_count = @unreconciled_transactions.count { |txn| txn.category.present? && txn.subcategory.present? }
    end

    def unreconciled_transaction_params
      params.require(:unreconciled_transaction).permit(:category, :subcategory).to_h.transform_values(&:presence)
    end
  end
end
