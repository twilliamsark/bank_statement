# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_12_201700) do
  create_table "account_statements", force: :cascade do |t|
    t.integer "account_id"
    t.string "account_name"
    t.string "account_number"
    t.decimal "apy_earned", precision: 8, scale: 4
    t.integer "beginning_balance_cents"
    t.integer "checks_cents"
    t.datetime "created_at", null: false
    t.integer "deposits_cents"
    t.integer "ending_balance_cents"
    t.string "import_format"
    t.integer "interest_paid_ytd_cents"
    t.integer "page_count"
    t.date "period_end"
    t.date "period_start"
    t.integer "service_fees_cents"
    t.string "source_filename"
    t.datetime "updated_at", null: false
    t.integer "withdrawals_cents"
    t.index ["account_id"], name: "index_account_statements_on_account_id"
    t.index ["account_number"], name: "index_account_statements_on_account_number"
    t.index ["period_start", "period_end"], name: "index_account_statements_on_period_start_and_period_end"
  end

  create_table "account_transactions", force: :cascade do |t|
    t.integer "account_statement_id", null: false
    t.integer "amount_cents", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.text "description", null: false
    t.string "section", null: false
    t.datetime "updated_at", null: false
    t.index ["account_statement_id"], name: "index_account_transactions_on_account_statement_id"
    t.index ["checksum"], name: "index_account_transactions_on_checksum"
    t.index ["date"], name: "index_account_transactions_on_date"
    t.index ["description"], name: "index_account_transactions_on_description"
    t.index ["section"], name: "index_account_transactions_on_section"
  end

  create_table "accounts", force: :cascade do |t|
    t.string "account_number"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "name_key", null: false
    t.datetime "updated_at", null: false
    t.index ["account_number"], name: "index_accounts_on_account_number"
    t.index ["name_key"], name: "index_accounts_on_name_key", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "credit_card_accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "name_key", null: false
    t.datetime "updated_at", null: false
    t.index ["name_key"], name: "index_credit_card_accounts_on_name_key", unique: true
  end

  create_table "credit_card_statements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "credit_card_account_id", null: false
    t.string "import_format"
    t.integer "page_count"
    t.string "source_filename"
    t.integer "statement_year"
    t.integer "total_spend_cents"
    t.datetime "updated_at", null: false
    t.index ["credit_card_account_id"], name: "index_credit_card_statements_on_credit_card_account_id"
    t.index ["statement_year"], name: "index_credit_card_statements_on_statement_year"
  end

  create_table "credit_card_transactions", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.string "category", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.integer "credit_card_statement_id"
    t.date "date", null: false
    t.text "description", null: false
    t.string "import_fingerprint"
    t.string "location", default: "", null: false
    t.integer "monthly_credit_card_statement_id"
    t.string "subcategory", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_credit_card_transactions_on_category"
    t.index ["checksum"], name: "index_credit_card_transactions_on_checksum"
    t.index ["credit_card_statement_id"], name: "index_credit_card_transactions_on_credit_card_statement_id"
    t.index ["date"], name: "index_credit_card_transactions_on_date"
    t.index ["description"], name: "index_credit_card_transactions_on_description"
    t.index ["monthly_credit_card_statement_id"], name: "idx_on_monthly_credit_card_statement_id_403131e787"
    t.index ["subcategory"], name: "index_credit_card_transactions_on_subcategory"
  end

  create_table "monthly_credit_card_statements", force: :cascade do |t|
    t.string "account_name"
    t.string "account_number"
    t.datetime "created_at", null: false
    t.integer "credit_card_account_id", null: false
    t.string "import_format"
    t.integer "page_count"
    t.date "period_end"
    t.date "period_start"
    t.string "source_filename"
    t.datetime "updated_at", null: false
    t.index ["credit_card_account_id"], name: "index_monthly_credit_card_statements_on_credit_card_account_id"
  end

  create_table "unreconciled_transactions", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.string "category"
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.text "description", null: false
    t.string "import_fingerprint", null: false
    t.integer "monthly_credit_card_statement_id", null: false
    t.string "subcategory"
    t.datetime "updated_at", null: false
    t.index ["amount_cents"], name: "index_unreconciled_transactions_on_amount_cents"
    t.index ["import_fingerprint"], name: "index_unreconciled_transactions_on_import_fingerprint"
    t.index ["monthly_credit_card_statement_id"], name: "idx_on_monthly_credit_card_statement_id_eed6fc13f7"
  end

  add_foreign_key "account_statements", "accounts"
  add_foreign_key "account_transactions", "account_statements"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "credit_card_statements", "credit_card_accounts"
  add_foreign_key "credit_card_transactions", "credit_card_statements"
  add_foreign_key "credit_card_transactions", "monthly_credit_card_statements"
  add_foreign_key "monthly_credit_card_statements", "credit_card_accounts"
  add_foreign_key "unreconciled_transactions", "monthly_credit_card_statements"
end
