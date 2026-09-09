# frozen_string_literal: true

require "test_helper"

class CreditCardAccountTransactionsTest < ActionDispatch::IntegrationTest
  setup do
    @account = create_credit_card_account!(name: "Travel Card")
    @other = create_credit_card_account!(name: "Other Card")

    @year_one = CreditCardStatements::Importer.call(
      io: StringIO.new(<<~CSV),
        date|category|subcategory|description|location|amount
        2024-03-01|Merchandise|Clothing|STORE A|CITY, ST|12.34
        2024-06-15|Travel and Transportation|Hotels|HOTEL 2024|JONESBORO, AR|100.00
      CSV
      filename: "cc-2024.csv",
      credit_card_account: @account
    ).statement

    @year_two = CreditCardStatements::Importer.call(
      io: StringIO.new(<<~CSV),
        date|category|subcategory|description|location|amount
        2025-01-15|Merchandise|Clothing|STORE B|CITY, ST|45.00
        2025-02-01|Services|Other Services|FEE|CITY, ST|5.00
      CSV
      filename: "cc-2025.csv",
      credit_card_account: @account
    ).statement

    CreditCardStatements::Importer.call(
      io: StringIO.new(<<~CSV),
        date|category|subcategory|description|location|amount
        2025-03-01|Merchandise|Clothing|OTHER ONLY|CITY, ST|9.00
      CSV
      filename: "other.csv",
      credit_card_account: @other
    )
  end

  test "master list unions statements for the card only" do
    get credit_card_account_transactions_path(@account)
    assert_response :success
    assert_match "STORE A", response.body
    assert_match "STORE B", response.body
    assert_match "HOTEL 2024", response.body
    assert_match "FEE", response.body
    assert_no_match(/OTHER ONLY/, response.body)
    assert_match(/4 transactions/, response.body)
    assert_select "a[href=?]", credit_card_statement_path(@year_one)
    assert_select "a[href=?]", credit_card_statement_path(@year_two)
    assert_match "$162.34", response.body # 12.34+100+45+5
  end

  test "filters by category across statements" do
    get credit_card_account_transactions_path(@account), params: { category: "Merchandise" }
    assert_response :success
    assert_match "STORE A", response.body
    assert_match "STORE B", response.body
    assert_no_match(/HOTEL 2024/, response.body)
    assert_no_match(/\bFEE\b/, response.body)
    assert_match "$57.34", response.body
  end

  test "filters by description" do
    get credit_card_account_transactions_path(@account), params: { description: "hotel" }
    assert_response :success
    assert_match "HOTEL 2024", response.body
    assert_no_match(/STORE A/, response.body)
  end

  test "filters by amount" do
    get credit_card_account_transactions_path(@account), params: { amount: "12.3" }
    assert_response :success
    assert_match "STORE A", response.body
    assert_no_match(/STORE B/, response.body)
  end

  test "account show links to master transactions" do
    get credit_card_account_path(@account)
    assert_response :success
    assert_select "a[href=?]", credit_card_account_transactions_path(@account)
  end
end
