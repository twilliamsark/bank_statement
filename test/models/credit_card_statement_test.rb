# frozen_string_literal: true

require "test_helper"

class CreditCardStatementTest < ActiveSupport::TestCase
  test "has many transactions and destroys them" do
    statement = CreditCardStatement.create!(
      statement_year: 2025,
      source_filename: "cc.csv",
      import_format: "csv",
      total_spend_cents: 1000
    )
    statement.credit_card_transactions.create!(
      date: Date.new(2025, 3, 1),
      description: "STORE",
      location: "CITY, ST",
      amount_cents: 1000,
      category: "Merchandise",
      subcategory: "Department Store"
    )

    assert_difference -> { CreditCardTransaction.count }, -1 do
      statement.destroy!
    end
  end

  test "can attach a source file" do
    statement = CreditCardStatement.create!(import_format: "pdf", source_filename: "cc.pdf")
    statement.source_file.attach(
      io: StringIO.new("%PDF-1.4"),
      filename: "cc.pdf",
      content_type: "application/pdf"
    )

    assert statement.source_file.attached?
  end
end
