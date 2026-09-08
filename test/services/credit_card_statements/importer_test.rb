# frozen_string_literal: true

require "test_helper"

class CreditCardStatements::ImporterTest < ActiveSupport::TestCase
  YEAR_END_PDF = File.expand_path("~/Documents/BoA_CC_YearEndSummary_2025.pdf")

  test "imports credit card CSV with cents, year, and spend" do
    path = write_csv(<<~CSV)
      date|category|subcategory|description|location|amount
      2025-03-01|Merchandise|Clothing|STORE A|CITY, ST|12.34
      2025-06-15|Travel and Transportation|Hotels|HOTEL|JONESBORO, AR|100.00
      2025-07-01|Merchandise|Clothing|REFUND|CITY, ST|-5.00
    CSV

    result = CreditCardStatements::Importer.call(path: path)

    assert_equal 3, result.imported_count
    assert_equal 0, result.skipped_duplicate_count
    statement = result.statement
    assert_equal "csv", statement.import_format
    assert_equal 2025, statement.statement_year
    assert_equal Money.cents(BigDecimal("12.34") + BigDecimal("100") + BigDecimal("-5")), statement.total_spend_cents
    assert_equal 3, statement.credit_card_transactions.count

    hotel = statement.credit_card_transactions.find_by!(description: "HOTEL")
    assert_equal 10000, hotel.amount_cents
    assert_equal "Travel and Transportation", hotel.category
    assert statement.source_file.attached?
  end

  test "allows duplicate lines within a single import" do
    path = write_csv(<<~CSV)
      date|category|subcategory|description|location|amount
      2025-01-15|Merchandise|Restaurants|COFFEE|CITY, ST|4.50
      2025-01-15|Merchandise|Restaurants|COFFEE|CITY, ST|4.50
    CSV

    result = CreditCardStatements::Importer.call(path: path)

    assert_equal 2, result.imported_count
    assert_equal 2, result.statement.credit_card_transactions.count
  end

  test "skips transactions already stored on re-import" do
    path = write_csv(<<~CSV)
      date|category|subcategory|description|location|amount
      2025-03-01|Merchandise|Clothing|STORE A|CITY, ST|12.34
    CSV

    first = CreditCardStatements::Importer.call(path: path)
    second = CreditCardStatements::Importer.call(path: path)

    assert_equal 1, first.imported_count
    assert_equal 0, second.imported_count
    assert_equal 1, second.skipped_duplicate_count
    assert_equal 2, CreditCardStatement.count
    assert_equal 1, CreditCardTransaction.count
  end

  test "rejects unsupported extensions" do
    path = File.join(Dir.mktmpdir, "notes.txt")
    File.write(path, "nope")

    assert_raises(Imports::Error) do
      CreditCardStatements::Importer.call(path: path)
    end
    assert_equal 0, CreditCardStatement.count
  end

  test "imports BoA_CC_YearEndSummary_2025.pdf when present" do
    skip "BoA_CC_YearEndSummary_2025.pdf not found" unless File.exist?(YEAR_END_PDF)

    result = CreditCardStatements::Importer.call(path: YEAR_END_PDF)

    assert_operator result.imported_count, :>, 0
    assert_equal 0, result.skipped_duplicate_count
    statement = result.statement
    assert_equal "pdf", statement.import_format
    assert_equal "BoA_CC_YearEndSummary_2025.pdf", statement.source_filename
    assert_equal 2025, statement.statement_year
    assert statement.total_spend_cents.present?
    assert_equal result.imported_count, statement.credit_card_transactions.count
    assert statement.source_file.attached?

    sample = statement.credit_card_transactions.first
    assert sample.category.present?
    assert sample.subcategory.present?
    assert sample.checksum.present?

    reimport = CreditCardStatements::Importer.call(path: YEAR_END_PDF)
    assert_equal 0, reimport.imported_count
    assert_equal result.imported_count, reimport.skipped_duplicate_count
  end

  private

  def write_csv(contents)
    dir = Dir.mktmpdir
    path = File.join(dir, "cc.csv")
    File.write(path, contents)
    path
  end
end
