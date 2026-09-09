# frozen_string_literal: true

require "test_helper"

class CreditCardAccountSummaryTest < ActionDispatch::IntegrationTest
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
      CSV
      filename: "cc-2025.csv",
      credit_card_account: @account
    ).statement

    CreditCardStatements::Importer.call(
      io: StringIO.new(<<~CSV),
        date|category|subcategory|description|location|amount
        2025-03-01|Merchandise|Clothing|OTHER ONLY|CITY, ST|999.00
      CSV
      filename: "other.csv",
      credit_card_account: @other
    )
  end

  test "show rolls up spend and categories across statements" do
    get credit_card_account_path(@account)
    assert_response :success

    assert_match "Travel Card", response.body
    assert_match "2024–2025", response.body
    assert_match "$157.34", response.body # 12.34 + 100 + 45
    assert_no_match(/\$999\.00/, response.body)

    assert_match "Merchandise", response.body
    assert_match "Clothing", response.body
    assert_match "$57.34", response.body # 12.34 + 45
    assert_match "Hotels", response.body
    assert_match "$100.00", response.body

    assert_select "a[href=?]", credit_card_statement_path(@year_one)
    assert_select "a[href=?]", credit_card_statement_path(@year_two)
    assert_select "a[href=?]", credit_card_account_transactions_path(@account)
  end

  test "index view links to summary show" do
    get credit_card_accounts_path
    assert_response :success
    assert_select "a[href=?]", credit_card_account_path(@account), text: "View"
  end
end
