# frozen_string_literal: true

require "test_helper"

class CreditCardAccountTest < ActiveSupport::TestCase
  test "find_or_create_from_name reuses case-insensitive names" do
    first = CreditCardAccount.find_or_create_from_name!("Travel Card")
    second = CreditCardAccount.find_or_create_from_name!("  travel   card ")

    assert_equal first.id, second.id
    assert_equal "Travel Card", first.reload.name
  end

  test "restricts destroy while statements exist" do
    account = CreditCardAccount.find_or_create_from_name!("Locked Card")
    CreditCardStatement.create!(
      credit_card_account: account,
      source_filename: "cc.csv",
      import_format: "csv"
    )

    assert_raises(ActiveRecord::DeleteRestrictionError) { account.destroy! }
  end
end
