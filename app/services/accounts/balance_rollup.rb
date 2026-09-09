# frozen_string_literal: true

module Accounts
  # Rolls statement period snapshots into account-level balance fields.
  # Beginning/ending are NOT summed across statements.
  class BalanceRollup
    Result = Data.define(
      :beginning_balance_cents,
      :ending_balance_cents,
      :deposits_cents,
      :withdrawals_cents,
      :checks_cents,
      :service_fees_cents,
      :interest_paid_ytd_cents,
      :apy_earned
    )

    def self.call(statements)
      new(statements).call
    end

    def initialize(statements)
      @statements = Array(statements)
    end

    def call
      Result.new(
        beginning_balance_cents: earliest_statement&.beginning_balance_cents,
        ending_balance_cents: latest_statement&.ending_balance_cents,
        deposits_cents: sum(:deposits_cents),
        withdrawals_cents: sum(:withdrawals_cents),
        checks_cents: sum(:checks_cents),
        service_fees_cents: sum(:service_fees_cents),
        interest_paid_ytd_cents: latest_statement&.interest_paid_ytd_cents,
        apy_earned: latest_statement&.apy_earned
      )
    end

    private

    attr_reader :statements

    def earliest_statement
      statements
        .select { |s| s.period_start.present? }
        .min_by { |s| [ s.period_start, s.period_end || s.period_start, s.id ] } ||
        statements.min_by(&:id)
    end

    def latest_statement
      statements
        .select { |s| s.period_end.present? }
        .max_by { |s| [ s.period_end, s.period_start || s.period_end, s.id ] } ||
        statements.max_by(&:id)
    end

    def sum(attribute)
      values = statements.filter_map { |s| s.public_send(attribute) }
      return nil if values.empty?

      values.sum
    end
  end
end
