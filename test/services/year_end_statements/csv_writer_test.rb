# frozen_string_literal: true

require "test_helper"

class CCYearEndStatement::CSVWriterTest < ActiveSupport::TestCase
  FakeExtractor = Struct.new(:result) do
    def call(filename:)
      raise ArgumentError, "filename is required" if filename.blank?

      result
    end
  end

  test "writes transactions to a pipe-delimited csv next to the source file by default" do
    Dir.mktmpdir do |dir|
      source_path = File.join(dir, "statement.pdf")
      File.write(source_path, "pdf")

      output_path = CCYearEndStatement::CSVWriter.call(
        filename: source_path,
        extractor: FakeExtractor.new(extractor_result)
      )

      assert_equal File.join(dir, "statement.csv"), output_path
      assert_equal <<~CSV, File.read(output_path)
        date|category|subcategory|description|location|amount
        2025-07-01|Merchandise|Clothing|MENS WAREHOUSE 1534|JONESBORO, AR|740.61
        2025-05-09|Travel and Transportation|Hotels|COMFORT INNS|ORLANDO, FL|-100.0
      CSV
    end
  end

  test "writes transactions using a custom separator and output path" do
    Dir.mktmpdir do |dir|
      source_path = File.join(dir, "statement.pdf")
      output_path = File.join(dir, "transactions.txt")
      File.write(source_path, "pdf")

      returned_path = CCYearEndStatement::CSVWriter.call(
        filename: source_path,
        output_filename: output_path,
        field_separator: ",",
        extractor: FakeExtractor.new(extractor_result)
      )

      assert_equal output_path, returned_path
      assert_equal <<~CSV, File.read(output_path)
        date,category,subcategory,description,location,amount
        2025-07-01,Merchandise,Clothing,MENS WAREHOUSE 1534,"JONESBORO, AR",740.61
        2025-05-09,Travel and Transportation,Hotels,COMFORT INNS,"ORLANDO, FL",-100.0
      CSV
    end
  end

  private

  def extractor_result
    CCYearEndStatement::Extractor::Result.new(
      filename: "/tmp/statement.pdf",
      page_count: 1,
      categories: [
        CCYearEndStatement::Extractor::Category.new(
          name: "Merchandise",
          total: BigDecimal("740.61"),
          subcategories: [
            CCYearEndStatement::Extractor::Subcategory.new(
              name: "Clothing",
              total: BigDecimal("740.61"),
              transactions: [
                CCYearEndStatement::Extractor::Transaction.new(
                  date: Date.new(2025, 7, 1),
                  description: "MENS WAREHOUSE 1534",
                  location: "JONESBORO, AR",
                  amount: BigDecimal("740.61"),
                  category: "Merchandise",
                  subcategory: "Clothing"
                )
              ]
            )
          ]
        ),
        CCYearEndStatement::Extractor::Category.new(
          name: "Travel and Transportation",
          total: BigDecimal("-100.0"),
          subcategories: [
            CCYearEndStatement::Extractor::Subcategory.new(
              name: "Hotels",
              total: BigDecimal("-100.0"),
              transactions: [
                CCYearEndStatement::Extractor::Transaction.new(
                  date: Date.new(2025, 5, 9),
                  description: "COMFORT INNS",
                  location: "ORLANDO, FL",
                  amount: BigDecimal("-100.0"),
                  category: "Travel and Transportation",
                  subcategory: "Hotels"
                )
              ]
            )
          ]
        )
      ]
    )
  end
end
