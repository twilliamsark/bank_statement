# frozen_string_literal: true

require "test_helper"

class AccountTransactionTest < ActiveSupport::TestCase
  setup do
    @statement = AccountStatement.create!(
      source_filename: "checking.csv",
      import_format: "csv"
    )
  end

  test "belongs to statement and requires core fields" do
    txn = AccountTransaction.new(account_statement: @statement)
    assert_not txn.valid?
    assert_includes txn.errors[:date], "can't be blank"
    assert_includes txn.errors[:description], "can't be blank"
    assert_includes txn.errors[:amount_cents], "can't be blank"
    assert_includes txn.errors[:section], "can't be blank"
  end

  test "checksum_for is stable for the same inputs" do
    attrs = {
      date: Date.new(2026, 1, 9),
      section: "Withdrawals and other subtractions",
      description: "ACH Withdrawal",
      amount_cents: -2500
    }

    first = AccountTransaction.checksum_for(**attrs)
    second = AccountTransaction.checksum_for(**attrs)

    assert_equal 64, first.length
    assert_equal first, second
  end

  test "checksum_for changes when amount changes" do
    base = {
      date: Date.new(2026, 1, 9),
      section: "Deposits and other additions",
      description: "Interest",
      amount_cents: 2
    }

    assert_not_equal(
      AccountTransaction.checksum_for(**base),
      AccountTransaction.checksum_for(**base, amount_cents: 3)
    )
  end

  test "assigns checksum before validation when blank" do
    txn = @statement.account_transactions.create!(
      date: Date.new(2026, 1, 9),
      description: "Interest Earned",
      amount_cents: 2,
      section: "Deposits and other additions"
    )

    assert_equal(
      AccountTransaction.checksum_for(
        date: txn.date,
        section: txn.section,
        description: txn.description,
        amount_cents: txn.amount_cents
      ),
      txn.checksum
    )
  end

  test "allows multiple rows with the same checksum" do
    attrs = {
      date: Date.new(2026, 1, 9),
      description: "Duplicate line",
      amount_cents: -100,
      section: "Withdrawals and other subtractions"
    }
    checksum = AccountTransaction.checksum_for(
      date: attrs[:date],
      section: attrs[:section],
      description: attrs[:description],
      amount_cents: attrs[:amount_cents]
    )

    assert_difference -> { AccountTransaction.count }, 2 do
      2.times do
        @statement.account_transactions.create!(attrs.merge(checksum: checksum))
      end
    end

    assert_equal 2, AccountTransaction.where(checksum: checksum).count
  end

  test "uses account_transactions table" do
    assert_equal "account_transactions", AccountTransaction.table_name
  end
end
