# frozen_string_literal: true

require "test_helper"

class BankAccountStatementsCSVExtractorIntegrationTest < ActiveSupport::TestCase
  test "loads the local gem and parses statement csv data" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "statement.csv")
      File.write(path, <<~CSV)
        date|section|description|amount
        2025-11-12|Deposits and other additions|PAYROLL|1500.00
      CSV

      result = BankAccountStatement::CSVExtractor.call(filename: path)

      assert_equal "0.1.0", BankAccountStatement::VERSION
      assert_equal path, result.filename
      assert_nil result.page_count
      assert_equal ["Deposits and other additions"], result.sections.map(&:name)
      assert_equal BigDecimal("1500.00"), result.sections.first.total
      assert_equal 1, result.transactions.size
      assert_equal "PAYROLL", result.transactions.first.description
      assert_equal BigDecimal("1500.00"), result.transactions.first.amount
    end
  end
end