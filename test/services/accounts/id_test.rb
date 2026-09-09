# frozen_string_literal: true

require "test_helper"

class Accounts::IdTest < ActiveSupport::TestCase
  test "round trips account numbers with spaces" do
    number = "0057 4568 7822"
    token = Accounts::Id.encode(number)

    assert_equal number, Accounts::Id.decode(token)
    assert_match(/\A[A-Za-z0-9_-]+\z/, token)
  end

  test "normalize strips spaces" do
    assert_equal "005745687822", Accounts::Id.normalize("0057 4568 7822")
  end
end
