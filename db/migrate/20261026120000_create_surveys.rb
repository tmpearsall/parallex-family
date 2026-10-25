# Organizer surveys: a few questions mailed to members and to people on the list who have no account. Everyone gets a
# personal link (only its SHA-256 digest is stored), answers once, and can change the answers until the survey closes.
class CreateSurveys < ActiveRecord::Migration[8.1]
  def change
    create_table :surveys do |t|
      t.references :family, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.bigint :reunion_id
      t.string :title, null: false
      t.text :intro
      t.date :closes_on
      t.string :status, null: false, default: "draft"      # draft, open, closed
      t.boolean :hide_names, null: false, default: false
      t.timestamps
    end

    create_table :survey_questions do |t|
      t.references :survey, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.string :kind, null: false                            # single, multi, short, long, dates
      t.string :prompt, null: false
      t.jsonb :options, null: false, default: []
      t.timestamps
    end

    create_table :survey_recipients do |t|
      t.references :survey, null: false, foreign_key: true
      t.references :person, foreign_key: true
      t.references :membership, foreign_key: true
      t.string :name
      t.string :email, null: false
      t.string :token_digest, null: false
      t.datetime :sent_at
      t.datetime :reminded_at
      t.timestamps
    end
    add_index :survey_recipients, :token_digest, unique: true
    add_index :survey_recipients, [ :survey_id, :email ], unique: true

    create_table :survey_responses do |t|
      t.references :survey, null: false, foreign_key: true
      t.references :survey_recipient, null: false, foreign_key: true, index: { unique: true }
      t.timestamps
    end

    create_table :survey_answers do |t|
      t.references :survey_response, null: false, foreign_key: true
      t.references :survey_question, null: false, foreign_key: true
      t.text :body
      t.jsonb :choices, null: false, default: []
      t.timestamps
    end
    add_index :survey_answers, [ :survey_response_id, :survey_question_id ], unique: true, name: "index_survey_answers_one_per_question"

    create_table :survey_opt_outs do |t|
      t.references :family, null: false, foreign_key: true
      t.string :email, null: false
      t.timestamps
    end
    add_index :survey_opt_outs, [ :family_id, :email ], unique: true
  end
end
