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

  test "pagination includes jump-to-page select and honors page param" do
    statement = @year_two
    55.times do |i|
      statement.credit_card_transactions.create!(
        date: Date.new(2025, 3, 1),
        description: "PAGE JUMP ROW #{i}",
        location: "",
        amount_cents: 100 + i,
        category: "Merchandise",
        subcategory: "Clothing"
      )
    end

    get credit_card_account_transactions_path(@account)
    assert_response :success
    assert_select "select#pagination_page"
    assert_select "select#pagination_page option", minimum: 2
    assert_match "PAGE JUMP ROW 0", response.body

    get credit_card_account_transactions_path(@account), params: { page: 2 }
    assert_response :success
    assert_select "select#pagination_page option[selected]", text: "2"
    assert_match(/Showing 51/, response.body)
  end

  test "account show links to master transactions" do
    get credit_card_account_path(@account)
    assert_response :success
    assert_select "a[href=?]", credit_card_account_transactions_path(@account)
  end

  test "index renders editable category subcategory text fields with suggestions" do
    get credit_card_account_transactions_path(@account)
    assert_response :success
    assert_select "input[name=?]", "credit_card_transaction[category]"
    assert_select "input[name=?]", "credit_card_transaction[subcategory]"
    assert_select "datalist option[value=?]", "Merchandise"
  end


  test "patch updates category subcategory and checksum for year-end row" do
    txn = @year_one.credit_card_transactions.find_by!(description: "STORE A")
    original_checksum = txn.checksum

    patch credit_card_account_transaction_path(@account, txn), params: {
      credit_card_transaction: { category: "Services", subcategory: "Other Services" }
    }
    assert_redirected_to credit_card_account_transactions_path(@account)

    txn.reload
    assert_equal "Services", txn.category
    assert_equal "Other Services", txn.subcategory
    assert_not_equal original_checksum, txn.checksum
  end

  test "patch updates monthly-backed row on the same account" do
    monthly = MonthlyCreditCardStatement.create!(
      credit_card_account: @account,
      source_filename: "monthly.csv",
      import_format: "csv"
    )
    txn = monthly.credit_card_transactions.create!(
      date: Date.new(2025, 8, 1),
      description: "MONTHLY STORE",
      location: "",
      amount_cents: 2200,
      category: "Merchandise",
      subcategory: "Clothing"
    )

    patch credit_card_account_transaction_path(@account, txn), params: {
      credit_card_transaction: { category: "Travel and Transportation", subcategory: "Hotels" }
    }
    assert_redirected_to credit_card_account_transactions_path(@account)

    txn.reload
    assert_equal "Travel and Transportation", txn.category
    assert_equal "Hotels", txn.subcategory
  end

  test "patch rejects blank category or subcategory" do
    txn = @year_one.credit_card_transactions.find_by!(description: "STORE A")

    patch credit_card_account_transaction_path(@account, txn), params: {
      credit_card_transaction: { category: "Services", subcategory: "" }
    }
    assert_redirected_to credit_card_account_transactions_path(@account)
    assert_equal "Category and subcategory are required.", flash[:alert]

    txn.reload
    assert_equal "Merchandise", txn.category
    assert_equal "Clothing", txn.subcategory
  end

  test "cannot patch transaction belonging to another credit card account" do
    other_txn = @other.credit_card_transactions.find_by!(description: "OTHER ONLY")

    patch credit_card_account_transaction_path(@account, other_txn), params: {
      credit_card_transaction: { category: "Services", subcategory: "Other Services" }
    }
    assert_response :not_found

    other_txn.reload
    assert_equal "Merchandise", other_txn.category
    assert_equal "Clothing", other_txn.subcategory
  end

  test "patch accepts free-text category and subcategory" do
    txn = @year_one.credit_card_transactions.find_by!(description: "STORE A")
    original_checksum = txn.checksum

    patch credit_card_account_transaction_path(@account, txn), params: {
      credit_card_transaction: { category: "  Brand New Category  ", subcategory: "  Brand New Sub  " }
    }
    assert_redirected_to credit_card_account_transactions_path(@account)

    txn.reload
    assert_equal "Brand New Category", txn.category
    assert_equal "Brand New Sub", txn.subcategory
    assert_not_equal original_checksum, txn.checksum

    get credit_card_account_transactions_path(@account)
    assert_select "datalist option[value=?]", "Brand New Category"
  end
end



