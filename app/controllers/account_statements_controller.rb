# frozen_string_literal: true

class AccountStatementsController < ApplicationController
  before_action :set_account_statement, only: %i[show destroy]

  def index
    @account_statements = AccountStatement.order(created_at: :desc).includes(:account_transactions)
  end

  def show
    @section_totals = @account_statement.account_transactions.group(:section).sum(:amount_cents)
  end

  def new
  end

  def create
    upload = params[:file]
    if upload.blank?
      redirect_to new_account_statement_path, alert: "Please choose a PDF or CSV file to import."
      return
    end

    result = AccountStatements::Importer.call(io: upload, filename: upload.original_filename)
    redirect_to account_statement_path(result.statement),
                notice: import_notice(result)
  rescue Imports::Error => e
    redirect_to new_account_statement_path, alert: e.message
  end

  def destroy
    @account_statement.destroy!
    redirect_to account_statements_path, notice: "Account statement deleted."
  end

  private

  def set_account_statement
    @account_statement = AccountStatement.find(params[:id])
  end

  def import_notice(result)
    if result.imported_count.zero? && result.skipped_duplicate_count.positive?
      "No new transactions (#{result.skipped_duplicate_count} skipped as duplicates)."
    else
      "Imported #{result.imported_count} transactions (#{result.skipped_duplicate_count} skipped as duplicates)."
    end
  end
end
