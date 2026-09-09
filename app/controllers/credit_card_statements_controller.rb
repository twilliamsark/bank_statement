# frozen_string_literal: true

class CreditCardStatementsController < ApplicationController
  before_action :set_credit_card_statement, only: %i[show destroy]

  def index
    @credit_card_statements = CreditCardStatement.order(created_at: :desc).includes(:credit_card_transactions)
  end

  def show
    @category_totals = @credit_card_statement.credit_card_transactions
      .group(:category, :subcategory)
      .sum(:amount_cents)
  end

  def new
  end

  def create
    upload = params[:file]
    if upload.blank?
      redirect_to new_credit_card_statement_path, alert: "Please choose a PDF or CSV file to import."
      return
    end

    result = CreditCardStatements::Importer.call(io: upload, filename: upload.original_filename)
    redirect_to credit_card_statement_path(result.statement),
                notice: import_notice(result)
  rescue Imports::Error => e
    redirect_to new_credit_card_statement_path, alert: e.message
  end

  def destroy
    @credit_card_statement.destroy!
    redirect_to credit_card_statements_path, notice: "Credit card statement deleted."
  end

  private

  def set_credit_card_statement
    @credit_card_statement = CreditCardStatement.find(params[:id])
  end

  def import_notice(result)
    if result.imported_count.zero? && result.skipped_duplicate_count.positive?
      "No new transactions (#{result.skipped_duplicate_count} skipped as duplicates)."
    else
      "Imported #{result.imported_count} transactions (#{result.skipped_duplicate_count} skipped as duplicates)."
    end
  end
end
