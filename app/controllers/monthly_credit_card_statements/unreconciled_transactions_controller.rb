# frozen_string_literal: true

module MonthlyCreditCardStatements
  class UnreconciledTransactionsController < ApplicationController
    before_action :set_monthly_credit_card_statement
    before_action :set_edit_category_options
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
          redirect_to monthly_credit_card_statement_unreconciled_transactions_path(
            @monthly_credit_card_statement,
            filter_params.to_h.compact_blank
          )
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

    def set_edit_category_options
      @categories = CreditCardTransaction.distinct.order(:category).pluck(:category)
      @subcategories_by_category = CreditCardTransaction
        .distinct
        .order(:category, :subcategory)
        .pluck(:category, :subcategory)
        .group_by(&:first)
        .transform_values { |pairs| pairs.map(&:last) }
    end

    def load_unreconciled_index
      base = @monthly_credit_card_statement.unreconciled_transactions
      @total_count = base.count
      @ready_to_save_count = base.where.not(category: [ nil, "" ]).where.not(subcategory: [ nil, "" ]).count

      filtered = UnreconciledTransaction.apply_filters(base, filter_params)
      @filtered_count = filtered.count
      @amount_total_cents = filtered.sum(:amount_cents)
      @pagination = Pagination.new(page: params[:page], total_count: @filtered_count)
      @unreconciled_transactions = filtered.order(:date, :id)
        .offset(@pagination.offset)
        .limit(@pagination.limit)

      @filter_categories = base.where.not(category: [ nil, "" ]).distinct.order(:category).pluck(:category)
      @filter_subcategories = base.where.not(subcategory: [ nil, "" ]).distinct.order(:subcategory).pluck(:subcategory)
      @filtered = filter_params.to_h.values.any?(&:present?)
    end

    def filter_params
      params.permit(:date_from, :date_to, :category, :subcategory, :description, :amount)
    end

    def unreconciled_transaction_params
      params.require(:unreconciled_transaction).permit(:category, :subcategory).to_h.transform_values(&:presence)
    end
  end
end
