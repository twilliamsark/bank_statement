# frozen_string_literal: true

require "test_helper"

class MonthlyCreditCardStatementsTest < ActionDispatch::IntegrationTest
  test "credit cards index shows year-end and monthly import CTAs" do
    get credit_card_accounts_path
    assert_response :success
    assert_select "a[href=?]", new_credit_card_statement_path, text: "Import Year End Statement"
    assert_select "a[href=?]", new_monthly_credit_card_statement_path, text: "Import Monthly Statement"
  end

  test "import monthly CSV with new account redirects to unreconciled list" do
    upload = csv_upload(<<~CSV, "monthly.csv")
      transaction_date|posting_date|section|description|reference_number|amount
      2025-03-01|2025-03-02|Purchases and Adjustments|STORE A|REF1|12.34
      2025-06-15|2025-06-16|Purchases and Adjustments|HOTEL|REF2|100.00
    CSV

    assert_difference -> { CreditCardAccount.count }, 1 do
      assert_difference -> { MonthlyCreditCardStatement.count }, 1 do
        assert_difference -> { UnreconciledTransaction.count }, 2 do
          post monthly_credit_card_statements_path, params: {
            file: upload,
            account_mode: "new",
            new_account_name: "Travel Card"
          }
        end
      end
    end

    statement = MonthlyCreditCardStatement.order(:id).last
    assert_redirected_to monthly_credit_card_statement_unreconciled_transactions_path(statement)
    follow_redirect!

    assert_response :success
    assert_match(/Staged 2 transactions/, flash[:notice])
    assert_match "STORE A", response.body
    assert_match "HOTEL", response.body
    assert_select "select[name=?]", "unreconciled_transaction[category]"
    assert_select "select[name=?] option[value='']", "unreconciled_transaction[category]"
    assert_select "select[name=?] option[value='']", "unreconciled_transaction[subcategory]"
  end

  test "import with existing account reuses it" do
    account = create_credit_card_account!(name: "Sapphire")
    upload = csv_upload(<<~CSV, "monthly.csv")
      transaction_date|posting_date|section|description|reference_number|amount
      2025-03-01|2025-03-02|Purchases and Adjustments|STORE A|REF1|12.34
    CSV

    assert_no_difference -> { CreditCardAccount.count } do
      post monthly_credit_card_statements_path, params: {
        file: upload,
        account_mode: "existing",
        credit_card_account_id: account.id
      }
    end

    assert_equal account.id, MonthlyCreditCardStatement.order(:id).last.credit_card_account_id
  end

  test "patching category and subcategory enables save reconciled" do
    account = create_credit_card_account!(name: "Travel Card")
    year_end = CreditCardStatement.create!(
      credit_card_account: account,
      statement_year: 2025,
      source_filename: "year_end.csv",
      import_format: "csv"
    )
    year_end.credit_card_transactions.create!(
      date: Date.new(2025, 1, 10),
      description: "SEED CATEGORY ROW",
      location: "",
      amount_cents: 100,
      category: "Merchandise",
      subcategory: "Clothing"
    )
    year_end.credit_card_transactions.create!(
      date: Date.new(2025, 1, 11),
      description: "SEED CATEGORY ROW TWO",
      location: "",
      amount_cents: 200,
      category: "Merchandise",
      subcategory: "Electronics"
    )

    monthly = MonthlyCreditCardStatement.create!(
      credit_card_account: account,
      source_filename: "monthly.csv",
      import_format: "csv"
    )
    staging = monthly.unreconciled_transactions.create!(
      date: Date.new(2025, 8, 10),
      description: "NEEDS MANUAL CATEGORY",
      amount_cents: 2500
    )

    get monthly_credit_card_statement_unreconciled_transactions_path(monthly)
    assert_response :success
    assert_select "select[name=?]", "unreconciled_transaction[category]"
    assert_select "select[name=?]", "unreconciled_transaction[subcategory]"
    assert_select "form[action=?]", monthly_credit_card_statement_save_reconciled_path(monthly), count: 0

    patch monthly_credit_card_statement_unreconciled_transaction_path(monthly, staging), params: {
      unreconciled_transaction: { category: "Merchandise", subcategory: "Clothing" }
    }
    assert_response :redirect
    follow_redirect!
    staging.reload
    assert_equal "Merchandise", staging.category
    assert_equal "Clothing", staging.subcategory
    assert_select "form[action=?]", monthly_credit_card_statement_save_reconciled_path(monthly)

    patch monthly_credit_card_statement_unreconciled_transaction_path(monthly, staging), params: {
      unreconciled_transaction: { category: "Merchandise", subcategory: "" }
    }
    follow_redirect!
    staging.reload
    assert_equal "Merchandise", staging.category
    assert_nil staging.subcategory

    patch monthly_credit_card_statement_unreconciled_transaction_path(monthly, staging), params: {
      unreconciled_transaction: { category: "Merchandise", subcategory: "Electronics" }
    }
    follow_redirect!

    assert_difference -> { CreditCardTransaction.where(monthly_credit_card_statement_id: monthly.id).count }, 1 do
      assert_difference -> { UnreconciledTransaction.count }, -1 do
        post monthly_credit_card_statement_save_reconciled_path(monthly)
      end
    end
    assert_redirected_to monthly_credit_card_statement_unreconciled_transactions_path(monthly)
  end

  test "unreconciled list shows guidance when no categories exist" do
    account = create_credit_card_account!(name: "Empty Card")
    monthly = MonthlyCreditCardStatement.create!(
      credit_card_account: account,
      source_filename: "monthly.csv",
      import_format: "csv"
    )
    monthly.unreconciled_transactions.create!(
      date: Date.new(2025, 8, 10),
      description: "NO OPTIONS YET",
      amount_cents: 100
    )

    get monthly_credit_card_statement_unreconciled_transactions_path(monthly)
    assert_response :success
    assert_match(/Import a year-end statement first/, response.body)
  end

  test "save reconciled commits categorized staging rows" do
    account = create_credit_card_account!(name: "Travel Card")
    monthly = MonthlyCreditCardStatement.create!(
      credit_card_account: account,
      source_filename: "monthly.csv",
      import_format: "csv"
    )
    monthly.unreconciled_transactions.create!(
      date: Date.new(2025, 8, 10),
      description: "HOTEL READY",
      amount_cents: 10000,
      category: "Travel and Transportation",
      subcategory: "Hotels"
    )
    monthly.unreconciled_transactions.create!(
      date: Date.new(2025, 8, 11),
      description: "STILL OPEN",
      amount_cents: 500
    )

    get monthly_credit_card_statement_unreconciled_transactions_path(monthly)
    assert_response :success
    assert_select "form[action=?]", monthly_credit_card_statement_save_reconciled_path(monthly)

    assert_difference -> { CreditCardTransaction.count }, 1 do
      assert_difference -> { UnreconciledTransaction.count }, -1 do
        post monthly_credit_card_statement_save_reconciled_path(monthly)
      end
    end

    assert_redirected_to monthly_credit_card_statement_unreconciled_transactions_path(monthly)
    follow_redirect!
    assert_match(/Saved 1 transactions/, flash[:notice])
    assert_match "STILL OPEN", response.body
    assert_no_match(/HOTEL READY/, response.body)

    committed = CreditCardTransaction.find_by!(description: "HOTEL READY")
    assert_equal monthly.id, committed.monthly_credit_card_statement_id
    assert_nil committed.credit_card_statement_id
  end

  test "auto reconcile fills matching categories on unreconciled list" do
    account = create_credit_card_account!(name: "Travel Card")
    year_end = CreditCardStatement.create!(
      credit_card_account: account,
      statement_year: 2025,
      source_filename: "year_end.csv",
      import_format: "csv"
    )
    year_end.credit_card_transactions.create!(
      date: Date.new(2025, 1, 10),
      description: "HOTEL STAY DOWNTOWN ABC YEAR END",
      location: "",
      amount_cents: 10000,
      category: "Travel and Transportation",
      subcategory: "Hotels"
    )

    monthly = MonthlyCreditCardStatement.create!(
      credit_card_account: account,
      source_filename: "monthly.csv",
      import_format: "csv"
    )
    monthly.unreconciled_transactions.create!(
      date: Date.new(2025, 8, 10),
      description: "HOTEL STAY DOWNTOWN ABC MONTHLY",
      amount_cents: 10000
    )

    get monthly_credit_card_statement_unreconciled_transactions_path(monthly)
    assert_response :success
    assert_select "form[action=?]", monthly_credit_card_statement_auto_reconcile_path(monthly)

    post monthly_credit_card_statement_auto_reconcile_path(monthly)
    assert_redirected_to monthly_credit_card_statement_unreconciled_transactions_path(monthly)
    follow_redirect!

    assert_match(/Auto Reconcile filled 1/, flash[:notice])
    assert_match "Travel and Transportation", response.body
    assert_match "Hotels", response.body
  end

  private

  def csv_upload(contents, filename)
    path = File.join(Dir.mktmpdir, filename)
    File.write(path, contents)
    Rack::Test::UploadedFile.new(path, "text/csv")
  end
end
