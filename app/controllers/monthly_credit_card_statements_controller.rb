# frozen_string_literal: true

class MonthlyCreditCardStatementsController < ApplicationController
  before_action :set_monthly_credit_card_statement, only: %i[show destroy]

  def index
    @monthly_credit_card_statements = MonthlyCreditCardStatement.order(created_at: :desc)
      .includes(:credit_card_account, :unreconciled_transactions, :credit_card_transactions)
    if params[:credit_card_account_id].present?
      @credit_card_account = CreditCardAccount.find(params[:credit_card_account_id])
      @monthly_credit_card_statements = @monthly_credit_card_statements
        .where(credit_card_account_id: @credit_card_account.id)
    end
  end

  def show
    @category_totals = @monthly_credit_card_statement.credit_card_transactions
      .group(:category, :subcategory)
      .sum(:amount_cents)
    @unreconciled_count = @monthly_credit_card_statement.unreconciled_transactions.count
    @committed_count = @monthly_credit_card_statement.credit_card_transactions.count
  end

  def new
    @credit_card_accounts = CreditCardAccount.order(:name)
    @selected_account_id = params[:credit_card_account_id]
    @account_mode = if @credit_card_accounts.empty?
      "new"
    elsif @selected_account_id.present?
      "existing"
    else
      "existing"
    end
  end

  def create
    upload = params[:file]
    if upload.blank?
      redirect_to new_monthly_credit_card_statement_path(credit_card_account_id: params[:credit_card_account_id]),
                  alert: "Please choose a PDF or CSV file to import."
      return
    end

    result = import_with_account!(upload)
    redirect_to monthly_credit_card_statement_unreconciled_transactions_path(result.statement),
                notice: import_notice(result)
  rescue Imports::Error, ActiveRecord::RecordNotFound => e
    redirect_to new_monthly_credit_card_statement_path(credit_card_account_id: params[:credit_card_account_id]),
                alert: e.message
  end

  def destroy
    @monthly_credit_card_statement.destroy!
    redirect_to monthly_credit_card_statements_path, notice: "Monthly credit card statement deleted."
  end

  private

  def set_monthly_credit_card_statement
    @monthly_credit_card_statement = MonthlyCreditCardStatement
      .includes(:credit_card_account)
      .find(params[:id])
  end

  def import_with_account!(upload)
    case params[:account_mode]
    when "existing"
      account = CreditCardAccount.find(params[:credit_card_account_id])
      MonthlyCreditCardStatements::Importer.call(
        io: upload,
        filename: upload.original_filename,
        credit_card_account: account
      )
    when "new"
      MonthlyCreditCardStatements::Importer.call(
        io: upload,
        filename: upload.original_filename,
        credit_card_account_name: params[:new_account_name]
      )
    else
      raise Imports::Error, "Please choose an existing credit card or enter a new name."
    end
  end

  def import_notice(result)
    notice = "Staged #{result.staged_count} transactions for reconciliation."
    if result.potential_duplicate_count.positive?
      count = result.potential_duplicate_count
      label = count == 1 ? "potential duplicate" : "potential duplicates"
      notice += " #{count} #{label} flagged."
    end
    notice
  end
end
