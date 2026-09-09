# frozen_string_literal: true

require "test_helper"

class CreditCardTransactionTest < ActiveSupport::TestCase
  setup do
    @statement = CreditCardStatement.create!(
      credit_card_account: create_credit_card_account!,
      statement_year: 2025,
      source_filename: "cc.csv",
      import_format: "csv"
    )
  end

  test "requires core fields" do
    txn = CreditCardTransaction.new(credit_card_statement: @statement)
    assert_not txn.valid?
    assert_includes txn.errors[:date], "can't be blank"
    assert_includes txn.errors[:description], "can't be blank"
    assert_includes txn.errors[:amount_cents], "can't be blank"
    assert_includes txn.errors[:category], "can't be blank"
    assert_includes txn.errors[:subcategory], "can't be blank"
  end

  test "allows blank location string" do
    txn = @statement.credit_card_transactions.create!(
      date: Date.new(2025, 6, 1),
      description: "ONLINE",
      location: "",
      amount_cents: 2500,
      category: "Services",
      subcategory: "Other Services"
    )

    assert_equal "", txn.location
    assert txn.checksum.present?
  end

  test "checksum_for is stable and includes location" do
    attrs = {
      date: Date.new(2025, 6, 1),
      category: "Travel and Transportation",
      subcategory: "Hotels",
      description: "HOTEL",
      location: "JONESBORO, AR",
      amount_cents: 10000
    }

    assert_equal(
      CreditCardTransaction.checksum_for(**attrs),
      CreditCardTransaction.checksum_for(**attrs)
    )
    assert_not_equal(
      CreditCardTransaction.checksum_for(**attrs),
      CreditCardTransaction.checksum_for(**attrs, location: "OTHER, ST")
    )
  end

  test "allows multiple rows with the same checksum" do
    attrs = {
      date: Date.new(2025, 1, 15),
      description: "COFFEE",
      location: "CITY, ST",
      amount_cents: 450,
      category: "Merchandise",
      subcategory: "Restaurants"
    }
    checksum = CreditCardTransaction.checksum_for(**attrs)

    assert_difference -> { CreditCardTransaction.count }, 2 do
      2.times { @statement.credit_card_transactions.create!(attrs.merge(checksum: checksum)) }
    end
  end
end
