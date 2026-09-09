# frozen_string_literal: true

class Pagination
  DEFAULT_PER_PAGE = 50

  attr_reader :page, :per_page, :total_count

  def initialize(page:, total_count:, per_page: DEFAULT_PER_PAGE)
    @per_page = per_page
    @total_count = total_count.to_i
    @page = [[ page.to_i, 1 ].max, total_pages].min
    @page = 1 if @page < 1
  end

  def offset
    (page - 1) * per_page
  end

  def limit
    per_page
  end

  def total_pages
    return 1 if total_count <= 0

    (total_count.to_f / per_page).ceil
  end

  def paginate?
    total_pages > 1
  end

  def from_item
    return 0 if total_count.zero?

    offset + 1
  end

  def to_item
    [ offset + per_page, total_count ].min
  end
end
