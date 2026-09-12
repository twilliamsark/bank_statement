# frozen_string_literal: true

require "test_helper"

class UnreconciledTransactions::AutoReconcileTest < ActiveSupport::TestCase
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

  test "fills category and subcategory from unanimous same-account year-end match" do
    create_year_end_txn!(
      description: "HOTEL STAY DOWNTOWN ABC EXTRA",
      amount_cents: 10000,
      category: "Travel and Transportation",
      subcategory: "Hotels"
    )
    staging = create_staging!(
      description: "HOTEL STAY DOWNTOWN ABC MONTHLY",
      amount_cents: 10000
    )

    result = UnreconciledTransactions::AutoReconcile.call(monthly_credit_card_statement: @monthly)

    assert_equal 1, result.examined_count
    assert_equal 1, result.reconciled_count
    staging.reload
    assert_equal "Travel and Transportation", staging.category
    assert_equal "Hotels", staging.subcategory
  end

  test "leaves row unchanged when no candidates match" do
    staging = create_staging!(description: "UNKNOWN MERCHANT", amount_cents: 999)

    result = UnreconciledTransactions::AutoReconcile.call(monthly_credit_card_statement: @monthly)

    assert_equal 1, result.examined_count
    assert_equal 0, result.reconciled_count
    staging.reload
    assert_nil staging.category
    assert_nil staging.subcategory
  end

  test "leaves row unchanged when year-end matches disagree on category pair" do
    create_year_end_txn!(
      description: "STORE PREFIX SHARED XYZ",
      amount_cents: 2500,
      category: "Merchandise",
      subcategory: "Clothing"
    )
    create_year_end_txn!(
      description: "STORE PREFIX SHARED ABC",
      amount_cents: 2500,
      category: "Merchandise",
      subcategory: "Electronics"
    )
    staging = create_staging!(description: "STORE PREFIX SHARED MONTHLY", amount_cents: 2500)

    result = UnreconciledTransactions::AutoReconcile.call(monthly_credit_card_statement: @monthly)

    assert_equal 0, result.reconciled_count
    staging.reload
    assert_nil staging.category
    assert_nil staging.subcategory
  end

  test "fills when multiple year-end matches agree on the same pair" do
    create_year_end_txn!(
      description: "COFFEE SHOP MAIN STREET A",
      amount_cents: 450,
      category: "Merchandise",
      subcategory: "Restaurants"
    )
    create_year_end_txn!(
      description: "COFFEE SHOP MAIN STREET B",
      amount_cents: 450,
      category: "Merchandise",
      subcategory: "Restaurants"
    )
    staging = create_staging!(description: "COFFEE SHOP MAIN STREET C", amount_cents: 450)

    result = UnreconciledTransactions::AutoReconcile.call(monthly_credit_card_statement: @monthly)

    assert_equal 1, result.reconciled_count
    staging.reload
    assert_equal "Merchandise", staging.category
    assert_equal "Restaurants", staging.subcategory
  end

  test "skips rows that already have both category and subcategory" do
    create_year_end_txn!(
      description: "ALREADY FILLED MERCHANT XX",
      amount_cents: 1200,
      category: "Services",
      subcategory: "Other Services"
    )
    staging = create_staging!(
      description: "ALREADY FILLED MERCHANT YY",
      amount_cents: 1200,
      category: "Merchandise",
      subcategory: "Clothing"
    )

    result = UnreconciledTransactions::AutoReconcile.call(monthly_credit_card_statement: @monthly)

    assert_equal 0, result.examined_count
    assert_equal 1, result.skipped_count
    staging.reload
    assert_equal "Merchandise", staging.category
    assert_equal "Clothing", staging.subcategory
  end

  test "does not match year-end transactions from a different credit card account" do
    other = create_credit_card_account!(name: "Other Card")
    other_statement = CreditCardStatement.create!(
      credit_card_account: other,
      statement_year: 2025,
      source_filename: "other.csv",
      import_format: "csv"
    )
    other_statement.credit_card_transactions.create!(
      date: Date.new(2025, 1, 1),
      description: "SHARED PREFIX MERCHANT AA",
      location: "",
      amount_cents: 3300,
      category: "Travel and Entertainment",
      subcategory: "Airlines"
    )
    staging = create_staging!(description: "SHARED PREFIX MERCHANT BB", amount_cents: 3300)

    result = UnreconciledTransactions::AutoReconcile.call(monthly_credit_card_statement: @monthly)

    assert_equal 0, result.reconciled_count
    staging.reload
    assert_nil staging.category
    assert_nil staging.subcategory
  end

  private

  def create_year_end_txn!(description:, amount_cents:, category:, subcategory:)
    @year_end.credit_card_transactions.create!(
      date: Date.new(2025, 2, 1),
      description: description,
      location: "",
      amount_cents: amount_cents,
      category: category,
      subcategory: subcategory
    )
  end

  def create_staging!(description:, amount_cents:, category: nil, subcategory: nil)
    @monthly.unreconciled_transactions.create!(
      date: Date.new(2025, 8, 1),
      description: description,
      amount_cents: amount_cents,
      category: category,
      subcategory: subcategory
    )
  end
end
