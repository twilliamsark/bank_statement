# frozen_string_literal: true

module MonthlyCreditCardStatements
  class AutoReconcilesController < ApplicationController
    def create
      statement = MonthlyCreditCardStatement.find(params[:monthly_credit_card_statement_id])
      result = UnreconciledTransactions::AutoReconcile.call(monthly_credit_card_statement: statement)

      redirect_to monthly_credit_card_statement_unreconciled_transactions_path(statement),
                  notice: auto_reconcile_notice(result)
    end

    private

    def auto_reconcile_notice(result)
      if result.reconciled_count.zero?
        "Auto Reconcile filled 0 transactions (#{result.examined_count} examined)."
      else
        "Auto Reconcile filled #{result.reconciled_count} of #{result.examined_count} examined transactions."
      end
    end
  end
end
