# frozen_string_literal: true

class CreditCardTransaction < ApplicationRecord
  include FilterableTransactions

  belongs_to :credit_card_statement

  validates :date, :description, :category, :subcategory, :checksum, presence: true
  validates :amount_cents, presence: true, numericality: { only_integer: true }

  before_validation :assign_checksum, if: -> { checksum.blank? }

  scope :for_category, ->(category) {
    category.present? ? where(category: category) : all
  }

  scope :for_subcategory, ->(subcategory) {
    subcategory.present? ? where(subcategory: subcategory) : all
  }

  def self.apply_filters(relation, params)
    relation = apply_common_filters(relation, params)
    relation = relation.for_category(params[:category])
    relation.for_subcategory(params[:subcategory])
  end

  def self.checksum_for(date:, category:, subcategory:, description:, location:, amount_cents:)
    payload = [
      date.is_a?(Date) ? date.iso8601 : date.to_s,
      category.to_s,
      subcategory.to_s,
      description.to_s,
      location.to_s,
      amount_cents.to_i
    ].join("|")

    Digest::SHA256.hexdigest(payload)
  end

  private

  def assign_checksum
    return if date.blank? || category.blank? || subcategory.blank? || description.blank? || amount_cents.nil?

    self.checksum = self.class.checksum_for(
      date: date,
      category: category,
      subcategory: subcategory,
      description: description,
      location: location,
      amount_cents: amount_cents
    )
  end
end
