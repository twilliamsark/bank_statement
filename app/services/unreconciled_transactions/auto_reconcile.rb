# frozen_string_literal: true

module UnreconciledTransactions
  class AutoReconcile
    Result = Data.define(:examined_count, :reconciled_count, :skipped_count)

    def self.call(...)
      new(...).call
    end

    def initialize(monthly_credit_card_statement:)
      @statement = monthly_credit_card_statement
    end

    def call
      account = @statement.credit_card_account
      year_end_txns = account.credit_card_transactions.to_a

      examined_count = 0
      reconciled_count = 0
      skipped_count = 0

      @statement.unreconciled_transactions.find_each do |staging|
        if staging.category.present? && staging.subcategory.present?
          skipped_count += 1
          next
        end

        examined_count += 1
        pair = unanimous_category_pair(staging, year_end_txns)
        if pair
          staging.update!(category: pair[0], subcategory: pair[1])
          reconciled_count += 1
        else
          skipped_count += 1
        end
      end

      Result.new(
        examined_count: examined_count,
        reconciled_count: reconciled_count,
        skipped_count: skipped_count
      )
    end

    private

    def unanimous_category_pair(staging, year_end_txns)
      prefix = CreditCardTransaction.category_match_prefix(staging.description)
      pairs = year_end_txns
        .select { |txn| txn.amount_cents == staging.amount_cents }
        .select { |txn| CreditCardTransaction.category_match_prefix(txn.description) == prefix }
        .map { |txn| [ txn.category, txn.subcategory ] }
        .uniq

      return pairs.first if pairs.size == 1

      nil
    end
  end
end
