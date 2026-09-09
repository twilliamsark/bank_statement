# frozen_string_literal: true

module AccountStatements
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
        BankAccountStatement::Extractor.call(filename: source.path)
      when "csv"
        BankAccountStatement::CSVExtractor.call(filename: source.path)
      end
    end

    def persist(source, gem_result)
      existing_checksums = AccountTransaction.distinct.pluck(:checksum).to_set
      imported_count = 0
      skipped_duplicate_count = 0

      statement = nil

      ActiveRecord::Base.transaction do
        account = resolve_account(gem_result)
        statement = AccountStatement.create!(statement_attributes(source, gem_result).merge(account: account))
        source.attach_to(statement)

        gem_result.transactions.each do |gem_txn|
          amount_cents = Money.cents(gem_txn.amount)
          checksum = AccountTransaction.checksum_for(
            date: gem_txn.date,
            section: gem_txn.section,
            description: gem_txn.description,
            amount_cents: amount_cents
          )

          if existing_checksums.include?(checksum)
            skipped_duplicate_count += 1
            next
          end

          statement.account_transactions.create!(
            date: gem_txn.date,
            description: gem_txn.description,
            section: gem_txn.section,
            amount_cents: amount_cents,
            checksum: checksum
          )
          imported_count += 1
        end
      end

      Imports::Result.new(
        statement: statement,
        imported_count: imported_count,
        skipped_duplicate_count: skipped_duplicate_count
      )
    end

    def resolve_account(gem_result)
      return nil if gem_result.account_name.blank?

      Account.find_or_create_from_import!(
        name: gem_result.account_name,
        account_number: gem_result.account_number
      )
    end

    def statement_attributes(source, gem_result)
      summary = gem_result.summary

      {
        source_filename: source.original_filename,
        import_format: source.import_format,
        page_count: gem_result.page_count,
        account_name: gem_result.account_name,
        account_number: gem_result.account_number,
        period_start: gem_result.period_start,
        period_end: gem_result.period_end,
        beginning_balance_cents: Money.cents(summary&.beginning_balance),
        deposits_cents: Money.cents(summary&.deposits),
        withdrawals_cents: Money.cents(summary&.withdrawals),
        checks_cents: Money.cents(summary&.checks),
        service_fees_cents: Money.cents(summary&.service_fees),
        ending_balance_cents: Money.cents(summary&.ending_balance),
        apy_earned: summary&.apy_earned,
        interest_paid_ytd_cents: Money.cents(summary&.interest_paid_ytd)
      }
    end
  end
end
