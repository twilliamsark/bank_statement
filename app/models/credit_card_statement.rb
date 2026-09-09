# frozen_string_literal: true

class CreditCardStatement < ApplicationRecord
  belongs_to :credit_card_account

  has_one_attached :source_file
  has_many :credit_card_transactions, dependent: :destroy

  validates :import_format, inclusion: { in: %w[pdf csv] }, allow_nil: true
end
