# frozen_string_literal: true

require "test_helper"

class MonthlyCreditCardStatements::ImporterTest < ActiveSupport::TestCase
  MONTHLY_PDF = File.expand_path("~/Documents/boa/2026/cc_2026-08-25.pdf")

  test "imports monthly CSV into unreconciled transactions with blank categories" do
    path = write_csv(<<~CSV)
      transaction_date|posting_date|section|description|reference_number|amount
      2025-03-01|2025-03-02|Purchases and Adjustments|STORE A|REF1|12.34
      2025-06-15|2025-06-16|Purchases and Adjustments|HOTEL STAY DOWNTOWN ABC|REF2|100.00
      2025-07-01|2025-07-02|Payments and Other Credits|PAYMENT THANK YOU||-5.00
    CSV

    result = MonthlyCreditCardStatements::Importer.call(path: path, credit_card_account_name: "Travel Card")

    assert_equal 3, result.staged_count
    statement = result.statement
    assert_kind_of MonthlyCreditCardStatement, statement
    assert_equal "csv", statement.import_format
    assert_equal 3, statement.unreconciled_transactions.count
    assert statement.source_file.attached?

    hotel = statement.unreconciled_transactions.find_by!(description: "HOTEL STAY DOWNTOWN ABC")
    assert_equal Date.new(2025, 6, 15), hotel.date
    assert_equal 10000, hotel.amount_cents
    assert_nil hotel.category
    assert_nil hotel.subcategory
    assert hotel.import_fingerprint.present?
    assert_equal UnreconciledTransaction.import_fingerprint_for(
      date: hotel.date,
      description: hotel.description,
      amount_cents: hotel.amount_cents
    ), hotel.import_fingerprint
  end

  test "allows duplicate fingerprints within a single import" do
    path = write_csv(<<~CSV)
      transaction_date|posting_date|section|description|reference_number|amount
      2025-01-15|2025-01-16|Purchases and Adjustments|COFFEE|REF1|4.50
      2025-01-15|2025-01-16|Purchases and Adjustments|COFFEE|REF2|4.50
    CSV

    result = MonthlyCreditCardStatements::Importer.call(path: path, credit_card_account_name: "Travel Card")

    assert_equal 2, result.staged_count
    assert_equal 2, result.statement.unreconciled_transactions.count
  end

  test "rejects unsupported extensions" do
    path = File.join(Dir.mktmpdir, "notes.txt")
    File.write(path, "nope")

    assert_raises(Imports::Error) do
      MonthlyCreditCardStatements::Importer.call(path: path, credit_card_account_name: "Travel Card")
    end
    assert_equal 0, MonthlyCreditCardStatement.count
  end

  test "imports monthly PDF when present" do
    skip "monthly PDF not found" unless File.exist?(MONTHLY_PDF)

    result = MonthlyCreditCardStatements::Importer.call(path: MONTHLY_PDF, credit_card_account_name: "Travel Card")

    assert_operator result.staged_count, :>, 0
    statement = result.statement
    assert_equal "pdf", statement.import_format
    assert statement.source_file.attached?
    assert_equal result.staged_count, statement.unreconciled_transactions.count
    assert statement.unreconciled_transactions.where(category: nil, subcategory: nil).count == result.staged_count
  end

  private

  def write_csv(contents)
    dir = Dir.mktmpdir
    path = File.join(dir, "monthly.csv")
    File.write(path, contents)
    path
  end
end
