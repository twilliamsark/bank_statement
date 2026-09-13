# frozen_string_literal: true

require "test_helper"

class MonthlyCreditCardStatementSummaryTest < ActionDispatch::IntegrationTest
  setup do
    @account = create_credit_card_account!(name: "Travel Card")
    @statement = MonthlyCreditCardStatement.create!(
      credit_card_account: @account,
      source_filename: "monthly.csv",
      import_format: "csv",
      period_start: Date.new(2026, 8, 1),
      period_end: Date.new(2026, 8, 25),
      previous_balance_cents: 10000,
      payments_and_credits_cents: -5000,
      purchases_and_adjustments_cents: 7500,
      new_balance_cents: 12500
    )
    @statement.unreconciled_transactions.create!(
      date: Date.new(2026, 8, 10),
      description: "STORE A",
      amount_cents: 1234
    )
    @statement.credit_card_transactions.create!(
      date: Date.new(2026, 8, 11),
      description: "HOTEL",
      location: "",
      amount_cents: 5000,
      category: "Travel and Transportation",
      subcategory: "Hotels"
    )
  end

  test "index lists monthly statements and import CTA" do
    get monthly_credit_card_statements_path
    assert_response :success
    assert_select "a[href=?]", new_monthly_credit_card_statement_path, text: "Import Monthly Statement"
    assert_match "monthly.csv", response.body
    assert_select "a[href=?]", monthly_credit_card_statement_path(@statement), text: "View"
  end

  test "accounts index links to monthly statements list" do
    get credit_card_accounts_path
    assert_response :success
    assert_select "a[href=?]", monthly_credit_card_statements_path, text: "Monthly statements"
  end

  test "show renders summary and links" do
    get monthly_credit_card_statement_path(@statement)
    assert_response :success
    assert_match "Aug 2026 statement", response.body
    assert_match(/Payments &amp; credits/, response.body)
    assert_match "-$50.00", response.body
    assert_no_match(/Previous balance/, response.body)
    assert_no_match(/New balance/, response.body)
    assert_no_match(/Purchases &amp; adjustments/, response.body)
    assert_no_match(/Account &amp; credit/, response.body)
    assert_no_match(/Payment &amp; fees/, response.body)
    assert_match "Travel and Transportation", response.body
    assert_match "Hotels", response.body
    assert_select "a[href=?]", monthly_credit_card_statement_unreconciled_transactions_path(@statement)
    assert_select "a[href=?]", monthly_credit_card_statement_transactions_path(@statement)
  end

  test "show notes missing summary for csv without balances" do
    hollow = MonthlyCreditCardStatement.create!(
      credit_card_account: @account,
      source_filename: "hollow.csv",
      import_format: "csv"
    )

    get monthly_credit_card_statement_path(hollow)
    assert_response :success
    assert_match(/Summary balances unavailable from CSV/, response.body)
  end

  test "transactions index is scoped to the monthly statement" do
    get monthly_credit_card_statement_transactions_path(@statement)
    assert_response :success
    assert_match "HOTEL", response.body
    assert_no_match(/STORE A/, response.body)
  end

  test "destroy removes monthly statement" do
    assert_difference -> { MonthlyCreditCardStatement.count }, -1 do
      delete monthly_credit_card_statement_path(@statement)
    end
    assert_redirected_to monthly_credit_card_statements_path
  end
end
