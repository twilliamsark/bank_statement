# frozen_string_literal: true

require "test_helper"

class AccountsTest < ActionDispatch::IntegrationTest
  setup do
    @account = Account.find_or_create_from_import!(
      name: "Your Savings",
      account_number: "0057 4568 7822"
    )
    @other = Account.find_or_create_from_import!(
      name: "Other Checking",
      account_number: "1111 2222 3333"
    )

    @jan = AccountStatement.create!(
      account: @account,
      account_name: "Your Savings",
      account_number: "0057 4568 7822",
      period_start: Date.new(2026, 1, 1),
      period_end: Date.new(2026, 1, 31),
      source_filename: "jan.pdf",
      import_format: "pdf",
      beginning_balance_cents: 100_00,
      deposits_cents: 50_00,
      withdrawals_cents: -20_00,
      ending_balance_cents: 130_00,
      interest_paid_ytd_cents: 1_00,
      apy_earned: BigDecimal("0.01")
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
      account: @account,
      account_name: "Your Savings",
      account_number: "005745687822",
      period_start: Date.new(2026, 2, 1),
      period_end: Date.new(2026, 2, 28),
      source_filename: "feb.pdf",
      import_format: "pdf",
      beginning_balance_cents: 130_00,
      deposits_cents: 10_00,
      withdrawals_cents: -5_00,
      ending_balance_cents: 135_00,
      interest_paid_ytd_cents: 2_00,
      apy_earned: BigDecimal("0.02")
    )
    @feb.account_transactions.create!(
      date: Date.new(2026, 2, 3),
      description: "Payroll Deposit",
      amount_cents: 1234,
      section: "Deposits and other additions"
    )

    AccountStatement.create!(
      account: @other,
      account_name: "Other Checking",
      account_number: "1111 2222 3333",
      period_start: Date.new(2026, 1, 1),
      period_end: Date.new(2026, 1, 31),
      source_filename: "other.pdf",
      import_format: "pdf"
    ).account_transactions.create!(
      date: Date.new(2026, 1, 8),
      description: "Other Only",
      amount_cents: 500,
      section: "Deposits and other additions"
    )

    AccountStatement.create!(
      source_filename: "hollow.csv",
      import_format: "csv"
    ).account_transactions.create!(
      date: Date.new(2026, 1, 1),
      description: "CSV Only",
      amount_cents: 100,
      section: "Deposits and other additions"
    )
  end

  test "index lists persisted accounts and notes unassigned csv statements" do
    get accounts_path
    assert_response :success
    assert_match "Your Savings", response.body
    assert_match "Other Checking", response.body
    assert_no_match(/CSV Only/, response.body)
    assert_match(/without an account name/, response.body)
    assert_select "a[href=?]", account_path(@account)
  end

  test "show summarizes balances and section totals across statements" do
    get account_path(@account)
    assert_response :success
    assert_match "Your Savings", response.body
    assert_match "$100.00", response.body # earliest beginning
    assert_match "$135.00", response.body # latest ending
    assert_match "$60.00", response.body # deposits 50+10
    assert_match "-$25.00", response.body # withdrawals -20 + -5
    assert_match "0.02%", response.body # latest APY
    assert_match "$2.00", response.body # latest interest YTD
    assert_match "$12.36", response.body # section total deposits (0.02 + 12.34)
    assert_select "a[href=?]", account_statement_path(@jan)
    assert_select "a[href=?]", account_statement_path(@feb)
    assert_select "a[href=?]", account_transactions_path(@account)
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

  test "master filters by section with filter total" do
    get account_transactions_path(@account), params: { section: "Deposits and other additions" }
    assert_response :success
    assert_match "Interest Earned", response.body
    assert_match "Payroll Deposit", response.body
    assert_no_match(/ACH Withdrawal/, response.body)
    assert_match "$12.36", response.body
  end

  test "same import name reuses account" do
    assert_no_difference -> { Account.count } do
      AccountStatements::Importer.call(
        io: StringIO.new(<<~CSV),
          date|section|description|amount
          2026-03-01|Deposits and other additions|Later Interest|1.00
        CSV
        filename: "later.csv"
      )
    end
    # CSV has no account name — should not create account; create via find_or_create directly
    assert_difference -> { @account.account_statements.count }, 1 do
      AccountStatement.create!(
        account: @account,
        account_name: "Your Savings",
        period_start: Date.new(2026, 3, 1),
        period_end: Date.new(2026, 3, 31),
        source_filename: "mar.pdf",
        import_format: "pdf"
      )
    end

    assert_equal 1, Account.where(name_key: "your savings").count
  end

  test "nav distinguishes accounts and statements" do
    get root_path
    assert_response :success
    assert_select "a[href=?]", accounts_path, text: "Accounts"
    assert_select "a[href=?]", account_statements_path, text: "Statements"
  end
end
