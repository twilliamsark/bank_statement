# frozen_string_literal: true

module CreditCardStatements
  class Importer
    def self.call(...)
      new(...).call
    end

    def initialize(path: nil, io: nil, filename: nil)
      @path = path
      @io = io
      @filename = filename
    end

    def call
      source = Imports::SourceFile.open(path: @path, io: @io, filename: @filename)

      begin
        gem_result = extract(source)
        persist(source, gem_result)
      rescue Imports::Error
        raise
      rescue ArgumentError, Errno::ENOENT => e
        raise Imports::Error, e.message
      ensure
        source.cleanup!
      end
    end

    private

    def extract(source)
      case source.import_format
      when "pdf"
        CCYearEndStatement::Extractor.call(filename: source.path)
      when "csv"
        CCYearEndStatement::CSVExtractor.call(filename: source.path)
      end
    end

    def persist(source, gem_result)
      existing_checksums = CreditCardTransaction.distinct.pluck(:checksum).to_set
      imported_count = 0
      skipped_duplicate_count = 0
      imported_amount_cents = 0

      statement = nil

      ActiveRecord::Base.transaction do
        statement = CreditCardStatement.create!(
          source_filename: source.original_filename,
          import_format: source.import_format,
          page_count: gem_result.page_count,
          statement_year: nil,
          total_spend_cents: 0
        )
        source.attach_to(statement)

        gem_result.transactions.each do |gem_txn|
          amount_cents = Money.cents(gem_txn.amount)
          checksum = CreditCardTransaction.checksum_for(
            date: gem_txn.date,
            category: gem_txn.category,
            subcategory: gem_txn.subcategory,
            description: gem_txn.description,
            location: gem_txn.location.to_s,
            amount_cents: amount_cents
          )

          if existing_checksums.include?(checksum)
            skipped_duplicate_count += 1
            next
          end

          statement.credit_card_transactions.create!(
            date: gem_txn.date,
            description: gem_txn.description,
            location: gem_txn.location.to_s,
            category: gem_txn.category,
            subcategory: gem_txn.subcategory,
            amount_cents: amount_cents,
            checksum: checksum
          )
          imported_count += 1
          imported_amount_cents += amount_cents
        end

        statement.update!(
          statement_year: statement_year_for(gem_result),
          total_spend_cents: total_spend_cents_for(gem_result, imported_amount_cents)
        )
      end

      Imports::Result.new(
        statement: statement,
        imported_count: imported_count,
        skipped_duplicate_count: skipped_duplicate_count
      )
    end

    # Year of the latest transaction date (SPEC).
    def statement_year_for(gem_result)
      dates = gem_result.transactions.filter_map(&:date)
      return nil if dates.empty?

      dates.max.year
    end

    def total_spend_cents_for(gem_result, imported_amount_cents)
      if gem_result.categories.any?
        gem_result.categories.sum { |category| Money.cents(category.total) }
      else
        imported_amount_cents
      end
    end
  end
end
