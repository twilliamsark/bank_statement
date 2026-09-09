# frozen_string_literal: true

require "test_helper"

class CreditCardStatementTransactionsFilterTest < ActionDispatch::IntegrationTest
  setup do
    result = CreditCardStatements::Importer.call(
      io: StringIO.new(<<~CSV),
        date|category|subcategory|description|location|amount
        2025-03-01|Merchandise|Clothing|STORE A|CITY, ST|12.34
        2025-06-15|Travel and Transportation|Hotels|HOTEL STAY|JONESBORO, AR|100.00
        2025-07-01|Merchandise|Clothing|STORE B|CITY, ST|45.00
      CSV
      filename: "cc.csv",
      credit_card_account_name: "Travel Card"
    )
    @statement = result.statement
  end

  test "filters by category" do
    get credit_card_statement_transactions_path(@statement), params: { category: "Merchandise" }
    assert_response :success
    assert_match "STORE A", response.body
    assert_match "STORE B", response.body
    assert_no_match(/HOTEL STAY/, response.body)
  end

  test "filters by subcategory" do
    get credit_card_statement_transactions_path(@statement), params: { subcategory: "Hotels" }
    assert_response :success
    assert_match "HOTEL STAY", response.body
    assert_no_match(/STORE A/, response.body)
  end

  test "filters by amount partial" do
    get credit_card_statement_transactions_path(@statement), params: { amount: "12.3" }
    assert_response :success
    assert_match "STORE A", response.body
    assert_no_match(/HOTEL STAY/, response.body)
  end

  test "filters by description" do
    get credit_card_statement_transactions_path(@statement), params: { description: "hotel" }
    assert_response :success
    assert_match "HOTEL STAY", response.body
    assert_no_match(/STORE A/, response.body)
  end
end
