# frozen_string_literal: true

class CreditCardStatementsController < ApplicationController
  before_action :set_credit_card_statement, only: %i[show destroy]

  def index
    @credit_card_statements = CreditCardStatement.order(created_at: :desc)
      .includes(:credit_card_transactions, :credit_card_account)
    if params[:credit_card_account_id].present?
      @credit_card_account = CreditCardAccount.find(params[:credit_card_account_id])
      @credit_card_statements = @credit_card_statements.where(credit_card_account_id: @credit_card_account.id)
    end
  end

  def show
    @category_totals = @credit_card_statement.credit_card_transactions
      .group(:category, :subcategory)
      .sum(:amount_cents)
  end

  def new
    @credit_card_accounts = CreditCardAccount.order(:name)
    @selected_account_id = params[:credit_card_account_id]
    @account_mode = @credit_card_accounts.any? && @selected_account_id.blank? ? "existing" : (@selected_account_id.present? ? "existing" : "new")
    @account_mode = "existing" if @selected_account_id.present?
    @account_mode = "new" if @credit_card_accounts.empty?
  end

  def create
    upload = params[:file]
    if upload.blank?
      redirect_to new_credit_card_statement_path(credit_card_account_id: params[:credit_card_account_id]),
                  alert: "Please choose a PDF or CSV file to import."
      return
    end

    result = import_with_account!(upload)
    redirect_to credit_card_statement_path(result.statement), notice: import_notice(result)
  rescue Imports::Error, ActiveRecord::RecordNotFound => e
    redirect_to new_credit_card_statement_path(credit_card_account_id: params[:credit_card_account_id]),
                alert: e.message
  end

  def destroy
    @credit_card_statement.destroy!
    redirect_to credit_card_statements_path, notice: "Credit card statement deleted."
  end

  private

  def set_credit_card_statement
    @credit_card_statement = CreditCardStatement.find(params[:id])
  end

  def import_with_account!(upload)
    case params[:account_mode]
    when "existing"
      account = CreditCardAccount.find(params[:credit_card_account_id])
      CreditCardStatements::Importer.call(
        io: upload,
        filename: upload.original_filename,
        credit_card_account: account
      )
    when "new"
      CreditCardStatements::Importer.call(
        io: upload,
        filename: upload.original_filename,
        credit_card_account_name: params[:new_account_name]
      )
    else
      raise Imports::Error, "Please choose an existing credit card or enter a new name."
    end
  end

  def import_notice(result)
    if result.imported_count.zero? && result.skipped_duplicate_count.positive?
      "No new transactions (#{result.skipped_duplicate_count} skipped as duplicates)."
    else
      "Imported #{result.imported_count} transactions (#{result.skipped_duplicate_count} skipped as duplicates)."
    end
  end
end
