# frozen_string_literal: true

require "test_helper"

class CreditCardStatementsTest < ActionDispatch::IntegrationTest
  test "import credit card CSV shows summary and transactions" do
    upload = csv_upload(<<~CSV, "cc.csv")
      date|category|subcategory|description|location|amount
      2025-03-01|Merchandise|Clothing|STORE A|CITY, ST|12.34
      2025-06-15|Travel and Transportation|Hotels|HOTEL|JONESBORO, AR|100.00
    CSV

    assert_difference -> { CreditCardStatement.count }, 1 do
      post credit_card_statements_path, params: { file: upload }
    end

    statement = CreditCardStatement.order(:id).last
    assert_redirected_to credit_card_statement_path(statement)
    follow_redirect!

    assert_response :success
    assert_match(/Imported 2 transactions/, flash[:notice])
    assert_match "2025", response.body
    assert_match "Merchandise", response.body
    assert_match "Hotels", response.body
    assert_match "$112.34", response.body

    get credit_card_statement_transactions_path(statement)
    assert_response :success
    assert_match "STORE A", response.body
    assert_match "HOTEL", response.body
    assert_match "$12.34", response.body
  end

  test "destroy removes credit card statement" do
    result = CreditCardStatements::Importer.call(
      io: StringIO.new(<<~CSV),
        date|category|subcategory|description|location|amount
        2025-03-01|Merchandise|Clothing|STORE A|CITY, ST|12.34
      CSV
      filename: "cc.csv"
    )

    assert_difference -> { CreditCardStatement.count }, -1 do
      delete credit_card_statement_path(result.statement)
    end
    assert_redirected_to credit_card_statements_path
  end

  private

  def csv_upload(contents, filename)
    path = File.join(Dir.mktmpdir, filename)
    File.write(path, contents)
    Rack::Test::UploadedFile.new(path, "text/csv")
  end
end
