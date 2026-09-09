# frozen_string_literal: true

module PaginationHelper
  def pagination_path_for(page)
    url_for(request.query_parameters.merge(page: page, only_path: true))
  end
end
