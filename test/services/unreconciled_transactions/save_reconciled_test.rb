# frozen_string_literal: true

require "test_helper"

class UnreconciledTransactions::SaveReconciledTest < ActiveSupport::TestCase
  setup do
    @account = create_credit_card_account!(name: "Travel Card")
    @monthly = MonthlyCreditCardStatement.create!(
      credit_card_account: @account,
      source_filename: "monthly.csv",
      import_format: "csv"
    )
  end

  test "creates credit card transactions for categorized staging rows and destroys them" do
    ready = create_staging!(
      description: "HOTEL",
      amount_cents: 10000,
      category: "Travel and Transportation",
      subcategory: "Hotels"
    )
    leftover = create_staging!(description: "UNKNOWN", amount_cents: 500)

    result = UnreconciledTransactions::SaveReconciled.call(monthly_credit_card_statement: @monthly)

    assert_equal 1, result.saved_count
    assert_equal 1, result.remaining_count
    assert_not UnreconciledTransaction.exists?(ready.id)
    assert UnreconciledTransaction.exists?(leftover.id)

    committed = @monthly.credit_card_transactions.find_by!(description: "HOTEL")
    assert_nil committed.credit_card_statement_id
    assert_equal @monthly.id, committed.monthly_credit_card_statement_id
    assert_equal "Travel and Transportation", committed.category
    assert_equal "Hotels", committed.subcategory
    assert_equal "", committed.location
    assert_equal 10000, committed.amount_cents
    assert committed.checksum.present?
    assert committed.import_fingerprint.present?
  end

  test "no-ops when no staging rows are categorized" do
    create_staging!(description: "UNKNOWN", amount_cents: 500)

    assert_no_difference -> { CreditCardTransaction.count } do
      result = UnreconciledTransactions::SaveReconciled.call(monthly_credit_card_statement: @monthly)
      assert_equal 0, result.saved_count
      assert_equal 1, result.remaining_count
    end
  end

  test "account all_credit_card_transactions includes monthly committed rows" do
    create_staging!(
      description: "STORE",
      amount_cents: 1234,
      category: "Merchandise",
      subcategory: "Clothing"
    )
    UnreconciledTransactions::SaveReconciled.call(monthly_credit_card_statement: @monthly)

    assert_equal 1, @account.all_credit_card_transactions.count
    assert_equal 0, @account.credit_card_transactions.count
    assert_equal 1, @account.monthly_credit_card_transactions.count
  end

  private

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
