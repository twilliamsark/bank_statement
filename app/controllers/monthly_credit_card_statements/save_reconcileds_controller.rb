# frozen_string_literal: true

module MonthlyCreditCardStatements
  class SaveReconciledsController < ApplicationController
    def create
      statement = MonthlyCreditCardStatement.find(params[:monthly_credit_card_statement_id])
      result = UnreconciledTransactions::SaveReconciled.call(monthly_credit_card_statement: statement)

      redirect_to monthly_credit_card_statement_unreconciled_transactions_path(statement),
                  notice: save_reconciled_notice(result)
    end

    private

    def save_reconciled_notice(result)
      if result.saved_count.zero?
        "No reconciled transactions to save."
      else
        "Saved #{result.saved_count} transactions (#{result.remaining_count} remaining unreconciled)."
      end
    end
  end
end
