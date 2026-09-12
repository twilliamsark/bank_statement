# frozen_string_literal: true

require "test_helper"

class CreditCardTransactionParentTest < ActiveSupport::TestCase
  setup do
    @account = create_credit_card_account!(name: "Travel Card")
    @year_end = CreditCardStatement.create!(
      credit_card_account: @account,
      statement_year: 2025,
      source_filename: "year_end.csv",
      import_format: "csv"
    )
    @monthly = MonthlyCreditCardStatement.create!(
      credit_card_account: @account,
      source_filename: "monthly.csv",
      import_format: "csv"
    )
  end

  test "accepts year-end parent only" do
    txn = CreditCardTransaction.new(
      credit_card_statement: @year_end,
      date: Date.new(2025, 1, 1),
      description: "STORE",
      location: "",
      amount_cents: 100,
      category: "Merchandise",
      subcategory: "Clothing"
    )
    assert txn.valid?
  end

  test "accepts monthly parent only" do
    txn = CreditCardTransaction.new(
      monthly_credit_card_statement: @monthly,
      date: Date.new(2025, 1, 1),
      description: "STORE",
      location: "",
      amount_cents: 100,
      category: "Merchandise",
      subcategory: "Clothing"
    )
    assert txn.valid?
  end

  test "rejects both parents present" do
    txn = CreditCardTransaction.new(
      credit_card_statement: @year_end,
      monthly_credit_card_statement: @monthly,
      date: Date.new(2025, 1, 1),
      description: "STORE",
      location: "",
      amount_cents: 100,
      category: "Merchandise",
      subcategory: "Clothing"
    )
    assert_not txn.valid?
    assert_includes txn.errors[:base].join, "exactly one"
  end

  test "rejects both parents missing" do
    txn = CreditCardTransaction.new(
      date: Date.new(2025, 1, 1),
      description: "STORE",
      location: "",
      amount_cents: 100,
      category: "Merchandise",
      subcategory: "Clothing"
    )
    assert_not txn.valid?
    assert_includes txn.errors[:base].join, "exactly one"
  end
end
