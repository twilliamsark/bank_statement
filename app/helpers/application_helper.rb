# frozen_string_literal: true

module ApplicationHelper
  def cents_to_currency(cents)
    return "—" if cents.nil?

    number_to_currency(Money.dollars(cents))
  end

  def display_date(date)
    return "—" if date.blank?

    l(date)
  end

  def display_text(value)
    value.presence || "—"
  end
end
