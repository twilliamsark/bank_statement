# frozen_string_literal: true

# Persisted bank account statement.
# Not named BankAccountStatement (gem module) or BankStatement (Rails app module).
class AccountStatement < ApplicationRecord
  belongs_to :account, optional: true

  has_one_attached :source_file
  has_many :account_transactions, dependent: :destroy, inverse_of: :account_statement

  validates :import_format, inclusion: { in: %w[pdf csv] }, allow_nil: true
end
