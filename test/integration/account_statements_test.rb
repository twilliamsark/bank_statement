# frozen_string_literal: true

require "test_helper"

class AccountStatementsTest < ActionDispatch::IntegrationTest
  test "home links to account statements" do
    get root_path
    assert_response :success
    assert_select "a[href=?]", account_statements_path
  end

  test "import account CSV shows summary and transactions" do
    upload = csv_upload(<<~CSV, "account.csv")
      date|section|description|amount
      2026-01-02|Deposits and other additions|Interest Earned|0.02
      2026-01-03|Withdrawals and other subtractions|ACH Withdrawal|-25.00
    CSV

    assert_difference -> { AccountStatement.count }, 1 do
      post account_statements_path, params: { file: upload }
    end

    statement = AccountStatement.order(:id).last
    assert_redirected_to account_statement_path(statement)
    follow_redirect!

    assert_response :success
    assert_match(/Imported 2 transactions/, flash[:notice])
    assert_select "h1", text: "—"
    assert_match(/Summary balances unavailable from CSV/, response.body)
    assert_match(/Interest Earned|Deposits and other additions|Withdrawals/, response.body)
    assert_select "a[href=?]", account_statement_transactions_path(statement)

    get account_statement_transactions_path(statement)
    assert_response :success
    assert_match "Interest Earned", response.body
    assert_match "ACH Withdrawal", response.body
    assert_match "$0.02", response.body
    assert_match "-$25.00", response.body
  end

  test "destroy removes statement" do
    result = AccountStatements::Importer.call(
      io: StringIO.new(<<~CSV),
        date|section|description|amount
        2026-01-02|Deposits and other additions|Interest Earned|0.02
      CSV
      filename: "account.csv"
    )

    assert_difference -> { AccountStatement.count }, -1 do
      delete account_statement_path(result.statement)
    end
    assert_redirected_to account_statements_path
  end

  test "missing file shows alert" do
    post account_statements_path, params: {}
    assert_redirected_to new_account_statement_path
    follow_redirect!
    assert_match(/Please choose a PDF or CSV/, flash[:alert])
  end

  private

  def csv_upload(contents, filename)
    path = File.join(Dir.mktmpdir, filename)
    File.write(path, contents)
    Rack::Test::UploadedFile.new(path, "text/csv")
  end
end
