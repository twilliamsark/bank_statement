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

  def nav_link(label, path, active: false)
    classes = [ "app-nav-link" ]
    classes << "app-nav-link-active" if active
    link_to label, path, class: classes.join(" ")
  end

  def nav_section_active?(*prefixes)
    prefixes.any? { |prefix| request.path == prefix || request.path.start_with?("#{prefix}/") }
  end
end
