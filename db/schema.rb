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

ActiveRecord::Schema[8.1].define(version: 2026_10_26_150000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "announcements", force: :cascade do |t|
    t.bigint "family_id", null: false
    t.bigint "user_id", null: false
    t.string "audience", default: "everyone", null: false
    t.bigint "reunion_id"
    t.string "subject"
    t.text "body", null: false
    t.integer "recipient_count", default: 0, null: false
    t.integer "failed_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["family_id", "created_at"], name: "index_announcements_on_family_id_and_created_at"
    t.index ["family_id"], name: "index_announcements_on_family_id"
    t.index ["user_id"], name: "index_announcements_on_user_id"
  end

  create_table "board_posts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "parent_id"
    t.string "title", limit: 120
    t.text "body", null: false
    t.bigint "reunion_id"
    t.boolean "pinned", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "family_id", null: false
    t.index ["created_at"], name: "index_board_posts_on_created_at"
    t.index ["family_id"], name: "index_board_posts_on_family_id"
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

  create_table "email_deliveries", force: :cascade do |t|
    t.bigint "family_id", null: false
    t.bigint "membership_id", null: false
    t.string "kind", null: false
    t.string "item_key", null: false
    t.string "status", default: "sending", null: false
    t.string "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["family_id"], name: "index_email_deliveries_on_family_id"
    t.index ["membership_id", "kind", "item_key"], name: "index_email_deliveries_once", unique: true
    t.index ["membership_id"], name: "index_email_deliveries_on_membership_id"
  end

  create_table "events", force: :cascade do |t|
    t.bigint "family_id", null: false
    t.string "title", null: false
    t.date "starts_on", null: false
    t.date "ends_on"
    t.string "time_note"
    t.string "location"
    t.text "notes"
    t.bigint "reunion_id"
    t.bigint "created_by_id"
    t.bigint "updated_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "organizers_only", default: false, null: false
    t.string "repeat", default: "none", null: false
    t.date "repeat_until"
    t.jsonb "skipped_dates", default: [], null: false
    t.index ["family_id", "starts_on"], name: "index_events_on_family_id_and_starts_on"
    t.index ["family_id"], name: "index_events_on_family_id"
    t.index ["reunion_id"], name: "index_events_on_reunion_id"
  end

  create_table "families", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "kind", default: "family", null: false
    t.index ["slug"], name: "index_families_on_slug", unique: true
    t.check_constraint "kind::text = ANY (ARRAY['family'::character varying::text, 'group'::character varying::text])", name: "families_kind"
  end

  create_table "households", force: :cascade do |t|
    t.string "name", null: false
    t.string "city"
    t.string "region"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "family_id", null: false
    t.bigint "created_by_id"
    t.bigint "updated_by_id"
    t.index ["family_id"], name: "index_households_on_family_id"
  end

  create_table "invitations", force: :cascade do |t|
    t.bigint "family_id", null: false
    t.string "email", null: false
    t.string "role", default: "member", null: false
    t.bigint "person_id"
    t.bigint "invited_by_id"
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "emailed_at"
    t.string "email_error"
    t.index ["family_id", "email"], name: "index_invitations_on_family_id_and_email"
    t.index ["family_id"], name: "index_invitations_on_family_id"
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["person_id"], name: "index_invitations_on_person_id"
    t.index ["token_digest"], name: "index_invitations_on_token_digest", unique: true
    t.check_constraint "role::text = ANY (ARRAY['organizer'::character varying::text, 'member'::character varying::text])", name: "invitations_role"
  end

  create_table "membership_events", force: :cascade do |t|
    t.bigint "family_id", null: false
    t.bigint "actor_user_id"
    t.string "kind", null: false
    t.string "target_label", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_user_id"], name: "index_membership_events_on_actor_user_id"
    t.index ["family_id", "created_at"], name: "index_membership_events_on_family_id_and_created_at"
    t.index ["family_id"], name: "index_membership_events_on_family_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "family_id", null: false
    t.bigint "user_id", null: false
    t.string "role", default: "member", null: false
    t.bigint "person_id"
    t.datetime "board_seen_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "calendar_token"
    t.boolean "email_reminders", default: true, null: false
    t.string "unsubscribe_token"
    t.boolean "owner", default: false, null: false
    t.index ["calendar_token"], name: "index_memberships_on_calendar_token", unique: true
    t.index ["family_id", "user_id"], name: "index_memberships_on_family_id_and_user_id", unique: true
    t.index ["family_id"], name: "index_memberships_on_family_id"
    t.index ["family_id"], name: "index_memberships_one_owner_per_family", unique: true, where: "owner"
    t.index ["person_id"], name: "index_memberships_on_person_id"
    t.index ["unsubscribe_token"], name: "index_memberships_on_unsubscribe_token", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.check_constraint "role::text = ANY (ARRAY['organizer'::character varying::text, 'member'::character varying::text])", name: "memberships_role"
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
    t.bigint "family_id", null: false
    t.string "phone"
    t.string "phone2"
    t.string "street1"
    t.string "street2"
    t.string "city"
    t.string "state"
    t.string "zip"
    t.index ["family_id"], name: "index_people_on_family_id"
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
    t.bigint "family_id", null: false
    t.index ["family_id"], name: "index_relationships_on_family_id"
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
    t.bigint "family_id", null: false
    t.index ["family_id"], name: "index_reunions_on_family_id"
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

  create_table "slack_integrations", force: :cascade do |t|
    t.bigint "family_id", null: false
    t.text "webhook_ciphertext", null: false
    t.boolean "notify_meetings", default: true, null: false
    t.boolean "notify_forum", default: true, null: false
    t.boolean "notify_surveys", default: true, null: false
    t.boolean "notify_deadlines", default: true, null: false
    t.boolean "notify_messages", default: false, null: false
    t.string "last_status"
    t.datetime "last_posted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["family_id"], name: "index_slack_integrations_on_family_id", unique: true
  end

  create_table "slack_posts", force: :cascade do |t|
    t.bigint "family_id", null: false
    t.string "item_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["family_id", "item_key"], name: "index_slack_posts_on_family_id_and_item_key", unique: true
    t.index ["family_id"], name: "index_slack_posts_on_family_id"
  end

  create_table "survey_answers", force: :cascade do |t|
    t.bigint "survey_response_id", null: false
    t.bigint "survey_question_id", null: false
    t.text "body"
    t.jsonb "choices", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["survey_question_id"], name: "index_survey_answers_on_survey_question_id"
    t.index ["survey_response_id", "survey_question_id"], name: "index_survey_answers_one_per_question", unique: true
    t.index ["survey_response_id"], name: "index_survey_answers_on_survey_response_id"
  end

  create_table "survey_opt_outs", force: :cascade do |t|
    t.bigint "family_id", null: false
    t.string "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["family_id", "email"], name: "index_survey_opt_outs_on_family_id_and_email", unique: true
    t.index ["family_id"], name: "index_survey_opt_outs_on_family_id"
  end

  create_table "survey_questions", force: :cascade do |t|
    t.bigint "survey_id", null: false
    t.integer "position", default: 0, null: false
    t.string "kind", null: false
    t.string "prompt", null: false
    t.jsonb "options", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["survey_id"], name: "index_survey_questions_on_survey_id"
  end

  create_table "survey_recipients", force: :cascade do |t|
    t.bigint "survey_id", null: false
    t.bigint "person_id"
    t.bigint "membership_id"
    t.string "name"
    t.string "email", null: false
    t.string "token_digest", null: false
    t.datetime "sent_at"
    t.datetime "reminded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["membership_id"], name: "index_survey_recipients_on_membership_id"
    t.index ["person_id"], name: "index_survey_recipients_on_person_id"
    t.index ["survey_id", "email"], name: "index_survey_recipients_on_survey_id_and_email", unique: true
    t.index ["survey_id"], name: "index_survey_recipients_on_survey_id"
    t.index ["token_digest"], name: "index_survey_recipients_on_token_digest", unique: true
  end

  create_table "survey_responses", force: :cascade do |t|
    t.bigint "survey_id", null: false
    t.bigint "survey_recipient_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["survey_id"], name: "index_survey_responses_on_survey_id"
    t.index ["survey_recipient_id"], name: "index_survey_responses_on_survey_recipient_id", unique: true
  end

  create_table "surveys", force: :cascade do |t|
    t.bigint "family_id", null: false
    t.bigint "created_by_id", null: false
    t.bigint "reunion_id"
    t.string "title", null: false
    t.text "intro"
    t.date "closes_on"
    t.string "status", default: "draft", null: false
    t.boolean "hide_names", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_surveys_on_created_by_id"
    t.index ["family_id"], name: "index_surveys_on_family_id"
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "platform_admin", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "announcements", "families"
  add_foreign_key "announcements", "users"
  add_foreign_key "board_posts", "board_posts", column: "parent_id"
  add_foreign_key "board_posts", "families"
  add_foreign_key "board_posts", "reunions"
  add_foreign_key "board_posts", "users"
  add_foreign_key "date_options", "reunions"
  add_foreign_key "date_votes", "date_options"
  add_foreign_key "date_votes", "users"
  add_foreign_key "email_deliveries", "families"
  add_foreign_key "email_deliveries", "memberships"
  add_foreign_key "events", "families"
  add_foreign_key "events", "reunions"
  add_foreign_key "households", "families"
  add_foreign_key "invitations", "families"
  add_foreign_key "invitations", "people"
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "membership_events", "families"
  add_foreign_key "membership_events", "users", column: "actor_user_id"
  add_foreign_key "memberships", "families"
  add_foreign_key "memberships", "people"
  add_foreign_key "memberships", "users"
  add_foreign_key "people", "families"
  add_foreign_key "people", "households"
  add_foreign_key "relationships", "families"
  add_foreign_key "relationships", "people", column: "from_person_id"
  add_foreign_key "relationships", "people", column: "to_person_id"
  add_foreign_key "reunions", "families"
  add_foreign_key "rsvps", "households"
  add_foreign_key "rsvps", "reunions"
  add_foreign_key "slack_integrations", "families"
  add_foreign_key "slack_posts", "families"
  add_foreign_key "survey_answers", "survey_questions"
  add_foreign_key "survey_answers", "survey_responses"
  add_foreign_key "survey_opt_outs", "families"
  add_foreign_key "survey_questions", "surveys"
  add_foreign_key "survey_recipients", "memberships"
  add_foreign_key "survey_recipients", "people"
  add_foreign_key "survey_recipients", "surveys"
  add_foreign_key "survey_responses", "survey_recipients"
  add_foreign_key "survey_responses", "surveys"
  add_foreign_key "surveys", "families"
  add_foreign_key "surveys", "users", column: "created_by_id"
  add_foreign_key "tasks", "reunions"
  add_foreign_key "tasks", "users", column: "claimed_by_id"
end
