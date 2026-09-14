# frozen_string_literal: true

require "test_helper"

class UnreconciledTransactionTest < ActiveSupport::TestCase
  setup do
    @statement = MonthlyCreditCardStatement.create!(
      credit_card_account: create_credit_card_account!,
      source_filename: "monthly.csv",
      import_format: "csv"
    )
  end

  test "belongs to monthly statement and allows blank category subcategory" do
    txn = @statement.unreconciled_transactions.create!(
      date: Date.new(2025, 3, 1),
      description: "STORE A",
      amount_cents: 1234
    )

    assert_equal @statement, txn.monthly_credit_card_statement
    assert_nil txn.category
    assert_nil txn.subcategory
    assert txn.import_fingerprint.present?
  end

  test "import_fingerprint uses 21-char description prefix" do
    description = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    expected = Digest::MD5.hexdigest(
      [ "2025-03-01", description[0, 21], 1234 ].join("|")
    )

    assert_equal 21, description[0, 21].length
    assert_equal expected, UnreconciledTransaction.import_fingerprint_for(
      date: Date.new(2025, 3, 1),
      description: description,
      amount_cents: 1234
    )

    txn = @statement.unreconciled_transactions.create!(
      date: Date.new(2025, 3, 1),
      description: description,
      amount_cents: 1234
    )
    assert_equal expected, txn.import_fingerprint
  end

  test "requires core fields" do
    txn = UnreconciledTransaction.new(monthly_credit_card_statement: @statement)
    assert_not txn.valid?
    assert_includes txn.errors[:date], "can't be blank"
    assert_includes txn.errors[:description], "can't be blank"
    assert_includes txn.errors[:amount_cents], "can't be blank"
  end

  test "strips free-text category labels and allows blank" do
    txn = @statement.unreconciled_transactions.create!(
      date: Date.new(2025, 3, 1),
      description: "STORE A",
      amount_cents: 1234,
      category: "  New Cat  ",
      subcategory: "  New Sub  "
    )
    assert_equal "New Cat", txn.category
    assert_equal "New Sub", txn.subcategory

    txn.update!(category: "   ", subcategory: nil)
    assert_nil txn.category
    assert_nil txn.subcategory
  end

  test "clears subcategory when category is blank" do
    txn = @statement.unreconciled_transactions.create!(
      date: Date.new(2025, 3, 1),
      description: "STORE A",
      amount_cents: 1234,
      category: "Merchandise",
      subcategory: "Clothing"
    )

    txn.update!(category: "", subcategory: "Clothing")
    assert_nil txn.category
    assert_nil txn.subcategory
  end

  test "ready_to_save requires categories and no potential duplicate flag" do
    txn = @statement.unreconciled_transactions.create!(
      date: Date.new(2025, 3, 1),
      description: "STORE A",
      amount_cents: 1234,
      category: "Merchandise",
      subcategory: "Clothing",
      potential_duplicate: true
    )

    assert_not txn.ready_to_save?

    txn.update!(potential_duplicate: false)
    assert txn.ready_to_save?
  end
end


