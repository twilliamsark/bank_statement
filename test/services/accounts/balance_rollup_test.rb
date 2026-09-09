# frozen_string_literal: true

require "test_helper"

class Accounts::BalanceRollupTest < ActiveSupport::TestCase
  test "uses earliest beginning and latest ending and sums flows" do
    early = AccountStatement.new(
      period_start: Date.new(2026, 1, 1),
      period_end: Date.new(2026, 1, 31),
      beginning_balance_cents: 100,
      ending_balance_cents: 150,
      deposits_cents: 60,
      withdrawals_cents: -10,
      interest_paid_ytd_cents: 1,
      apy_earned: BigDecimal("0.01")
    )
    late = AccountStatement.new(
      period_start: Date.new(2026, 2, 1),
      period_end: Date.new(2026, 2, 28),
      beginning_balance_cents: 150,
      ending_balance_cents: 200,
      deposits_cents: 40,
      withdrawals_cents: -20,
      interest_paid_ytd_cents: 5,
      apy_earned: BigDecimal("0.02")
    )

    result = Accounts::BalanceRollup.call([ early, late ])

    assert_equal 100, result.beginning_balance_cents
    assert_equal 200, result.ending_balance_cents
    assert_equal 100, result.deposits_cents
    assert_equal(-30, result.withdrawals_cents)
    assert_equal 5, result.interest_paid_ytd_cents
    assert_equal BigDecimal("0.02"), result.apy_earned
  end
end
