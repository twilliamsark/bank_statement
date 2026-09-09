# frozen_string_literal: true

require "test_helper"

class AccountTransactionFilterTest < ActiveSupport::TestCase
  setup do
    @statement = AccountStatement.create!(source_filename: "a.csv", import_format: "csv")
    @interest = @statement.account_transactions.create!(
      date: Date.new(2026, 1, 2),
      description: "Interest Earned",
      amount_cents: 2,
      section: "Deposits and other additions"
    )
    @withdrawal = @statement.account_transactions.create!(
      date: Date.new(2026, 1, 15),
      description: "ACH Withdrawal STORE",
      amount_cents: -2534,
      section: "Withdrawals and other subtractions"
    )
    @deposit = @statement.account_transactions.create!(
      date: Date.new(2026, 2, 1),
      description: "Payroll",
      amount_cents: 1234,
      section: "Deposits and other additions"
    )
  end

  test "filters by date range inclusively" do
    result = AccountTransaction.apply_filters(
      @statement.account_transactions,
      { date_from: "2026-01-02", date_to: "2026-01-15" }
    )
    assert_equal [ @interest.id, @withdrawal.id ].sort, result.pluck(:id).sort
  end

  test "filters by section" do
    result = AccountTransaction.apply_filters(
      @statement.account_transactions,
      { section: "Deposits and other additions" }
    )
    assert_equal [ @interest.id, @deposit.id ].sort, result.pluck(:id).sort
  end

  test "filters description case-insensitively" do
    result = AccountTransaction.apply_filters(
      @statement.account_transactions,
      { description: "interest" }
    )
    assert_equal [ @interest.id ], result.pluck(:id)
  end

  test "filters amount by dollar display partial" do
    result = AccountTransaction.apply_filters(
      @statement.account_transactions,
      { amount: "12.3" }
    )
    assert_equal [ @deposit.id ], result.pluck(:id)

    negative = AccountTransaction.apply_filters(
      @statement.account_transactions,
      { amount: "-25.3" }
    )
    assert_equal [ @withdrawal.id ], negative.pluck(:id)
  end

  test "combines filters with AND" do
    result = AccountTransaction.apply_filters(
      @statement.account_transactions,
      {
        section: "Deposits and other additions",
        description: "Pay"
      }
    )
    assert_equal [ @deposit.id ], result.pluck(:id)
  end
end
