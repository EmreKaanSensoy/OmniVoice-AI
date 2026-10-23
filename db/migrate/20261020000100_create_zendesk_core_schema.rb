class CreateZendeskCoreSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :subdomain, null: false
      t.string :phone_number
      t.text :settings

      t.timestamps
    end
    add_index :organizations, :subdomain, unique: true

    create_table :users do |t|
      t.references :organization, foreign_key: true, index: true
      t.string :name, null: false
      t.string :email, null: false
      t.string :password_digest
      t.string :role, default: "agent", null: false
      t.string :phone
      t.string :avatar_url
      t.string :status, default: "available"

      t.timestamps
    end
    add_index :users, [:organization_id, :email], unique: true

    create_table :tickets do |t|
      t.references :organization, null: false, foreign_key: true, index: true
      t.integer :ticket_number, null: false
      t.string :subject, null: false
      t.text :description
      t.string :status, default: "new", null: false, index: true
      t.string :priority, default: "normal", null: false, index: true
      t.string :ticket_type, default: "question", null: false
      t.string :channel, default: "web", null: false
      t.references :requester, null: false, foreign_key: { to_table: :users }, index: true
      t.references :assignee, foreign_key: { to_table: :users }, index: true
      t.string :tags
      t.text :ai_summary
      t.string :ai_sentiment
      t.text :ai_suggested_action
      t.integer :csat_rating
      t.text :csat_comment
      t.datetime :due_at
      t.datetime :resolved_at

      t.timestamps
    end
    add_index :tickets, [:organization_id, :ticket_number], unique: true

    create_table :ticket_comments do |t|
      t.references :ticket, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      t.text :body, null: false
      t.boolean :is_internal, default: false, null: false
      t.string :comment_type, default: "message", null: false
      t.text :metadata

      t.timestamps
    end

    create_table :call_logs do |t|
      t.references :organization, null: false, foreign_key: true, index: true
      t.references :ticket, foreign_key: true, index: true
      t.references :agent, foreign_key: { to_table: :users }, index: true
      t.string :call_sid, index: true
      t.string :caller_number
      t.string :callee_number
      t.string :caller_name
      t.string :direction, default: "inbound"
      t.string :status, default: "in_progress", index: true
      t.integer :duration_seconds, default: 0
      t.string :recording_url
      t.text :transcript_full
      t.string :detected_intent
      t.string :sentiment
      t.text :ai_summary
      t.text :ai_action_items
      t.datetime :started_at
      t.datetime :ended_at

      t.timestamps
    end

    create_table :call_transcripts do |t|
      t.references :call_log, null: false, foreign_key: true, index: true
      t.string :speaker, null: false
      t.text :content, null: false
      t.string :sentiment
      t.integer :offset_ms, default: 0

      t.timestamps
    end

    create_table :knowledge_articles do |t|
      t.references :organization, null: false, foreign_key: true, index: true
      t.references :author, null: false, foreign_key: { to_table: :users }, index: true
      t.string :title, null: false
      t.string :slug, null: false
      t.string :category, default: "Genel"
      t.text :body, null: false
      t.string :status, default: "published"
      t.integer :views_count, default: 0
      t.integer :helpful_count, default: 0

      t.timestamps
    end
    add_index :knowledge_articles, [:organization_id, :slug], unique: true

    create_table :macros do |t|
      t.references :organization, null: false, foreign_key: true, index: true
      t.string :title, null: false
      t.string :description
      t.text :actions

      t.timestamps
    end
  end
end
