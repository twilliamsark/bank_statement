# frozen_string_literal: true

class AccountsController < ApplicationController
  def index
    @accounts = AccountSummary.all
    @unnumbered_statement_count = AccountStatement.where(account_number: [ nil, "" ]).count
  end
end
