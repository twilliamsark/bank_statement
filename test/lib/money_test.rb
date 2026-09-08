# frozen_string_literal: true

require "test_helper"

class MoneyTest < ActiveSupport::TestCase
  test "cents converts BigDecimal dollars to integer cents" do
    assert_equal 1234, Money.cents(BigDecimal("12.34"))
    assert_equal(-500, Money.cents(BigDecimal("-5")))
    assert_equal 1, Money.cents(BigDecimal("0.01"))
  end

  test "cents rounds half up at the third decimal of dollars" do
    assert_equal 13, Money.cents(BigDecimal("0.125"))
    assert_equal 12, Money.cents(BigDecimal("0.124"))
  end

  test "cents returns nil for nil" do
    assert_nil Money.cents(nil)
  end

  test "dollars converts cents to BigDecimal" do
    assert_equal BigDecimal("12.34"), Money.dollars(1234)
    assert_equal BigDecimal("-5.0"), Money.dollars(-500)
  end

  test "dollars returns nil for nil" do
    assert_nil Money.dollars(nil)
  end

  test "round trip dollars and cents" do
    original = BigDecimal("99.99")
    assert_equal original, Money.dollars(Money.cents(original))
  end
end
