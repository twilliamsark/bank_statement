# frozen_string_literal: true

class UnreconciledTransaction < ApplicationRecord
  include ImportFingerprintable
  include FilterableTransactions

  belongs_to :monthly_credit_card_statement

  validates :date, :description, :import_fingerprint, presence: true
  validates :amount_cents, presence: true, numericality: { only_integer: true }

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

  def ready_to_save?
    category.present? && subcategory.present?
  end
end
