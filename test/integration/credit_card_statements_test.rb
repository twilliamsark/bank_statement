# frozen_string_literal: true

require "test_helper"

class CreditCardStatementsTest < ActionDispatch::IntegrationTest
  test "import credit card CSV with new account name" do
    upload = csv_upload(<<~CSV, "cc.csv")
      date|category|subcategory|description|location|amount
      2025-03-01|Merchandise|Clothing|STORE A|CITY, ST|12.34
      2025-06-15|Travel and Transportation|Hotels|HOTEL|JONESBORO, AR|100.00
    CSV

    assert_difference -> { CreditCardAccount.count }, 1 do
      assert_difference -> { CreditCardStatement.count }, 1 do
        post credit_card_statements_path, params: {
          file: upload,
          account_mode: "new",
          new_account_name: "Travel Card"
        }
      end
    end

    statement = CreditCardStatement.order(:id).last
    assert_equal "Travel Card", statement.credit_card_account.name
    assert_redirected_to credit_card_statement_path(statement)
    follow_redirect!

    assert_response :success
    assert_match(/Imported 2 transactions/, flash[:notice])
    assert_match "Travel Card", response.body
    assert_match "2025", response.body
    assert_match "Merchandise", response.body
    assert_match "$112.34", response.body
  end

  test "import with existing account reuses it" do
    account = create_credit_card_account!(name: "Sapphire")
    upload = csv_upload(<<~CSV, "cc.csv")
      date|category|subcategory|description|location|amount
      2025-03-01|Merchandise|Clothing|STORE A|CITY, ST|12.34
    CSV

    assert_no_difference -> { CreditCardAccount.count } do
      post credit_card_statements_path, params: {
        file: upload,
        account_mode: "existing",
        credit_card_account_id: account.id
      }
    end

    assert_equal account.id, CreditCardStatement.order(:id).last.credit_card_account_id
  end

  test "missing account choice shows alert" do
    upload = csv_upload(<<~CSV, "cc.csv")
      date|category|subcategory|description|location|amount
      2025-03-01|Merchandise|Clothing|STORE A|CITY, ST|12.34
    CSV

    assert_no_difference -> { CreditCardStatement.count } do
      post credit_card_statements_path, params: { file: upload, account_mode: "new", new_account_name: "" }
    end
    assert_redirected_to new_credit_card_statement_path
    follow_redirect!
    assert_match(/required|name/i, flash[:alert])
  end

  test "destroy removes credit card statement" do
    result = CreditCardStatements::Importer.call(
      io: StringIO.new(<<~CSV),
        date|category|subcategory|description|location|amount
        2025-03-01|Merchandise|Clothing|STORE A|CITY, ST|12.34
      CSV
      filename: "cc.csv",
      credit_card_account_name: "Travel Card"
    )

    assert_difference -> { CreditCardStatement.count }, -1 do
      delete credit_card_statement_path(result.statement)
    end
    assert_redirected_to credit_card_statements_path
  end

  test "credit cards nav points at accounts index" do
    get root_path
    assert_response :success
    assert_select "a[href=?]", credit_card_accounts_path, text: "Credit cards"
  end

  private

  def csv_upload(contents, filename)
    path = File.join(Dir.mktmpdir, filename)
    File.write(path, contents)
    Rack::Test::UploadedFile.new(path, "text/csv")
  end
end
