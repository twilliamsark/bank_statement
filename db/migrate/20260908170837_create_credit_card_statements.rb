class CreateCreditCardStatements < ActiveRecord::Migration[8.1]
  def change
    create_table :credit_card_statements do |t|
      t.integer :statement_year
      t.integer :page_count
      t.string :source_filename
      t.string :import_format
      t.integer :total_spend_cents

      t.timestamps
    end

    add_index :credit_card_statements, :statement_year
  end
end
