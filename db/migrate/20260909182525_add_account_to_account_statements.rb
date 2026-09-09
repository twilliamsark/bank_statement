# frozen_string_literal: true

class AddAccountToAccountStatements < ActiveRecord::Migration[8.1]
  def up
    add_reference :account_statements, :account, foreign_key: true, null: true

    say_with_time "backfill accounts from statement names/numbers" do
      # Inline SQL-friendly backfill via Ruby model once loaded — use exec in migration carefully.
      AccountStatement.reset_column_information if defined?(AccountStatement)

      groups = {}
      AccountStatement.find_each do |statement|
        key = if statement.account_name.present?
          statement.account_name.to_s.gsub(/\s+/, " ").strip.downcase
        elsif statement.account_number.present?
          "number:#{statement.account_number.to_s.gsub(/\s+/, "")}"
        else
          next
        end

        groups[key] ||= []
        groups[key] << statement
      end

      groups.each do |key, statements|
        sample = statements.find { |s| s.account_name.present? } || statements.first
        name = if sample.account_name.present?
          sample.account_name.to_s.gsub(/\s+/, " ").strip
        else
          "Account #{sample.account_number}"
        end
        name_key = name.downcase
        number = statements.map(&:account_number).compact.find(&:present?)

        account = Account.find_or_initialize_by(name_key: name_key)
        account.name = name if account.new_record?
        account.account_number = number if account.account_number.blank? && number.present?
        account.save!

        AccountStatement.where(id: statements.map(&:id)).update_all(account_id: account.id)
      end
    end
  end

  def down
    remove_reference :account_statements, :account, foreign_key: true
  end
end
