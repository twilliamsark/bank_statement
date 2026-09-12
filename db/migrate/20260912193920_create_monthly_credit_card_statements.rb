# frozen_string_literal: true

class CreateMonthlyCreditCardStatements < ActiveRecord::Migration[8.1]
  def change
    create_table :monthly_credit_card_statements do |t|
      t.references :credit_card_account, null: false, foreign_key: true
      t.date :period_start
      t.date :period_end
      t.string :account_name
      t.string :account_number
      t.integer :page_count
      t.string :source_filename
      t.string :import_format

      t.timestamps
    end
  end
end
