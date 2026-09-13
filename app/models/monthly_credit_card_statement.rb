# frozen_string_literal: true

class MonthlyCreditCardStatement < ApplicationRecord
  belongs_to :credit_card_account

  has_one_attached :source_file
  has_many :unreconciled_transactions, dependent: :destroy
  has_many :credit_card_transactions, dependent: :destroy

  validates :import_format, inclusion: { in: %w[pdf csv] }, allow_nil: true

  def summary_available?
    new_balance_cents.present? || previous_balance_cents.present?
  end

  def period_label
    if period_start.present? || period_end.present?
      start_label = period_start&.strftime("%b %-d, %Y") || "—"
      end_label = period_end&.strftime("%b %-d, %Y") || "—"
      "#{start_label} – #{end_label}"
    elsif statement_closing_date.present?
      statement_closing_date.strftime("%b %-d, %Y closing")
    else
      source_filename.presence || "Monthly statement"
    end
  end

  def title_label
    if period_end.present?
      "#{period_end.strftime("%b %Y")} statement"
    elsif statement_closing_date.present?
      "#{statement_closing_date.strftime("%b %Y")} statement"
    else
      "Monthly statement"
    end
  end
end
