# frozen_string_literal: true

module MonthlyCreditCardStatements
  class Importer
    Result = Data.define(:statement, :staged_count)

    def self.call(...)
      new(...).call
    end

    def initialize(path: nil, io: nil, filename: nil, credit_card_account: nil, credit_card_account_name: nil)
      @path = path
      @io = io
      @filename = filename
      @credit_card_account = credit_card_account
      @credit_card_account_name = credit_card_account_name
    end

    def call
      if @credit_card_account.blank? && @credit_card_account_name.blank?
        raise Imports::Error, "credit card account is required"
      end

      source = Imports::SourceFile.open(path: @path, io: @io, filename: @filename)

      begin
        gem_result = extract(source)
        persist(source, gem_result)
      rescue Imports::Error
        raise
      rescue ArgumentError, Errno::ENOENT, ActiveRecord::RecordInvalid => e
        raise Imports::Error, e.message
      ensure
        source.cleanup!
      end
    end

    private

    def extract(source)
      case source.import_format
      when "pdf"
        CCAccountStatement::Extractor.call(filename: source.path)
      when "csv"
        CCAccountStatement::CSVExtractor.call(filename: source.path)
      end
    end

    def persist(source, gem_result)
      statement = nil
      staged_count = 0

      ActiveRecord::Base.transaction do
        account = resolve_account!

        statement = MonthlyCreditCardStatement.create!(
          credit_card_account: account,
          source_filename: source.original_filename,
          import_format: source.import_format,
          page_count: gem_result.page_count,
          period_start: gem_result.period_start,
          period_end: gem_result.period_end,
          account_name: gem_result.account_name,
          account_number: gem_result.account_number
        )
        source.attach_to(statement)

        gem_result.transactions.each do |gem_txn|
          statement.unreconciled_transactions.create!(
            date: gem_txn.transaction_date,
            description: gem_txn.description,
            amount_cents: Money.cents(gem_txn.amount),
            category: nil,
            subcategory: nil
          )
          staged_count += 1
        end
      end

      Result.new(statement: statement, staged_count: staged_count)
    end

    def resolve_account!
      return @credit_card_account if @credit_card_account.present?

      CreditCardAccount.find_or_create_from_name!(@credit_card_account_name)
    end
  end
end
