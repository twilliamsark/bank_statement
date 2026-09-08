# frozen_string_literal: true

# Converts between gem BigDecimal dollars and integer cents for persistence.
module Money
  module_function

  # Bank/CC amounts are two decimal places; half-up rounding documents intent.
  def cents(dollars)
    return nil if dollars.nil?

    (BigDecimal(dollars.to_s) * 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
  end

  def dollars(cents)
    return nil if cents.nil?

    BigDecimal(cents.to_i) / 100
  end
end
