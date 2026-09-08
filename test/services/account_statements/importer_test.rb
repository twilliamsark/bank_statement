# frozen_string_literal: true

require "test_helper"

class AccountStatements::ImporterTest < ActiveSupport::TestCase
  SAVINGS_PDF = File.expand_path("~/Documents/BoA_Savings_Jan_2026.pdf")

  test "imports account CSV with cents and checksums" do
    path = write_csv(<<~CSV)
      date|section|description|amount
      2026-01-02|Deposits and other additions|Interest Earned|0.02
      2026-01-03|Withdrawals and other subtractions|ACH Withdrawal|-25.00
    CSV

    result = AccountStatements::Importer.call(path: path)

    assert_equal 2, result.imported_count
    assert_equal 0, result.skipped_duplicate_count
    statement = result.statement
    assert_equal "csv", statement.import_format
    assert_nil statement.account_name
    assert_nil statement.beginning_balance_cents
    assert_equal 2, statement.account_transactions.count

    interest = statement.account_transactions.find_by!(description: "Interest Earned")
    assert_equal 2, interest.amount_cents
    assert_equal(
      AccountTransaction.checksum_for(
        date: interest.date,
        section: interest.section,
        description: interest.description,
        amount_cents: interest.amount_cents
      ),
      interest.checksum
    )

    withdrawal = statement.account_transactions.find_by!(description: "ACH Withdrawal")
    assert_equal(-2500, withdrawal.amount_cents)
    assert statement.source_file.attached?
  end

  test "allows duplicate lines within a single import" do
    path = write_csv(<<~CSV)
      date|section|description|amount
      2026-01-09|Withdrawals and other subtractions|Duplicate line|-1.00
      2026-01-09|Withdrawals and other subtractions|Duplicate line|-1.00
    CSV

    result = AccountStatements::Importer.call(path: path)

    assert_equal 2, result.imported_count
    assert_equal 0, result.skipped_duplicate_count
    assert_equal 2, result.statement.account_transactions.count
    assert_equal 1, result.statement.account_transactions.distinct.count(:checksum)
  end

  test "skips transactions already stored on re-import" do
    path = write_csv(<<~CSV)
      date|section|description|amount
      2026-01-02|Deposits and other additions|Interest Earned|0.02
      2026-01-03|Withdrawals and other subtractions|ACH Withdrawal|-25.00
    CSV

    first = AccountStatements::Importer.call(path: path)
    second = AccountStatements::Importer.call(path: path)

    assert_equal 2, first.imported_count
    assert_equal 0, first.skipped_duplicate_count
    assert_equal 0, second.imported_count
    assert_equal 2, second.skipped_duplicate_count
    assert_equal 2, AccountStatement.count
    assert_equal 2, AccountTransaction.count
  end

  test "rejects unsupported extensions" do
    path = File.join(Dir.mktmpdir, "notes.txt")
    File.write(path, "nope")

    error = assert_raises(Imports::Error) do
      AccountStatements::Importer.call(path: path)
    end
    assert_match(/unsupported file type/i, error.message)
    assert_equal 0, AccountStatement.count
  end

  test "imports BoA_Savings_Jan_2026.pdf when present" do
    skip "BoA_Savings_Jan_2026.pdf not found" unless File.exist?(SAVINGS_PDF)

    result = AccountStatements::Importer.call(path: SAVINGS_PDF)

    assert_operator result.imported_count, :>, 0
    assert_equal 0, result.skipped_duplicate_count
    statement = result.statement
    assert_equal "pdf", statement.import_format
    assert_equal "BoA_Savings_Jan_2026.pdf", statement.source_filename
    assert statement.account_name.present?
    assert statement.period_start.present?
    assert statement.ending_balance_cents.present?
    assert_equal result.imported_count, statement.account_transactions.count
    assert statement.source_file.attached?

    reimport = AccountStatements::Importer.call(path: SAVINGS_PDF)
    assert_equal 0, reimport.imported_count
    assert_equal result.imported_count, reimport.skipped_duplicate_count
  end

  private

  def write_csv(contents)
    dir = Dir.mktmpdir
    path = File.join(dir, "account.csv")
    File.write(path, contents)
    path
  end
end
