# frozen_string_literal: true

class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :name, null: false
      t.string :name_key, null: false
      t.string :account_number

      t.timestamps
    end

    add_index :accounts, :name_key, unique: true
    add_index :accounts, :account_number
  end
end
