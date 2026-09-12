# frozen_string_literal: true

require "test_helper"

class CreditCardTransactionFingerprintTest < ActiveSupport::TestCase
  test "import_fingerprint_for uses description[0, 21] not inclusive 22-char slice" do
    description = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    expected = Digest::MD5.hexdigest(
      [ "2025-06-01", "ABCDEFGHIJKLMNOPQRSTU", 10000 ].join("|")
    )
    outdated_22_char = Digest::MD5.hexdigest(
      [ "2025-06-01", "ABCDEFGHIJKLMNOPQRSTUV", 10000 ].join("|")
    )

    actual = CreditCardTransaction.import_fingerprint_for(
      date: Date.new(2025, 6, 1),
      description: description,
      amount_cents: 10000
    )

    assert_equal expected, actual
    assert_not_equal outdated_22_char, actual
  end
end
