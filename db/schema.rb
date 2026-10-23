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

ActiveRecord::Schema[8.1].define(version: 2026_10_20_000100) do
  create_table "call_logs", force: :cascade do |t|
    t.integer "organization_id", null: false
    t.integer "ticket_id"
    t.integer "agent_id"
    t.string "call_sid"
    t.string "caller_number"
    t.string "callee_number"
    t.string "caller_name"
    t.string "direction", default: "inbound"
    t.string "status", default: "in_progress"
    t.integer "duration_seconds", default: 0
    t.string "recording_url"
    t.text "transcript_full"
    t.string "detected_intent"
    t.string "sentiment"
    t.text "ai_summary"
    t.text "ai_action_items"
    t.datetime "started_at"
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_call_logs_on_agent_id"
    t.index ["call_sid"], name: "index_call_logs_on_call_sid"
    t.index ["organization_id"], name: "index_call_logs_on_organization_id"
    t.index ["status"], name: "index_call_logs_on_status"
    t.index ["ticket_id"], name: "index_call_logs_on_ticket_id"
  end

  create_table "call_transcripts", force: :cascade do |t|
    t.integer "call_log_id", null: false
    t.string "speaker", null: false
    t.text "content", null: false
    t.string "sentiment"
    t.integer "offset_ms", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["call_log_id"], name: "index_call_transcripts_on_call_log_id"
  end

  create_table "knowledge_articles", force: :cascade do |t|
    t.integer "organization_id", null: false
    t.integer "author_id", null: false
    t.string "title", null: false
    t.string "slug", null: false
    t.string "category", default: "Genel"
    t.text "body", null: false
    t.string "status", default: "published"
    t.integer "views_count", default: 0
    t.integer "helpful_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_knowledge_articles_on_author_id"
    t.index ["organization_id", "slug"], name: "index_knowledge_articles_on_organization_id_and_slug", unique: true
    t.index ["organization_id"], name: "index_knowledge_articles_on_organization_id"
  end

  create_table "macros", force: :cascade do |t|
    t.integer "organization_id", null: false
    t.string "title", null: false
    t.string "description"
    t.text "actions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_macros_on_organization_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.string "subdomain", null: false
    t.string "phone_number"
    t.text "settings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["subdomain"], name: "index_organizations_on_subdomain", unique: true
  end

  create_table "ticket_comments", force: :cascade do |t|
    t.integer "ticket_id", null: false
    t.integer "user_id", null: false
    t.text "body", null: false
    t.boolean "is_internal", default: false, null: false
    t.string "comment_type", default: "message", null: false
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ticket_id"], name: "index_ticket_comments_on_ticket_id"
    t.index ["user_id"], name: "index_ticket_comments_on_user_id"
  end

  create_table "tickets", force: :cascade do |t|
    t.integer "organization_id", null: false
    t.integer "ticket_number", null: false
    t.string "subject", null: false
    t.text "description"
    t.string "status", default: "new", null: false
    t.string "priority", default: "normal", null: false
    t.string "ticket_type", default: "question", null: false
    t.string "channel", default: "web", null: false
    t.integer "requester_id", null: false
    t.integer "assignee_id"
    t.string "tags"
    t.text "ai_summary"
    t.string "ai_sentiment"
    t.text "ai_suggested_action"
    t.integer "csat_rating"
    t.text "csat_comment"
    t.datetime "due_at"
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id"], name: "index_tickets_on_assignee_id"
    t.index ["organization_id", "ticket_number"], name: "index_tickets_on_organization_id_and_ticket_number", unique: true
    t.index ["organization_id"], name: "index_tickets_on_organization_id"
    t.index ["priority"], name: "index_tickets_on_priority"
    t.index ["requester_id"], name: "index_tickets_on_requester_id"
    t.index ["status"], name: "index_tickets_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.integer "organization_id"
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest"
    t.string "role", default: "agent", null: false
    t.string "phone"
    t.string "avatar_url"
    t.string "status", default: "available"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "email"], name: "index_users_on_organization_id_and_email", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
  end

  add_foreign_key "call_logs", "organizations"
  add_foreign_key "call_logs", "tickets"
  add_foreign_key "call_logs", "users", column: "agent_id"
  add_foreign_key "call_transcripts", "call_logs"
  add_foreign_key "knowledge_articles", "organizations"
  add_foreign_key "knowledge_articles", "users", column: "author_id"
  add_foreign_key "macros", "organizations"
  add_foreign_key "ticket_comments", "tickets"
  add_foreign_key "ticket_comments", "users"
  add_foreign_key "tickets", "organizations"
  add_foreign_key "tickets", "users", column: "assignee_id"
  add_foreign_key "tickets", "users", column: "requester_id"
  add_foreign_key "users", "organizations"
end
