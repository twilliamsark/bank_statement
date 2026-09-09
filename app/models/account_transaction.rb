# frozen_string_literal: true

class AccountTransaction < ApplicationRecord
  include FilterableTransactions

  belongs_to :account_statement, inverse_of: :account_transactions

  validates :date, :description, :section, :checksum, presence: true
  validates :amount_cents, presence: true, numericality: { only_integer: true }

  before_validation :assign_checksum, if: -> { checksum.blank? }

  scope :for_section, ->(section) {
    section.present? ? where(section: section) : all
  }

  def self.apply_filters(relation, params)
    relation = apply_common_filters(relation, params)
    relation.for_section(params[:section])
  end

  def self.checksum_for(date:, section:, description:, amount_cents:)
    payload = [
      date.is_a?(Date) ? date.iso8601 : date.to_s,
      section.to_s,
      description.to_s,
      amount_cents.to_i
    ].join("|")

    Digest::SHA256.hexdigest(payload)
  end

  private

  def assign_checksum
    return if date.blank? || section.blank? || description.blank? || amount_cents.nil?

    self.checksum = self.class.checksum_for(
      date: date,
      section: section,
      description: description,
      amount_cents: amount_cents
    )
  end
end
