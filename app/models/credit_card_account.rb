# frozen_string_literal: true

class CreditCardAccount < ApplicationRecord
  has_many :credit_card_statements, dependent: :restrict_with_exception
  # Year-end-backed transactions (used by Auto Reconcile matching).
  has_many :credit_card_transactions, through: :credit_card_statements
  has_many :monthly_credit_card_statements, dependent: :restrict_with_exception
  has_many :monthly_credit_card_transactions, through: :monthly_credit_card_statements, source: :credit_card_transactions

  validates :name, :name_key, presence: true
  validates :name_key, uniqueness: true

  before_validation :assign_name_key

  def self.normalize_name(name)
    name.to_s.gsub(/\s+/, " ").strip
  end

  def self.name_key_for(name)
    normalize_name(name).downcase
  end

  def self.find_or_create_from_name!(name)
    raise ArgumentError, "credit card account name is required" if name.blank?

    display_name = normalize_name(name)
    key = name_key_for(display_name)

    find_by(name_key: key) || create!(name: display_name, name_key: key)
  end

  # Year-end + monthly committed rows for account rollups and master transaction lists.
  def all_credit_card_transactions
    CreditCardTransaction.where(credit_card_statement_id: credit_card_statements.select(:id)).or(
      CreditCardTransaction.where(monthly_credit_card_statement_id: monthly_credit_card_statements.select(:id))
    )
  end

  private

  def assign_name_key
    self.name = self.class.normalize_name(name) if name.present?
    self.name_key = self.class.name_key_for(name) if name.present?
  end
end

