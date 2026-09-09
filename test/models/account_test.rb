# frozen_string_literal: true

require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "find_or_create_from_import reuses normalized name" do
    first = Account.find_or_create_from_import!(name: "Your Savings", account_number: "123")
    second = Account.find_or_create_from_import!(name: "  your   savings ", account_number: "999")

    assert_equal first.id, second.id
    assert_equal "Your Savings", first.reload.name
    assert_equal "123", first.account_number
  end

  test "new name creates a new account" do
    Account.find_or_create_from_import!(name: "Checking")
    assert_difference -> { Account.count }, 1 do
      Account.find_or_create_from_import!(name: "Savings")
    end
  end
end
