# frozen_string_literal: true

require "test_helper"

class AccountsTest < ActionDispatch::IntegrationTest
  setup do
    @number = "0057 4568 7822"
    @other_number = "1111 2222 3333"

    @jan = AccountStatement.create!(
      account_name: "Your Savings",
      account_number: @number,
      period_start: Date.new(2026, 1, 1),
      period_end: Date.new(2026, 1, 31),
      source_filename: "jan.pdf",
      import_format: "pdf"
    )
    @jan.account_transactions.create!(
      date: Date.new(2026, 1, 5),
      description: "Interest Earned",
      amount_cents: 2,
      section: "Deposits and other additions"
    )
    @jan.account_transactions.create!(
      date: Date.new(2026, 1, 10),
      description: "ACH Withdrawal",
      amount_cents: -2500,
      section: "Withdrawals and other subtractions"
    )

    @feb = AccountStatement.create!(
      account_name: "Your Savings",
      account_number: "005745687822", # same account, spacing variant
      period_start: Date.new(2026, 2, 1),
      period_end: Date.new(2026, 2, 28),
      source_filename: "feb.pdf",
      import_format: "pdf"
    )
    @feb.account_transactions.create!(
      date: Date.new(2026, 2, 3),
      description: "Payroll Deposit",
      amount_cents: 1234,
      section: "Deposits and other additions"
    )

    @other = AccountStatement.create!(
      account_name: "Other Checking",
      account_number: @other_number,
      period_start: Date.new(2026, 1, 1),
      period_end: Date.new(2026, 1, 31),
      source_filename: "other.pdf",
      import_format: "pdf"
    )
    @other.account_transactions.create!(
      date: Date.new(2026, 1, 8),
      description: "Other Only",
      amount_cents: 500,
      section: "Deposits and other additions"
    )

    @csv_only = AccountStatement.create!(
      source_filename: "hollow.csv",
      import_format: "csv"
    )
    @csv_only.account_transactions.create!(
      date: Date.new(2026, 1, 1),
      description: "CSV Only",
      amount_cents: 100,
      section: "Deposits and other additions"
    )

    @account = AccountSummary.find_by_param!(Accounts::Id.encode(@number))
  end

  test "index lists accounts with numbers and notes csv-only statements" do
    get accounts_path
    assert_response :success
    assert_match "Your Savings", response.body
    assert_match @number, response.body
    assert_match "Other Checking", response.body
    assert_no_match(/CSV Only/, response.body)
    assert_match(/without an account number/, response.body)
    assert_select "a[href=?]", account_statements_path
  end

  test "master transactions include all statements for the account" do
    get account_transactions_path(@account)
    assert_response :success
    assert_match "Interest Earned", response.body
    assert_match "Payroll Deposit", response.body
    assert_match "ACH Withdrawal", response.body
    assert_no_match(/Other Only/, response.body)
    assert_no_match(/CSV Only/, response.body)
    assert_match(/3 transactions/, response.body)
    assert_select "a[href=?]", account_statement_path(@jan)
    assert_select "a[href=?]", account_statement_path(@feb)
  end

  test "master filters by section" do
    get account_transactions_path(@account), params: { section: "Deposits and other additions" }
    assert_response :success
    assert_match "Interest Earned", response.body
    assert_match "Payroll Deposit", response.body
    assert_no_match(/ACH Withdrawal/, response.body)
    assert_match(/Total/i, response.body)
    assert_match "$12.36", response.body # 0.02 + 12.34
  end

  test "master pagination and filter total" do
    55.times do |i|
      @jan.account_transactions.create!(
        date: Date.new(2026, 1, 20),
        description: "Bulk #{i}",
        amount_cents: 100,
        section: "Withdrawals and other subtractions",
        checksum: "bulk-#{i}"
      )
    end

    get account_transactions_path(@account)
    assert_response :success
    assert_match(/page 1 of 2/, response.body)
    assert_select "a", text: "Next"

    get account_transactions_path(@account), params: { page: 2 }
    assert_response :success
    assert_match(/page 2 of 2/, response.body)

    get account_transactions_path(@account), params: { section: "Withdrawals and other subtractions" }
    assert_response :success
    # original ACH -$25.00 + 55 × $1.00 = $30.00 (filter total across all pages)
    assert_match "$30.00", response.body
    assert_match(/56 matching transactions/, response.body)
  end

  test "master filters by description" do
    get account_transactions_path(@account), params: { description: "payroll" }
    assert_response :success
    assert_match "Payroll Deposit", response.body
    assert_no_match(/Interest Earned/, response.body)
  end

  test "master filters by amount" do
    get account_transactions_path(@account), params: { amount: "12.3" }
    assert_response :success
    assert_match "Payroll Deposit", response.body
    assert_no_match(/Interest Earned/, response.body)
  end

  test "master filters by date range across statements" do
    get account_transactions_path(@account),
        params: { date_from: "2026-02-01", date_to: "2026-02-28" }
    assert_response :success
    assert_match "Payroll Deposit", response.body
    assert_no_match(/Interest Earned/, response.body)
  end

  test "nav distinguishes accounts and statements" do
    get root_path
    assert_response :success
    assert_select "a[href=?]", accounts_path, text: "Accounts"
    assert_select "a[href=?]", account_statements_path, text: "Statements"
  end
end
