class CreateCreditCardTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :credit_card_transactions do |t|
      t.references :credit_card_statement, null: false, foreign_key: true
      t.date :date, null: false
      t.text :description, null: false
      t.string :location, null: false, default: ""
      t.integer :amount_cents, null: false
      t.string :category, null: false
      t.string :subcategory, null: false
      t.string :checksum, null: false

      t.timestamps
    end

    add_index :credit_card_transactions, :date
    add_index :credit_card_transactions, :category
    add_index :credit_card_transactions, :subcategory
    add_index :credit_card_transactions, :description
    add_index :credit_card_transactions, :checksum
  end
end
