# frozen_string_literal: true

require "test_helper"
require "ostruct"

class ApplicationHelperTest < ActionView::TestCase
  test "nav_section_active matches accounts without matching account_statements" do
    @request_path = "/account_statements"
    assert_not nav_section_active?("/accounts")
    assert nav_section_active?("/account_statements")
  end

  test "nav_section_active matches nested account paths" do
    @request_path = "/accounts/1/transactions"
    assert nav_section_active?("/accounts")
  end

  def request
    OpenStruct.new(path: @request_path)
  end
end
