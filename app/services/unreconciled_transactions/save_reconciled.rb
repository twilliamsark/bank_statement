# frozen_string_literal: true

module UnreconciledTransactions
  class SaveReconciled
    Result = Data.define(:saved_count, :remaining_count)

    def self.call(...)
      new(...).call
    end

    def initialize(monthly_credit_card_statement:)
      @statement = monthly_credit_card_statement
    end

    def call
      saved_count = 0

      ActiveRecord::Base.transaction do
        eligible.find_each do |staging|
          @statement.credit_card_transactions.create!(
            credit_card_statement_id: nil,
            date: staging.date,
            description: staging.description,
            amount_cents: staging.amount_cents,
            category: staging.category,
            subcategory: staging.subcategory,
            location: "",
            import_fingerprint: staging.import_fingerprint
          )
          staging.destroy!
          saved_count += 1
        end
      end

      Result.new(
        saved_count: saved_count,
        remaining_count: @statement.unreconciled_transactions.count
      )
    end

    private

    def eligible
      scope = @statement.unreconciled_transactions
        .where.not(category: [ nil, "" ])
        .where.not(subcategory: [ nil, "" ])

      if UnreconciledTransaction.column_names.include?("potential_duplicate")
        scope = scope.where(potential_duplicate: false)
      end

      scope
    end
  end
end
