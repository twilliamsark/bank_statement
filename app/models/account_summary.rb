# frozen_string_literal: true

# Read-model for grouping AccountStatement rows by normalized account_number.
class AccountSummary
  attr_reader :account_number, :account_name, :statement_count, :transaction_count,
              :period_start, :period_end

  def initialize(account_number:, account_name:, statement_count:, transaction_count:, period_start:, period_end:)
    @account_number = account_number
    @account_name = account_name
    @statement_count = statement_count
    @transaction_count = transaction_count
    @period_start = period_start
    @period_end = period_end
  end

  def to_param
    Accounts::Id.encode(account_number)
  end

  def statement_relation
    normalized = Accounts::Id.normalize(account_number)
    AccountStatement.where.not(account_number: [ nil, "" ])
      .where("REPLACE(account_number, ' ', '') = ?", normalized)
  end

  def transactions
    AccountTransaction.where(account_statement_id: statement_relation.select(:id))
  end

  def self.all
    statements = AccountStatement
      .where.not(account_number: [ nil, "" ])
      .includes(:account_transactions)
      .order(period_end: :desc, created_at: :desc)

    grouped = statements.group_by { |statement| Accounts::Id.normalize(statement.account_number) }

    grouped.map { |_key, group| build_from_group(group) }
      .sort_by { |account| [ account.account_name.to_s.downcase, account.account_number.to_s ] }
  end

  def self.find_by_param!(param)
    number = Accounts::Id.decode(param)
    normalized = Accounts::Id.normalize(number)
    group = AccountStatement
      .where.not(account_number: [ nil, "" ])
      .where("REPLACE(account_number, ' ', '') = ?", normalized)
      .includes(:account_transactions)
      .order(period_end: :desc, created_at: :desc)
      .to_a

    raise ActiveRecord::RecordNotFound, "Account not found" if group.empty?

    build_from_group(group)
  end

  def self.build_from_group(group)
    # Prefer a spaced BoA-style number for display when variants exist.
    canonical = group.find { |statement| statement.account_number.to_s.match?(/\s/) } || group.first
    named = group.find { |statement| statement.account_name.present? } || canonical
    periods_start = group.map(&:period_start).compact
    periods_end = group.map(&:period_end).compact

    new(
      account_number: canonical.account_number,
      account_name: named.account_name,
      statement_count: group.size,
      transaction_count: group.sum { |statement| statement.account_transactions.size },
      period_start: periods_start.min,
      period_end: periods_end.max
    )
  end
  private_class_method :build_from_group
end
