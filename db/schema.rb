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

ActiveRecord::Schema[8.1].define(version: 2026_05_21_093847) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "repositories", force: :cascade do |t|
    t.boolean "active"
    t.datetime "created_at", null: false
    t.string "default_branch"
    t.string "name"
    t.string "owner"
    t.string "repo_name"
    t.datetime "updated_at", null: false
  end

  create_table "user_github_credentials", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "fine_grained_token", null: false
    t.datetime "last_validated_at"
    t.text "last_validation_error"
    t.datetime "token_expires_at"
    t.string "token_last_four"
    t.jsonb "token_permissions_snapshot", default: {}, null: false
    t.jsonb "token_repository_access_snapshot", default: {}, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_user_github_credentials_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "github_avatar_url"
    t.string "github_email"
    t.string "github_login", null: false
    t.string "github_name"
    t.string "github_profile_url"
    t.string "github_uid", null: false
    t.datetime "last_signed_in_at"
    t.string "oauth_provider", default: "github", null: false
    t.datetime "updated_at", null: false
    t.index ["github_login"], name: "index_users_on_github_login"
    t.index ["github_uid"], name: "index_users_on_github_uid", unique: true
  end

  add_foreign_key "user_github_credentials", "users"
end
