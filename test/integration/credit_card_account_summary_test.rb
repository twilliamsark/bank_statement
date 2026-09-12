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

  test "show lists monthly statements above year-end and links to unreconciled" do
    older = MonthlyCreditCardStatement.create!(
      credit_card_account: @account,
      source_filename: "older-monthly.csv",
      import_format: "csv",
      period_end: Date.new(2025, 6, 30),
      created_at: 2.days.ago
    )
    older.unreconciled_transactions.create!(
      date: Date.new(2025, 6, 1),
      description: "OLD STAGING",
      amount_cents: 100
    )

    newer = MonthlyCreditCardStatement.create!(
      credit_card_account: @account,
      source_filename: "newer-monthly.csv",
      import_format: "csv",
      period_end: Date.new(2025, 8, 31),
      created_at: 1.day.ago
    )
    newer.unreconciled_transactions.create!(
      date: Date.new(2025, 8, 1),
      description: "NEW STAGING",
      amount_cents: 200
    )

    get credit_card_account_path(@account)
    assert_response :success

    headings = response.body.scan(%r{<h2[^>]*>(.*?)</h2>}m).flatten.map { |html| html.gsub(/<[^>]+>/, "").strip }
    monthly_idx = headings.index("Monthly statements")
    year_end_idx = headings.index("Year-end statements")
    assert monthly_idx, "expected Monthly statements heading"
    assert year_end_idx, "expected Year-end statements heading"
    assert_operator monthly_idx, :<, year_end_idx

    assert_select "a[href=?]", monthly_credit_card_statement_unreconciled_transactions_path(newer),
                  text: "View Unreconciled Transactions"
    assert_select "a[href=?]", monthly_credit_card_statement_unreconciled_transactions_path(newer),
                  text: "View Unreconciled"
    assert_select "a[href=?]", monthly_credit_card_statement_unreconciled_transactions_path(older),
                  text: "View Unreconciled"
    assert_match "newer-monthly.csv", response.body
    assert_match "older-monthly.csv", response.body
  end

  test "show hides top unreconciled button when no staging rows remain" do
    MonthlyCreditCardStatement.create!(
      credit_card_account: @account,
      source_filename: "empty-monthly.csv",
      import_format: "csv"
    )

    get credit_card_account_path(@account)
    assert_response :success
    assert_select "a", text: "View Unreconciled Transactions", count: 0
  end
end
