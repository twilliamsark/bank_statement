# frozen_string_literal: true

class UnreconciledTransaction < ApplicationRecord
  include ImportFingerprintable

  belongs_to :monthly_credit_card_statement

  validates :date, :description, :import_fingerprint, presence: true
  validates :amount_cents, presence: true, numericality: { only_integer: true }
end
