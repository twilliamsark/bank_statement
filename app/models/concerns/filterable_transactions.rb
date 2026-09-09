# frozen_string_literal: true

# Shared date / description / amount filters for statement transaction tables.
# Amount matching uses SQLite printf of cents as dollars — keep isolated here.
module FilterableTransactions
  extend ActiveSupport::Concern

  class_methods do
    def apply_common_filters(relation, params)
      relation = relation.for_date_range(params[:date_from], params[:date_to])
      relation = relation.description_like(params[:description])
      relation = relation.amount_display_like(params[:amount])
      relation
    end

    def normalize_amount_query(query)
      query.to_s.gsub(/[$,\s]/, "")
    end
  end

  included do
    scope :for_date_range, ->(date_from, date_to) do
      rel = all
      begin
        rel = rel.where("date >= ?", Date.parse(date_from.to_s)) if date_from.present?
        rel = rel.where("date <= ?", Date.parse(date_to.to_s)) if date_to.present?
      rescue Date::Error
        rel = all
      end
      rel
    end

    scope :description_like, ->(query) do
      if query.blank?
        all
      else
        where("LOWER(description) LIKE ?", "%#{query.to_s.downcase}%")
      end
    end

    # SQLite-specific dollar formatting of amount_cents for lookahead UX.
    scope :amount_display_like, ->(query) do
      normalized = normalize_amount_query(query)
      if normalized.blank?
        all
      else
        where("printf('%.2f', amount_cents / 100.0) LIKE ?", "%#{normalized}%")
      end
    end
  end
end
