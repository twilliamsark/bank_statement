# frozen_string_literal: true

class AddCreditCardAccountToCreditCardStatements < ActiveRecord::Migration[8.1]
  def up
    add_reference :credit_card_statements, :credit_card_account, foreign_key: true, null: true

    say_with_time "backfill credit card accounts" do
      if CreditCardStatement.exists?
        account = CreditCardAccount.find_or_initialize_by(name_key: "unassigned")
        account.name = "Unassigned" if account.new_record?
        account.save!
        CreditCardStatement.where(credit_card_account_id: nil).update_all(credit_card_account_id: account.id)
      end
    end

    change_column_null :credit_card_statements, :credit_card_account_id, false
  end

  def down
    change_column_null :credit_card_statements, :credit_card_account_id, true
    remove_reference :credit_card_statements, :credit_card_account, foreign_key: true
  end
end
