# frozen_string_literal: true

class Account < ApplicationRecord
  has_many :account_statements, dependent: :restrict_with_exception
  has_many :account_transactions, through: :account_statements

  validates :name, :name_key, presence: true
  validates :name_key, uniqueness: true

  before_validation :assign_name_key

  def self.normalize_name(name)
    name.to_s.gsub(/\s+/, " ").strip
  end

  def self.name_key_for(name)
    normalize_name(name).downcase
  end

  def self.find_or_create_from_import!(name:, account_number: nil)
    raise ArgumentError, "account name required" if name.blank?

    display_name = normalize_name(name)
    key = name_key_for(display_name)

    account = find_by(name_key: key)
    if account
      if account_number.present? && account.account_number.blank?
        account.update!(account_number: account_number)
      end
      account
    else
      create!(name: display_name, name_key: key, account_number: account_number.presence)
    end
  end

  def period_start
    account_statements.minimum(:period_start)
  end

  def period_end
    account_statements.maximum(:period_end)
  end

  private

  def assign_name_key
    self.name = self.class.normalize_name(name) if name.present?
    self.name_key = self.class.name_key_for(name) if name.present?
  end
end
