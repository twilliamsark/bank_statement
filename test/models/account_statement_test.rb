# frozen_string_literal: true

require "test_helper"

class AccountStatementTest < ActiveSupport::TestCase
  test "has many transactions and destroys them" do
    statement = AccountStatement.create!(
      source_filename: "checking.csv",
      import_format: "csv"
    )
    statement.account_transactions.create!(
      date: Date.new(2026, 1, 2),
      description: "Deposit",
      amount_cents: 1000,
      section: "Deposits and other additions"
    )

    assert_difference -> { AccountTransaction.count }, -1 do
      statement.destroy!
    end
  end

  test "can attach a source file" do
    statement = AccountStatement.create!(import_format: "pdf", source_filename: "a.pdf")
    statement.source_file.attach(
      io: StringIO.new("%PDF-1.4"),
      filename: "a.pdf",
      content_type: "application/pdf"
    )

    assert statement.source_file.attached?
  end

  test "rejects invalid import_format" do
    statement = AccountStatement.new(import_format: "xlsx")
    assert_not statement.valid?
    assert_includes statement.errors[:import_format], "is not included in the list"
  end

  test "uses account_statements table" do
    assert_equal "account_statements", AccountStatement.table_name
  end
end
