# frozen_string_literal: true

require "test_helper"

class AccountStatementTransactionsFilterTest < ActionDispatch::IntegrationTest
  setup do
    result = AccountStatements::Importer.call(
      io: StringIO.new(<<~CSV),
        date|section|description|amount
        2026-01-02|Deposits and other additions|Interest Earned|0.02
        2026-01-15|Withdrawals and other subtractions|ACH Withdrawal|-25.34
        2026-02-01|Deposits and other additions|Payroll Deposit|12.34
      CSV
      filename: "account.csv"
    )
    @statement = result.statement
  end

  test "lists all transactions without filters" do
    get account_statement_transactions_path(@statement)
    assert_response :success
    assert_match "Interest Earned", response.body
    assert_match "ACH Withdrawal", response.body
    assert_match "Payroll Deposit", response.body
    assert_match(/3 transactions/, response.body)
  end

  test "filters by section" do
    get account_statement_transactions_path(@statement), params: { section: "Deposits and other additions" }
    assert_response :success
    assert_match "Interest Earned", response.body
    assert_match "Payroll Deposit", response.body
    assert_no_match(/ACH Withdrawal/, response.body)
    assert_match(/2 matches of 3 transactions/, response.body)
  end

  test "filters by date range" do
    get account_statement_transactions_path(@statement),
        params: { date_from: "2026-01-01", date_to: "2026-01-31" }
    assert_response :success
    assert_match "Interest Earned", response.body
    assert_match "ACH Withdrawal", response.body
    assert_no_match(/Payroll Deposit/, response.body)
  end

  test "filters by description partial" do
    get account_statement_transactions_path(@statement), params: { description: "payroll" }
    assert_response :success
    assert_match "Payroll Deposit", response.body
    assert_no_match(/Interest Earned/, response.body)
  end

  test "filters by amount dollar partial" do
    get account_statement_transactions_path(@statement), params: { amount: "12.3" }
    assert_response :success
    assert_match "Payroll Deposit", response.body
    assert_no_match(/Interest Earned/, response.body)
    assert_no_match(/ACH Withdrawal/, response.body)
  end

  test "clear filters link present when filtered" do
    get account_statement_transactions_path(@statement), params: { description: "pay" }
    assert_response :success
    assert_select "a", text: "Clear filters"
  end
end
