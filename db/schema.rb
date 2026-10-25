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

ActiveRecord::Schema[8.1].define(version: 2026_10_25_100200) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "board_posts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "parent_id"
    t.string "title", limit: 120
    t.text "body", null: false
    t.bigint "reunion_id"
    t.boolean "pinned", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_board_posts_on_created_at"
    t.index ["parent_id", "created_at"], name: "index_board_posts_on_parent_id_and_created_at"
    t.index ["parent_id"], name: "index_board_posts_on_parent_id"
    t.index ["reunion_id"], name: "index_board_posts_on_reunion_id"
    t.index ["user_id"], name: "index_board_posts_on_user_id"
  end

  create_table "date_options", force: :cascade do |t|
    t.bigint "reunion_id", null: false
    t.date "starts_on", null: false
    t.date "ends_on"
    t.string "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reunion_id"], name: "index_date_options_on_reunion_id"
  end

  create_table "date_votes", force: :cascade do |t|
    t.bigint "date_option_id", null: false
    t.bigint "user_id", null: false
    t.string "answer", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["date_option_id", "user_id"], name: "index_date_votes_on_date_option_id_and_user_id", unique: true
    t.index ["date_option_id"], name: "index_date_votes_on_date_option_id"
    t.index ["user_id"], name: "index_date_votes_on_user_id"
    t.check_constraint "answer::text = ANY (ARRAY['yes'::character varying::text, 'maybe'::character varying::text, 'no'::character varying::text])", name: "date_votes_answer"
  end

  create_table "households", force: :cascade do |t|
    t.string "name", null: false
    t.string "city"
    t.string "region"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "people", force: :cascade do |t|
    t.bigint "household_id"
    t.string "first_name", null: false
    t.string "last_name"
    t.string "maiden_name"
    t.string "nickname"
    t.date "birth_date"
    t.date "death_date"
    t.string "birth_place"
    t.string "occupation"
    t.text "notes"
    t.string "email"
    t.boolean "hide_details", default: false, null: false
    t.bigint "created_by_id"
    t.bigint "updated_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["household_id"], name: "index_people_on_household_id"
    t.index ["last_name", "first_name"], name: "index_people_on_last_name_and_first_name"
  end

  create_table "relationships", force: :cascade do |t|
    t.bigint "from_person_id", null: false
    t.bigint "to_person_id", null: false
    t.string "kind", null: false
    t.date "started_on"
    t.date "ended_on"
    t.string "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["from_person_id", "to_person_id", "kind"], name: "index_relationships_uniqueness", unique: true
    t.index ["from_person_id"], name: "index_relationships_on_from_person_id"
    t.index ["to_person_id"], name: "index_relationships_on_to_person_id"
    t.check_constraint "from_person_id <> to_person_id", name: "relationships_no_self"
    t.check_constraint "kind::text = ANY (ARRAY['parent'::character varying::text, 'partner'::character varying::text])", name: "relationships_kind"
  end

  create_table "reunions", force: :cascade do |t|
    t.string "title", null: false
    t.date "starts_on"
    t.date "ends_on"
    t.string "location_name"
    t.string "address"
    t.text "description"
    t.date "rsvp_by"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "rsvps", force: :cascade do |t|
    t.bigint "reunion_id", null: false
    t.bigint "household_id", null: false
    t.string "status", default: "maybe", null: false
    t.integer "adults", default: 0, null: false
    t.integer "children", default: 0, null: false
    t.text "dietary"
    t.boolean "lodging_needed", default: false, null: false
    t.date "arrival_on"
    t.date "departure_on"
    t.text "notes"
    t.bigint "updated_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["household_id"], name: "index_rsvps_on_household_id"
    t.index ["reunion_id", "household_id"], name: "index_rsvps_on_reunion_id_and_household_id", unique: true
    t.index ["reunion_id"], name: "index_rsvps_on_reunion_id"
    t.check_constraint "status::text = ANY (ARRAY['attending'::character varying::text, 'maybe'::character varying::text, 'not_attending'::character varying::text])", name: "rsvps_status"
  end

  create_table "tasks", force: :cascade do |t|
    t.bigint "reunion_id", null: false
    t.string "title", null: false
    t.text "details"
    t.bigint "claimed_by_id"
    t.boolean "done", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["claimed_by_id"], name: "index_tasks_on_claimed_by_id"
    t.index ["reunion_id"], name: "index_tasks_on_reunion_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.boolean "admin", default: false, null: false
    t.datetime "board_seen_at"
    t.bigint "person_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["person_id"], name: "index_users_on_person_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "board_posts", "board_posts", column: "parent_id"
  add_foreign_key "board_posts", "reunions"
  add_foreign_key "board_posts", "users"
  add_foreign_key "date_options", "reunions"
  add_foreign_key "date_votes", "date_options"
  add_foreign_key "date_votes", "users"
  add_foreign_key "people", "households"
  add_foreign_key "relationships", "people", column: "from_person_id"
  add_foreign_key "relationships", "people", column: "to_person_id"
  add_foreign_key "rsvps", "households"
  add_foreign_key "rsvps", "reunions"
  add_foreign_key "tasks", "reunions"
  add_foreign_key "tasks", "users", column: "claimed_by_id"
  add_foreign_key "users", "people"
end
