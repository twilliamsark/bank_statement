# frozen_string_literal: true

require "test_helper"

class PaginationTest < ActiveSupport::TestCase
  test "clamps page within bounds" do
    pagination = Pagination.new(page: 99, total_count: 120, per_page: 50)

    assert_equal 3, pagination.page
    assert_equal 3, pagination.total_pages
    assert_equal 100, pagination.offset
  end

  test "single page when empty" do
    pagination = Pagination.new(page: 1, total_count: 0)

    assert_equal 1, pagination.page
    assert_equal 1, pagination.total_pages
    assert_not pagination.paginate?
  end
end
