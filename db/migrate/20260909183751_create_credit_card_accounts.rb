# frozen_string_literal: true

class CreateCreditCardAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :credit_card_accounts do |t|
      t.string :name, null: false
      t.string :name_key, null: false

      t.timestamps
    end

    add_index :credit_card_accounts, :name_key, unique: true
  end
end
