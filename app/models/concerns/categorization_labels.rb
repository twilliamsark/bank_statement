# frozen_string_literal: true

module CategorizationLabels
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_category_labels

    validates :category, length: { maximum: 100 }, allow_blank: true
    validates :subcategory, length: { maximum: 100 }, allow_blank: true
  end

  private

  def normalize_category_labels
    self.category = category&.strip.presence
    self.subcategory = subcategory&.strip.presence
    self.subcategory = nil if category.blank?
  end
end

